<?php

namespace Tests\Feature;

use App\Models\FailureLog;
use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
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

    private function fakeForecast(string $main, float $temp): void
    {
        Http::fake([
            'api.openweathermap.org/*' => Http::response([
                'list' => [[
                    'dt_txt'  => '2026-11-23 00:00:00',
                    'main'    => ['temp' => $temp, 'humidity' => 80],
                    'weather' => [['main' => $main, 'description' => strtolower($main)]],
                ]],
            ]),
        ]);
    }

    public function test_analisis_risiko_dijadwalkan_pukul_nol_waktu_bisnis(): void
    {
        $this->artisan('schedule:list')->assertSuccessful();

        $event = collect(app(Schedule::class)->events())
            ->first(fn ($event) => str_contains($event->command, 'crop:analyze-risk'));

        $this->assertNotNull($event);
        $this->assertSame('0 0 * * *', $event->expression);
        $this->assertSame(config('business_timezone'), (string) $event->timezone);
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
}
