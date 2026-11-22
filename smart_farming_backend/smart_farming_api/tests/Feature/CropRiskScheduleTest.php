<?php

namespace Tests\Feature;

use App\Models\FailureLog;
use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Testing\RefreshDatabase;
use App\Models\CropRiskRun;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Carbon\Carbon;
use Tests\Feature\Concerns\CreatesTenants;
use Tests\TestCase;

class CropRiskScheduleTest extends TestCase
{
    use RefreshDatabase, CreatesTenants;

    private array $t;

    protected function setUp(): void
    {
        parent::setUp();

        $this->t = $this->makeTenant('a');
    }

    private function forecastBody(string $main, float $temp): array
    {
        return [
            'list' => [[
                'dt_txt'  => '2026-11-23 00:00:00',
                'main'    => ['temp' => $temp, 'humidity' => 80],
                'weather' => [['main' => $main, 'description' => strtolower($main)]],
            ]],
        ];
    }

    private function fakeForecast(string $main, float $temp): void
    {
        Http::fake([
            'api.openweathermap.org/*' => Http::response($this->forecastBody($main, $temp)),
        ]);
    }

    private function fakeForecastSequence(array $items): void
    {
        $sequence = Http::sequence();

        foreach ($items as [$main, $temp]) {
            $sequence->push($this->forecastBody($main, $temp));
        }

        Http::fake(['api.openweathermap.org/*' => $sequence]);
    }

    public function test_analisis_risiko_dijadwalkan_pukul_nol_waktu_bisnis(): void
    {
        $this->artisan('schedule:list')->assertSuccessful();

        $event = collect(app(Schedule::class)->events())
            ->first(fn ($event) => str_contains($event->command, 'crop:analyze-risk'));

        $this->assertNotNull($event);
        $this->assertSame('0 0 * * *', $event->expression);
        $this->assertSame(config('app.business_timezone'), (string) $event->timezone);
    }

    public function test_analisis_menyimpan_log_jika_ada_risiko(): void
    {
        $this->fakeForecast('Rain', 38);

        $this->artisan('crop:analyze-risk')
            ->expectsOutputToContain('1 tanaman dianalisis, 1 berisiko')
            ->assertSuccessful();

        $log = FailureLog::withoutGlobalScopes()->firstOrFail();

        $this->assertSame(50, (int) $log->risk_score);
        $this->assertSame('cronjob', $log->source);
        $this->assertSame($this->t['company']->id, $log->company_id);
        $this->assertSame($this->t['planting']->id, $log->planting_id);
    }

    public function test_analisis_tanpa_risiko_tidak_menyimpan_log_tetapi_tercatat_dianalisis(): void
    {
        $this->fakeForecast('Clear', 28);

        $this->artisan('crop:analyze-risk')
            ->expectsOutputToContain('1 tanaman dianalisis, 0 berisiko')
            ->assertSuccessful();

        $this->assertSame(0, FailureLog::withoutGlobalScopes()->count());
    }

    public function test_kegagalan_layanan_cuaca_dihitung_dan_tidak_menghentikan_analisis(): void
    {
        Http::fake(['api.openweathermap.org/*' => Http::response([], 500)]);

        $this->artisan('crop:analyze-risk')
            ->expectsOutputToContain('0 tanaman dianalisis, 0 berisiko, 0 dilewati, 1 gagal')
            ->assertSuccessful();

        $this->assertSame(0, FailureLog::withoutGlobalScopes()->count());
    }

    public function test_setiap_run_tercatat_walau_tidak_ada_risiko(): void
    {
        $this->fakeForecast('Clear', 28);

        $this->artisan('crop:analyze-risk')->assertSuccessful();

        $run = CropRiskRun::firstOrFail();

        $this->assertSame(1, $run->checked);
        $this->assertSame(0, $run->logged);
    }

    public function test_riwayat_tetap_ada_dan_risiko_saat_ini_kembali_nol_setelah_aman(): void
    {
        $this->fakeForecastSequence([['Rain', 38], ['Clear', 28]]);
        $this->artisan('crop:analyze-risk')->assertSuccessful();

        Sanctum::actingAs($this->t['owner']);
        $this->getJson('/api/failure-logs')
            ->assertOk()
            ->assertJsonPath('status.current_score', 50)
            ->assertJsonPath('status.is_stale', false)
            ->assertJsonCount(1, 'data');

        Carbon::setTestNow(now()->addDays(3));
        $this->artisan('crop:analyze-risk')->assertSuccessful();

        $this->getJson('/api/failure-logs')
            ->assertOk()
            ->assertJsonPath('status.current_score', 0)
            ->assertJsonPath('status.last_run.logged', 0)
            ->assertJsonCount(1, 'data');

        $this->assertSame(1, FailureLog::withoutGlobalScopes()->count());

        Carbon::setTestNow();
    }

    public function test_risiko_siklus_yang_sudah_ditutup_tidak_dihitung_sebagai_saat_ini(): void
    {
        $this->fakeForecast('Rain', 38);
        $this->artisan('crop:analyze-risk')->assertSuccessful();

        $this->t['planting']->forceFill(['status' => 'panen'])->save();

        Sanctum::actingAs($this->t['owner']);
        $this->getJson('/api/failure-logs')
            ->assertOk()
            ->assertJsonPath('status.current_score', 0)
            ->assertJsonCount(1, 'data');
    }

    public function test_status_menandai_analisis_basi_jika_belum_pernah_atau_lama_tidak_jalan(): void
    {
        Sanctum::actingAs($this->t['owner']);

        $this->getJson('/api/failure-logs')
            ->assertOk()
            ->assertJsonPath('status.is_stale', true)
            ->assertJsonPath('status.last_run_at', null);

        CropRiskRun::create(['ran_at' => now()->subHours(40)]);

        $this->getJson('/api/failure-logs')->assertJsonPath('status.is_stale', true);

        CropRiskRun::create(['ran_at' => now()->subHours(2)]);

        $this->getJson('/api/failure-logs')->assertJsonPath('status.is_stale', false);
    }

    public function test_status_analisis_tidak_menghitung_risiko_perusahaan_lain(): void
    {
        $this->fakeForecast('Rain', 38);
        $this->artisan('crop:analyze-risk')->assertSuccessful();

        $other = $this->makeTenant('b');
        $other['planting']->forceFill(['status' => 'panen'])->save();

        Sanctum::actingAs($other['owner']);

        $this->getJson('/api/failure-logs')
            ->assertOk()
            ->assertJsonPath('status.current_score', 0)
            ->assertJsonPath('data', []);
    }
}
