<?php

namespace Tests\Feature;

use App\Models\Attendance;
use App\Models\Finance;
use App\Models\Harvest;
use App\Models\Planting;
use App\Models\Task;
use App\Models\TaskReport;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\Feature\Concerns\CreatesTenants;
use Tests\TestCase;

class HarvestFinanceTest extends TestCase
{
    use RefreshDatabase, CreatesTenants;

    private array $t;

    protected function setUp(): void
    {
        parent::setUp();

        Carbon::setTestNow(Carbon::parse('2026-11-20 03:00:00', 'UTC'));

        $this->t = $this->makeTenant('a');
    }

    protected function tearDown(): void
    {
        Carbon::setTestNow();

        parent::tearDown();
    }

    private function planting(): Planting
    {
        return $this->t['planting'];
    }

    private function harvest(array $payload = [], ?Planting $planting = null)
    {
        Sanctum::actingAs($this->t['owner']);

        $planting ??= $this->planting();

        return $this->postJson("/api/plantings/{$planting->id}/harvests", array_merge([
            'quantity_kg' => 100,
        ], $payload));
    }

    private function task(string $status, ?User $user = null, ?Planting $planting = null, ?float $wage = null, string $date = '2026-11-10'): Task
    {
        $user ??= $this->t['buruh'];
        $planting ??= $this->planting();

        $task = new Task();
        $task->forceFill([
            'company_id'  => $user->company_id,
            'planting_id' => $planting->id,
            'assigned_to' => $user->id,
            'title'       => 'Tugas ' . $date,
            'task_date'   => $date,
            'due_date'    => $date,
            'status'      => $status,
            'wage_amount' => $wage,
        ])->save();

        if ($status === 'selesai') {
            $report = new TaskReport();
            $report->forceFill([
                'company_id'    => $user->company_id,
                'task_id'       => $task->id,
                'type'          => 'selesai',
                'media_urls'    => ['foto.jpg'],
                'reported_at'   => Carbon::parse($date . ' 10:00:00', 'UTC'),
                'review_status' => 'terverifikasi',
                'reviewer_role' => 'mandor',
            ])->save();
        }

        return $task;
    }

    private function wage($user, string $type, float $amount = 0): void
    {
        $wage = $user->wage()->firstOrNew([]);
        $wage->forceFill([
            'company_id' => $user->company_id,
            'wage_type'  => $type,
            'amount'     => $amount,
        ])->save();
    }

    private function attendance(User $user, string $date): void
    {
        $attendance = new Attendance();
        $attendance->forceFill([
            'company_id'           => $user->company_id,
            'user_id'              => $user->id,
            'work_date'            => $date,
            'check_in_at'          => Carbon::parse($date . ' 01:00:00', 'UTC'),
            'check_out_at'         => Carbon::parse($date . ' 09:00:00', 'UTC'),
            'source'               => 'mandiri',
            'status'               => 'terverifikasi',
            'reviewer_role'        => 'mandor',
            'reviewer_assigned_at' => now(),
        ])->save();
    }

    private function expense(float $amount, string $category = 'lainnya', ?Planting $planting = null)
    {
        Sanctum::actingAs($this->t['owner']);

        return $this->postJson('/api/finances', [
            'type'        => 'pengeluaran',
            'category'    => $category,
            'amount'      => $amount,
            'description' => 'Biaya',
            'planting_id' => ($planting ?? $this->planting())->id,
        ]);
    }

    public function test_panen_dengan_penjualan_mencatat_pemasukan(): void
    {
        $this->harvest(['quantity_kg' => 100, 'sold_kg' => 80, 'price_per_kg' => 25000])
            ->assertCreated()
            ->assertJsonPath('data.planting_id', $this->planting()->id);

        $income = Finance::where('type', 'pemasukan')->first();

        $this->assertNotNull($income);
        $this->assertEquals(2000000, $income->amount);
        $this->assertSame('penjualan', $income->category);
        $this->assertSame($this->planting()->id, $income->planting_id);
        $this->assertNotNull($income->harvest_id);
    }

    public function test_panen_tanpa_penjualan_tidak_mencatat_pemasukan(): void
    {
        $this->harvest(['quantity_kg' => 50])->assertCreated();

        $this->assertSame(0, Finance::where('type', 'pemasukan')->count());
        $this->assertSame(1, Harvest::count());
    }

    public function test_validasi_catatan_panen(): void
    {
        $this->harvest(['quantity_kg' => 10, 'sold_kg' => 20, 'price_per_kg' => 1000])->assertUnprocessable();
        $this->harvest(['quantity_kg' => 10, 'sold_kg' => 5])->assertUnprocessable();
        $this->harvest(['quantity_kg' => 10, 'harvest_date' => '2026-11-25'])->assertUnprocessable();
        $this->harvest(['quantity_kg' => 10, 'harvest_date' => '2000-01-01'])->assertUnprocessable();
        $this->harvest(['quantity_kg' => 0])->assertUnprocessable();

        $this->assertSame(0, Harvest::count());
    }

    public function test_buruh_tidak_bisa_panen_dan_mandor_tidak_bisa_ringkasan(): void
    {
        $planting = $this->planting();

        Sanctum::actingAs($this->t['buruh']);
        $this->postJson("/api/plantings/{$planting->id}/harvests", ['quantity_kg' => 5])->assertForbidden();
        $this->getJson("/api/plantings/{$planting->id}/harvests")->assertForbidden();
        $this->getJson("/api/plantings/{$planting->id}/summary")->assertForbidden();

        Sanctum::actingAs($this->t['mandor']);
        $this->getJson("/api/plantings/{$planting->id}/summary")->assertForbidden();
    }

    public function test_mandor_mencatat_dan_melihat_panen(): void
    {
        $planting = $this->planting();

        Sanctum::actingAs($this->t['mandor']);

        $this->postJson("/api/plantings/{$planting->id}/harvests", [
            'quantity_kg' => 40, 'sold_kg' => 10, 'price_per_kg' => 2000,
        ])->assertCreated();

        $response = $this->getJson("/api/plantings/{$planting->id}/harvests")->assertOk();

        $this->assertCount(1, $response->json('data.harvests'));
        $this->assertEquals(40, $response->json('data.harvested_kg'));
        $this->assertSame($this->t['mandor']->id, $response->json('data.harvests.0.recorded_by'));
        $this->assertSame(1, Finance::where('type', 'pemasukan')->count());
    }

    public function test_mandor_hanya_menghapus_panen_miliknya(): void
    {
        $planting = $this->planting();

        Sanctum::actingAs($this->t['owner']);
        $ownerId = $this->postJson("/api/plantings/{$planting->id}/harvests", ['quantity_kg' => 10])
            ->assertCreated()->json('data.id');

        Sanctum::actingAs($this->t['mandor']);
        $mandorId = $this->postJson("/api/plantings/{$planting->id}/harvests", ['quantity_kg' => 5])
            ->assertCreated()->json('data.id');

        $this->deleteJson("/api/harvests/{$ownerId}")->assertForbidden();
        $this->deleteJson("/api/harvests/{$mandorId}")->assertOk();

        Sanctum::actingAs($this->t['owner']);
        $this->deleteJson("/api/harvests/{$ownerId}")->assertOk();
        $this->assertSame(0, Harvest::count());
    }

    public function test_hapus_catatan_panen_menghapus_pemasukannya(): void
    {
        $id = $this->harvest(['quantity_kg' => 10, 'sold_kg' => 10, 'price_per_kg' => 1000])
            ->assertCreated()
            ->json('data.id');

        $this->deleteJson("/api/harvests/{$id}")->assertOk();

        $this->assertSame(0, Harvest::count());
        $this->assertSame(0, Finance::where('type', 'pemasukan')->count());
    }

    public function test_menyelesaikan_siklus_wajib_ada_panen(): void
    {
        Sanctum::actingAs($this->t['owner']);

        $this->postJson("/api/plantings/{$this->planting()->id}/harvest")
            ->assertUnprocessable()
            ->assertJsonValidationErrors('harvest_kg');

        $this->assertSame('berjalan', $this->planting()->fresh()->status);
    }

    public function test_menyelesaikan_siklus_dengan_panen_akhir(): void
    {
        Sanctum::actingAs($this->t['owner']);

        $this->postJson("/api/plantings/{$this->planting()->id}/harvest", [
            'harvest_kg'   => 40,
            'sold_kg'      => 40,
            'price_per_kg' => 30000,
        ])->assertOk();

        $planting = $this->planting()->fresh();

        $this->assertSame('panen', $planting->status);
        $this->assertSame('2026-11-20', $planting->closed_at->toDateString());
        $this->assertSame(1, Harvest::count());
        $this->assertEquals(1200000, Finance::where('type', 'pemasukan')->sum('amount'));

        $this->harvest(['quantity_kg' => 5])->assertUnprocessable();
    }

    public function test_menyelesaikan_siklus_dengan_panen_bertahap_tercatat(): void
    {
        $this->harvest(['quantity_kg' => 30])->assertCreated();
        $this->harvest(['quantity_kg' => 20])->assertCreated();

        $this->postJson("/api/plantings/{$this->planting()->id}/harvest")->assertOk();

        $this->assertSame('panen', $this->planting()->fresh()->status);
    }

    public function test_siklus_tidak_dapat_diselesaikan_selama_ada_tugas_berjalan(): void
    {
        $this->harvest(['quantity_kg' => 30])->assertCreated();
        $this->task('dikerjakan');

        $this->postJson("/api/plantings/{$this->planting()->id}/harvest")
            ->assertUnprocessable()
            ->assertJsonValidationErrors('planting');

        $this->assertSame('berjalan', $this->planting()->fresh()->status);
    }

    public function test_pembatalan_siklus_mengisi_tanggal_tutup(): void
    {
        Sanctum::actingAs($this->t['owner']);

        $this->postJson("/api/plantings/{$this->planting()->id}/cancel")->assertOk();

        $planting = $this->planting()->fresh();

        $this->assertSame('gagal', $planting->status);
        $this->assertSame('2026-11-20', $planting->closed_at->toDateString());
        $this->postJson("/api/plantings/{$planting->id}/cancel")->assertUnprocessable();
    }

    public function test_biaya_siklus_berasal_dari_satu_sumber_dan_tidak_ganda(): void
    {
        $this->expense(150000, 'lainnya')->assertCreated();
        $this->expense(50000, 'bahan')->assertCreated();

        $this->assertEquals(200000, $this->planting()->fresh()->total_cost);

        Finance::where('amount', 50000)->first()->delete();

        $this->assertEquals(150000, $this->planting()->fresh()->total_cost);
    }

    public function test_pemakaian_bahan_pada_laporan_masuk_biaya_sekali(): void
    {
        $task = $this->task('dikerjakan');
        $task->resources()->attach($this->t['resource']->id, [
            'company_id'        => $this->t['company']->id,
            'max_allocated_qty' => 10,
            'actual_used_qty'   => 0,
            'variance_qty'      => 0,
            'is_over_allocated' => false,
        ]);

        Sanctum::actingAs($this->t['buruh']);

        $this->postJson("/api/tasks/{$task->id}/report", [
            'media_urls' => ['foto.jpg'],
            'resources'  => [['resource_id' => $this->t['resource']->id, 'actual_used_qty' => 4]],
        ])->assertCreated();

        $cost = Finance::where('type', 'pengeluaran')->first();

        $this->assertSame('bahan', $cost->category);
        $this->assertEquals(40000, $cost->amount);
        $this->assertEquals(40000, $this->planting()->fresh()->total_cost);
    }

    public function test_ringkasan_siklus_menghitung_hpp_dan_laba(): void
    {
        $this->expense(300000, 'bahan')->assertCreated();
        $this->expense(100000, 'lainnya')->assertCreated();

        $this->harvest(['quantity_kg' => 100, 'sold_kg' => 80, 'price_per_kg' => 10000])->assertCreated();
        $this->harvest(['quantity_kg' => 100])->assertCreated();

        $response = $this->getJson("/api/plantings/{$this->planting()->id}/summary")->assertOk();

        $this->assertEquals(400000, $response->json('data.total_cost'));
        $this->assertEquals(800000, $response->json('data.income'));
        $this->assertEquals(400000, $response->json('data.profit'));
        $this->assertEquals(200, $response->json('data.harvested_kg'));
        $this->assertEquals(80, $response->json('data.sold_kg'));
        $this->assertEquals(2000, $response->json('data.hpp_per_kg'));
        $this->assertEquals(10000, $response->json('data.avg_price_per_kg'));
        $this->assertCount(2, $response->json('data.harvests'));
        $this->assertCount(2, $response->json('data.costs'));
    }

    public function test_hpp_memakai_panen_tercatat_jika_kg_tidak_dikirim(): void
    {
        $this->expense(200000)->assertCreated();

        $this->getJson("/api/plantings/{$this->planting()->id}/hpp")->assertUnprocessable();

        $this->harvest(['quantity_kg' => 100])->assertCreated();

        $recorded = $this->getJson("/api/plantings/{$this->planting()->id}/hpp")->assertOk();

        $this->assertEquals(2000, $recorded->json('data.hpp_per_kg'));
        $this->assertEquals(100, $recorded->json('data.harvest_kg'));

        $manual = $this->getJson("/api/plantings/{$this->planting()->id}/hpp?harvest_kg=50")->assertOk();

        $this->assertEquals(4000, $manual->json('data.hpp_per_kg'));
    }

    public function test_daftar_keuangan_dapat_difilter_siklus_dan_kategori(): void
    {
        $this->expense(1000, 'bahan')->assertCreated();
        $this->expense(2000, 'upah')->assertCreated();

        $this->getJson('/api/finances')->assertOk()->assertJsonCount(2, 'data');
        $this->getJson('/api/finances?category=upah')->assertOk()->assertJsonCount(1, 'data');
        $this->getJson('/api/finances?planting_id=' . $this->planting()->id)->assertOk()->assertJsonCount(2, 'data');
        $this->getJson('/api/finances?planting_id=999999')->assertOk()->assertJsonCount(0, 'data');
    }

    public function test_persetujuan_rekap_mencatat_upah_borongan_ke_siklus_tugasnya(): void
    {
        $other = new Planting();
        $other->forceFill([
            'company_id'       => $this->t['company']->id,
            'land_id'          => $this->planting()->land_id,
            'crop_name'        => 'Tomat',
            'plant_date'       => '2026-10-01',
            'est_harvest_date' => '2027-01-01',
            'status'           => 'berjalan',
            'total_cost'       => 0,
        ])->save();

        $this->wage($this->t['buruh'], 'borongan');
        $this->task('selesai', $this->t['buruh'], $this->planting(), 100000, '2026-11-05');
        $this->task('selesai', $this->t['buruh'], $other, 60000, '2026-11-06');

        Sanctum::actingAs($this->t['owner']);

        $id = $this->postJson('/api/payrolls', ['period_start' => '2026-11-01', 'period_end' => '2026-11-20'])
            ->assertCreated()->json('data.id');

        $this->assertSame(0, Finance::where('category', 'upah')->count());

        $this->postJson("/api/payrolls/{$id}/approve")->assertOk();

        $this->assertEquals(100000, Finance::where('category', 'upah')->where('planting_id', $this->planting()->id)->sum('amount'));
        $this->assertEquals(60000, Finance::where('category', 'upah')->where('planting_id', $other->id)->sum('amount'));
        $this->assertEquals(100000, $this->planting()->fresh()->total_cost);
        $this->assertSame($id, Finance::where('category', 'upah')->first()->payroll_id);
    }

    public function test_upah_harian_dibagi_menurut_tugas_terverifikasi_dan_masuk_hpp(): void
    {
        $this->wage($this->t['buruh'], 'harian', 100000);
        $this->attendance($this->t['buruh'], '2026-11-03');
        $this->attendance($this->t['buruh'], '2026-11-04');
        $this->task('selesai', $this->t['buruh'], $this->planting(), null, '2026-11-05');

        Sanctum::actingAs($this->t['owner']);

        $id = $this->postJson('/api/payrolls', ['period_start' => '2026-11-01', 'period_end' => '2026-11-20'])
            ->assertCreated()->json('data.id');

        $this->postJson("/api/payrolls/{$id}/approve")->assertOk();

        $this->assertEquals(200000, Finance::where('category', 'upah')->where('planting_id', $this->planting()->id)->sum('amount'));

        $summary = $this->getJson("/api/plantings/{$this->planting()->id}/summary")->assertOk();

        $this->assertEquals(200000, $summary->json('data.total_cost'));
        $this->assertSame('upah', $summary->json('data.costs.0.category'));
    }

    public function test_gaji_mandor_dialokasikan_ke_siklus_berjalan(): void
    {
        $this->wage($this->t['mandor'], 'bulanan', 3000000);

        Sanctum::actingAs($this->t['owner']);

        $id = $this->postJson('/api/payrolls', ['period_start' => '2026-11-01', 'period_end' => '2026-11-20'])
            ->assertCreated()->json('data.id');

        $this->postJson("/api/payrolls/{$id}/approve")->assertOk();

        $this->assertEquals(3000000, Finance::where('category', 'upah')->where('planting_id', $this->planting()->id)->sum('amount'));
    }

    public function test_gaji_dialokasikan_ke_biaya_umum_jika_tidak_ada_siklus(): void
    {
        $this->planting()->forceFill(['status' => 'panen', 'closed_at' => '2026-10-15'])->save();
        $this->wage($this->t['mandor'], 'bulanan', 3000000);

        Sanctum::actingAs($this->t['owner']);

        $id = $this->postJson('/api/payrolls', ['period_start' => '2026-11-01', 'period_end' => '2026-11-20'])
            ->assertCreated()->json('data.id');

        $this->postJson("/api/payrolls/{$id}/approve")->assertOk();

        $cost = Finance::where('category', 'upah')->first();

        $this->assertNull($cost->planting_id);
        $this->assertEquals(3000000, $cost->amount);
    }

    public function test_siklus_perusahaan_lain_tidak_dapat_diakses(): void
    {
        $b = $this->makeTenant('b');

        Sanctum::actingAs($this->t['owner']);

        $this->getJson("/api/plantings/{$b['planting']->id}/summary")->assertNotFound();
        $this->postJson("/api/plantings/{$b['planting']->id}/harvests", ['quantity_kg' => 5])->assertNotFound();
        $this->postJson("/api/plantings/{$b['planting']->id}/harvest")->assertNotFound();
    }
}
