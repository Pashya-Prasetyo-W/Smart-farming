<?php

namespace Tests\Feature;

use App\Enums\TaskStatus;
use App\Models\FailureLog;
use App\Models\Finance;
use App\Models\Harvest;
use App\Models\IncidentReport;
use App\Models\Land;
use App\Models\Planting;
use App\Models\Task;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\Feature\Concerns\CreatesTenants;
use Tests\TestCase;

class AnalyticsTest extends TestCase
{
    use RefreshDatabase, CreatesTenants;

    private array $t;

    protected function setUp(): void
    {
        parent::setUp();

        $this->t = $this->makeTenant('a');
    }

    private function finance(string $type, string $category, float $amount, ?int $plantingId, ?array $extra = null): Finance
    {
        return Finance::forceCreate(array_merge([
            'company_id'  => $this->t['company']->id,
            'planting_id' => $plantingId,
            'type'        => $type,
            'category'    => $category,
            'amount'      => $amount,
            'description' => 'Data uji',
            'record_date' => now()->toDateString(),
        ], $extra ?? []));
    }

    private function seedMoney(): void
    {
        $plantingId = $this->t['planting']->id;

        $this->finance('pemasukan', 'penjualan', 1000000, $plantingId);
        $this->finance('pengeluaran', 'bahan', 400000, $plantingId);
        $this->finance('pengeluaran', 'upah', 100000, $plantingId);
        $this->finance('pengeluaran', 'perawatan', 50000, null);
        $this->finance('pengeluaran', 'pembelian', 300000, null);

        $harvest = new Harvest();
        $harvest->forceFill([
            'company_id'   => $this->t['company']->id,
            'planting_id'  => $plantingId,
            'harvest_date' => now()->toDateString(),
            'quantity_kg'  => 50,
            'sold_kg'      => 40,
            'price_per_kg' => 25000,
            'recorded_by'  => $this->t['owner']->id,
        ])->save();
    }

    private function secondLandWithFailedCycle(): Planting
    {
        $land = Land::create([
            'company_id'    => $this->t['company']->id,
            'name'          => 'Lahan Kedua',
            'area_sqm'      => 5000,
            'location_lat'  => -6.3,
            'location_long' => 106.9,
        ]);

        $planting = new Planting();
        $planting->forceFill([
            'company_id'       => $this->t['company']->id,
            'land_id'          => $land->id,
            'crop_name'        => 'Tomat',
            'plant_date'       => now()->subDays(60)->toDateString(),
            'est_harvest_date' => now()->subDays(5)->toDateString(),
            'status'           => 'gagal',
            'closed_at'        => now()->subDays(10)->toDateString(),
            'total_cost'       => 0,
        ])->save();

        $this->finance('pengeluaran', 'bahan', 200000, $planting->id);

        return $planting;
    }

    public function test_laba_per_siklus_dan_per_lahan(): void
    {
        $this->seedMoney();
        $failed = $this->secondLandWithFailedCycle();

        Sanctum::actingAs($this->t['owner']);

        $data = $this->getJson('/api/analytics/profit')->assertOk()->json('data');

        $cycle = collect($data['cycles'])->firstWhere('planting_id', $this->t['planting']->id);

        $this->assertEquals(1000000, $cycle['income']);
        $this->assertEquals(500000, $cycle['cost']);
        $this->assertEquals(500000, $cycle['profit']);
        $this->assertEquals(50.0, $cycle['margin_percent']);
        $this->assertEquals(50, $cycle['harvested_kg']);
        $this->assertEquals(10000, $cycle['hpp_per_kg']);
        $this->assertEqualsCanonicalizing(
            ['bahan' => 400000, 'upah' => 100000],
            collect($cycle['cost_breakdown'])->pluck('amount', 'category')->all()
        );

        $failedCycle = collect($data['cycles'])->firstWhere('planting_id', $failed->id);
        $this->assertEquals(-200000, $failedCycle['profit']);
        $this->assertNull($failedCycle['margin_percent']);
        $this->assertNull($failedCycle['hpp_per_kg']);

        $this->assertSame($this->t['land']->id, $data['lands'][0]['land_id']);
        $this->assertEquals(500000, $data['lands'][0]['profit']);
        $this->assertEquals(5000000, $data['lands'][0]['profit_per_ha']);
        $this->assertSame(1, $data['lands'][1]['failed']);
        $this->assertEquals(-200000, $data['lands'][1]['profit']);

        $this->assertEquals(1000000, $data['overall']['income']);
        $this->assertEquals(700000, $data['overall']['cycle_cost']);
        $this->assertEquals(300000, $data['overall']['cycle_profit']);
        $this->assertEquals(50000, $data['overall']['unallocated_cost']);
        $this->assertEquals(250000, $data['overall']['net_profit']);
    }

    public function test_filter_lahan_dan_status(): void
    {
        $this->seedMoney();
        $this->secondLandWithFailedCycle();

        Sanctum::actingAs($this->t['owner']);

        $filtered = $this->getJson('/api/analytics/profit?land_id=' . $this->t['land']->id)
            ->assertOk()
            ->json('data');

        $this->assertCount(1, $filtered['cycles']);
        $this->assertNull($filtered['overall']['unallocated_cost']);
        $this->assertNull($filtered['overall']['net_profit']);

        $failedOnly = $this->getJson('/api/analytics/profit?status=gagal')->assertOk()->json('data');
        $this->assertCount(1, $failedOnly['cycles']);
        $this->assertSame('gagal', $failedOnly['cycles'][0]['status']);

        $this->getJson('/api/analytics/profit?status=lainnya')->assertUnprocessable();
    }

    public function test_data_perusahaan_lain_tidak_ikut_dan_lahannya_ditolak(): void
    {
        $this->seedMoney();
        $other = $this->makeTenant('b');

        Sanctum::actingAs($other['owner']);

        $data = $this->getJson('/api/analytics/profit')->assertOk()->json('data');
        $this->assertCount(1, $data['cycles']);
        $this->assertEquals(0, $data['cycles'][0]['income']);

        $this->getJson('/api/analytics/profit?land_id=' . $this->t['land']->id)
            ->assertUnprocessable()
            ->assertJsonValidationErrors('land_id');
    }

    public function test_hanya_pemilik_yang_dapat_melihat_analitik(): void
    {
        foreach (['mandor', 'buruh'] as $role) {
            Sanctum::actingAs($this->t[$role]);

            $this->getJson('/api/analytics/profit')->assertForbidden();
            $this->getJson('/api/analytics/risk')->assertForbidden();
        }
    }

    private function overdueTask(): void
    {
        $task = new Task();
        $task->forceFill([
            'company_id'  => $this->t['company']->id,
            'planting_id' => $this->t['planting']->id,
            'assigned_to' => $this->t['buruh']->id,
            'title'       => 'Tugas terlambat',
            'task_date'   => now()->subDays(5)->toDateString(),
            'due_date'    => now()->subDays(2)->toDateString(),
            'status'      => TaskStatus::Menunggu,
        ])->save();
    }

    private function incident(string $type, int $daysAgo): void
    {
        $incident = new IncidentReport();
        $incident->forceFill([
            'company_id'  => $this->t['company']->id,
            'land_id'     => $this->t['land']->id,
            'reported_by' => $this->t['owner']->id,
            'type'        => $type,
            'description' => 'Kejadian uji',
            'media_urls'  => [],
            'reported_at' => now()->subDays($daysAgo),
        ])->save();
    }

    public function test_skor_risiko_menggabungkan_tugas_kejadian_dan_cuaca(): void
    {
        $this->overdueTask();
        $this->overdueTask();
        $this->incident('hama', 3);
        $this->incident('penyakit_tanaman', 10);
        $this->incident('hama', 45);

        $log = new FailureLog();
        $log->forceFill([
            'company_id'         => $this->t['company']->id,
            'planting_id'        => $this->t['planting']->id,
            'source'             => 'cronjob',
            'risk_score'         => 50,
            'reason'             => 'Cuaca',
            'analyzed_data_json' => ['weather_summary' => ['weather_main' => 'Rain', 'temperature' => 36]],
        ])->save();

        Sanctum::actingAs($this->t['owner']);

        $row = $this->getJson('/api/analytics/risk')->assertOk()->json('data.0');

        $points = collect($row['factors'])->pluck('points', 'key')->all();

        $this->assertSame($this->t['planting']->id, $row['planting_id']);
        $this->assertSame(20, $points['tugas_terlambat']);
        $this->assertSame(35, $points['kejadian_lapangan']);
        $this->assertSame(15, $points['hujan']);
        $this->assertSame(15, $points['suhu_ekstrem']);
        $this->assertSame(85, $row['score']);
        $this->assertSame('tinggi', $row['level']);
        $this->assertSame(2, $row['overdue_tasks']);
        $this->assertSame(2, $row['incidents']['total']);
        $this->assertCount(2, $row['incidents']['recent']);
    }

    public function test_tanpa_masalah_risikonya_rendah(): void
    {
        Sanctum::actingAs($this->t['owner']);

        $row = $this->getJson('/api/analytics/risk')->assertOk()->json('data.0');

        $this->assertSame(0, $row['score']);
        $this->assertSame('rendah', $row['level']);
        $this->assertSame([], $row['factors']);
    }

    public function test_riwayat_gagal_dan_panen_terlambat_menambah_skor(): void
    {
        $this->t['planting']->forceFill(['est_harvest_date' => now()->subDays(10)->toDateString()])->save();

        $failed = $this->secondLandWithFailedCycle();
        $failed->forceFill(['land_id' => $this->t['land']->id])->save();

        Sanctum::actingAs($this->t['owner']);

        $data = $this->getJson('/api/analytics/risk')->assertOk()->json('data');

        $this->assertCount(1, $data);

        $points = collect($data[0]['factors'])->pluck('points', 'key')->all();

        $this->assertSame(10, $points['panen_terlambat']);
        $this->assertSame(10, $points['riwayat_gagal']);
        $this->assertSame(20, $data[0]['score']);
        $this->assertSame('rendah', $data[0]['level']);
    }

    public function test_siklus_diurutkan_dari_risiko_tertinggi(): void
    {
        $this->overdueTask();
        $this->incident('hama', 2);

        $land = Land::create([
            'company_id'    => $this->t['company']->id,
            'name'          => 'Lahan Aman',
            'area_sqm'      => 100,
            'location_lat'  => -6.4,
            'location_long' => 107.0,
        ]);

        $planting = new Planting();
        $planting->forceFill([
            'company_id'       => $this->t['company']->id,
            'land_id'          => $land->id,
            'crop_name'        => 'Jagung',
            'plant_date'       => now()->subDays(5)->toDateString(),
            'est_harvest_date' => now()->addDays(60)->toDateString(),
            'status'           => 'berjalan',
            'total_cost'       => 0,
        ])->save();

        Sanctum::actingAs($this->t['owner']);

        $data = $this->getJson('/api/analytics/risk')->assertOk()->json('data');

        $this->assertSame([$this->t['planting']->id, $planting->id], array_column($data, 'planting_id'));
        $this->assertSame(25, $data[0]['score']);
        $this->assertSame(0, $data[1]['score']);
    }
}
