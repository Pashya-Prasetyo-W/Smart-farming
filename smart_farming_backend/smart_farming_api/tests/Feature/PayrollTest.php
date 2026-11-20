<?php

namespace Tests\Feature;

use App\Models\Attendance;
use App\Models\Payroll;
use App\Models\Task;
use App\Models\TaskReport;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\Feature\Concerns\CreatesTenants;
use Tests\TestCase;

class PayrollTest extends TestCase
{
    use RefreshDatabase, CreatesTenants;

    private array $t;

    protected function setUp(): void
    {
        parent::setUp();

        Carbon::setTestNow(Carbon::parse('2026-11-20 03:00:00', 'UTC'));

        $this->t = $this->makeTenant('a');

        $this->setWage($this->t['buruh'], 'harian', 80000);
        $this->setWage($this->t['mandor'], 'bulanan', 4500000);
        $this->t['mandor']->allowances()->forceCreate([
            'company_id' => $this->t['company']->id,
            'name'       => 'Transport',
            'amount'     => 300000,
        ]);
    }

    protected function tearDown(): void
    {
        Carbon::setTestNow();

        parent::tearDown();
    }

    private function setWage(User $user, string $type, float $amount = 0): void
    {
        $wage = $user->wage()->firstOrNew([]);
        $wage->forceFill([
            'company_id' => $user->company_id,
            'wage_type'  => $type,
            'amount'     => $amount,
        ])->save();
    }

    private function attendance(User $user, string $date, string $status = 'terverifikasi'): Attendance
    {
        $attendance = new Attendance();
        $attendance->forceFill([
            'company_id'           => $user->company_id,
            'user_id'              => $user->id,
            'work_date'            => $date,
            'check_in_at'          => Carbon::parse($date . ' 01:00:00', 'UTC'),
            'check_out_at'         => Carbon::parse($date . ' 09:00:00', 'UTC'),
            'source'               => 'mandiri',
            'status'               => $status,
            'reviewer_role'        => 'mandor',
            'reviewer_assigned_at' => now(),
        ])->save();

        return $attendance;
    }

    private function doneTask(User $user, ?float $wage, string $reviewStatus = 'terverifikasi', string $date = '2026-11-10'): TaskReport
    {
        $task = new Task();
        $task->forceFill([
            'company_id'  => $user->company_id,
            'planting_id' => $this->t['planting']->id,
            'assigned_to' => $user->id,
            'title'       => 'Panen ' . $date,
            'task_date'   => $date,
            'due_date'    => $date,
            'status'      => $reviewStatus === 'terverifikasi' ? 'selesai' : 'menunggu_verifikasi',
            'wage_amount' => $wage,
        ])->save();

        $report = new TaskReport();
        $report->forceFill([
            'company_id'    => $user->company_id,
            'task_id'       => $task->id,
            'type'          => 'selesai',
            'media_urls'    => ['foto.jpg'],
            'reported_at'   => Carbon::parse($date . ' 10:00:00', 'UTC'),
            'review_status' => $reviewStatus,
            'reviewer_role' => 'mandor',
        ])->save();

        return $report;
    }

    private function createPayroll(string $start, string $end)
    {
        Sanctum::actingAs($this->t['owner']);

        return $this->postJson('/api/payrolls', ['period_start' => $start, 'period_end' => $end]);
    }

    private function item($response, User $user): ?array
    {
        return collect($response->json('data.items'))->firstWhere('user_id', $user->id);
    }

    public function test_upah_harian_dihitung_dari_absensi_terverifikasi(): void
    {
        $this->attendance($this->t['buruh'], '2026-11-02');
        $this->attendance($this->t['buruh'], '2026-11-03');
        $this->attendance($this->t['buruh'], '2026-11-04');
        $this->attendance($this->t['buruh'], '2026-11-05', 'menunggu');
        $this->attendance($this->t['buruh'], '2026-11-06', 'ditolak');

        $item = $this->item($this->createPayroll('2026-11-01', '2026-11-10')->assertCreated(), $this->t['buruh']);

        $this->assertSame('harian', $item['wage_type']);
        $this->assertSame(3, $item['units']);
        $this->assertEquals(240000, $item['total_amount']);
        $this->assertSame(['2026-11-02', '2026-11-03', '2026-11-04'], $item['details']['dates']);
    }

    public function test_upah_borongan_dijumlahkan_dari_tugas_terverifikasi(): void
    {
        $this->setWage($this->t['buruh'], 'borongan');

        $this->doneTask($this->t['buruh'], 120000, 'terverifikasi', '2026-11-03');
        $this->doneTask($this->t['buruh'], 50000, 'terverifikasi', '2026-11-04');
        $this->doneTask($this->t['buruh'], 70000, 'menunggu', '2026-11-05');
        $this->doneTask($this->t['buruh'], null, 'terverifikasi', '2026-11-06');

        $item = $this->item($this->createPayroll('2026-11-01', '2026-11-10')->assertCreated(), $this->t['buruh']);

        $this->assertSame('borongan', $item['wage_type']);
        $this->assertSame(2, $item['units']);
        $this->assertEquals(170000, $item['total_amount']);
        $this->assertCount(2, $item['details']['tasks']);
    }

    public function test_gaji_bulanan_mandor_ditambah_tunjangan(): void
    {
        $response = $this->createPayroll('2026-11-01', '2026-11-10')->assertCreated();

        $item = $this->item($response, $this->t['mandor']);

        $this->assertEquals(4500000, $item['base_amount']);
        $this->assertEquals(300000, $item['allowances_total']);
        $this->assertEquals(4800000, $item['total_amount']);
        $this->assertEquals(4800000, $response->json('data.total_amount'));
        $this->assertNull($this->item($response, $this->t['buruh']));
    }

    public function test_gaji_bulanan_hanya_dibayar_sekali_per_bulan(): void
    {
        $this->createPayroll('2026-11-01', '2026-11-10')->assertCreated();

        $second = $this->createPayroll('2026-11-11', '2026-11-20')->assertCreated();
        $item = $this->item($second, $this->t['mandor']);

        $this->assertEquals(0, $item['total_amount']);
        $this->assertNotNull($item['note']);
    }

    public function test_absensi_lama_ikut_dihitung_dan_tidak_dihitung_dua_kali(): void
    {
        $this->attendance($this->t['buruh'], '2026-10-28');
        $this->attendance($this->t['buruh'], '2026-11-03');
        $this->attendance($this->t['buruh'], '2026-11-12');

        $first = $this->createPayroll('2026-11-01', '2026-11-10')->assertCreated();
        $this->assertSame(2, $this->item($first, $this->t['buruh'])['units']);

        $second = $this->createPayroll('2026-11-11', '2026-11-20')->assertCreated();
        $this->assertSame(1, $this->item($second, $this->t['buruh'])['units']);
    }

    public function test_absensi_yang_terlambat_diverifikasi_masuk_periode_berikutnya(): void
    {
        $late = $this->attendance($this->t['buruh'], '2026-11-05', 'menunggu');

        $first = $this->createPayroll('2026-11-01', '2026-11-10')->assertCreated();
        $this->assertNull($this->item($first, $this->t['buruh']));
        $this->assertSame(1, $first->json('data.warnings.pending_attendances'));

        $late->forceFill(['status' => 'terverifikasi'])->save();

        $second = $this->createPayroll('2026-11-11', '2026-11-20')->assertCreated();
        $this->assertSame(1, $this->item($second, $this->t['buruh'])['units']);
    }

    public function test_hitung_ulang_draf_menangkap_verifikasi_baru(): void
    {
        $late = $this->attendance($this->t['buruh'], '2026-11-05', 'menunggu');

        $payroll = $this->createPayroll('2026-11-01', '2026-11-10')->assertCreated()->json('data.id');

        $late->forceFill(['status' => 'terverifikasi'])->save();

        $this->postJson("/api/payrolls/{$payroll}/recalculate")
            ->assertOk()
            ->assertJsonPath('data.items.0.wage_type', 'harian')
            ->assertJsonPath('data.items.0.units', 1);

        $this->postJson("/api/payrolls/{$payroll}/recalculate")->assertOk();

        $this->assertSame(1, Attendance::where('payroll_id', $payroll)->count());
    }

    public function test_hapus_draf_membebaskan_absensi(): void
    {
        $this->attendance($this->t['buruh'], '2026-11-03');

        $payroll = $this->createPayroll('2026-11-01', '2026-11-10')->assertCreated()->json('data.id');
        $this->assertSame(1, Attendance::where('payroll_id', $payroll)->count());

        $this->deleteJson("/api/payrolls/{$payroll}")->assertOk();

        $this->assertSame(0, Attendance::whereNotNull('payroll_id')->count());

        $again = $this->createPayroll('2026-11-01', '2026-11-10')->assertCreated();
        $this->assertSame(1, $this->item($again, $this->t['buruh'])['units']);
    }

    public function test_alur_persetujuan_dan_pembayaran(): void
    {
        $this->attendance($this->t['buruh'], '2026-11-03');

        $payroll = $this->createPayroll('2026-11-01', '2026-11-10')->assertCreated()->json('data.id');

        $this->postJson("/api/payrolls/{$payroll}/pay")->assertUnprocessable();

        $this->postJson("/api/payrolls/{$payroll}/approve")
            ->assertOk()
            ->assertJsonPath('data.status', 'disetujui')
            ->assertJsonPath('data.approver.id', $this->t['owner']->id);

        $this->postJson("/api/payrolls/{$payroll}/approve")->assertUnprocessable();
        $this->postJson("/api/payrolls/{$payroll}/recalculate")->assertUnprocessable();
        $this->deleteJson("/api/payrolls/{$payroll}")->assertUnprocessable();

        $this->postJson("/api/payrolls/{$payroll}/pay")
            ->assertOk()
            ->assertJsonPath('data.status', 'dibayar');

        $this->postJson("/api/payrolls/{$payroll}/pay")->assertUnprocessable();
    }

    public function test_perubahan_upah_tidak_mengubah_rekap_yang_disetujui(): void
    {
        $this->attendance($this->t['buruh'], '2026-11-03');

        $payroll = $this->createPayroll('2026-11-01', '2026-11-10')->assertCreated()->json('data.id');
        $this->postJson("/api/payrolls/{$payroll}/approve")->assertOk();

        $this->setWage($this->t['buruh'], 'harian', 200000);

        $this->getJson("/api/payrolls/{$payroll}")
            ->assertOk()
            ->assertJsonPath('data.items.0.rate', '80000.00');
    }

    public function test_rekap_kosong_tidak_dapat_disetujui(): void
    {
        $this->t['mandor']->forceFill(['is_active' => false])->save();

        $payroll = $this->createPayroll('2026-11-01', '2026-11-10')->assertCreated()->json('data.id');

        $this->postJson("/api/payrolls/{$payroll}/approve")->assertUnprocessable();
    }

    public function test_validasi_periode(): void
    {
        $this->createPayroll('2026-11-10', '2026-11-05')->assertUnprocessable()->assertJsonValidationErrors('period_end');
        $this->createPayroll('2026-10-25', '2026-11-05')->assertUnprocessable()->assertJsonValidationErrors('period_end');
        $this->createPayroll('2026-11-15', '2026-11-25')->assertUnprocessable()->assertJsonValidationErrors('period_end');
        $this->createPayroll('November', '2026-11-05')->assertUnprocessable()->assertJsonValidationErrors('period_start');

        $this->createPayroll('2026-11-01', '2026-11-10')->assertCreated();
        $this->createPayroll('2026-11-10', '2026-11-15')->assertUnprocessable()->assertJsonValidationErrors('period_start');
    }

    public function test_hanya_pemilik_mengelola_rekap_upah(): void
    {
        $payroll = $this->createPayroll('2026-11-01', '2026-11-10')->assertCreated()->json('data.id');

        foreach (['mandor', 'buruh'] as $role) {
            Sanctum::actingAs($this->t[$role]);

            $this->getJson('/api/payrolls')->assertForbidden();
            $this->postJson('/api/payrolls', ['period_start' => '2026-11-11', 'period_end' => '2026-11-12'])->assertForbidden();
            $this->getJson("/api/payrolls/{$payroll}")->assertForbidden();
            $this->postJson("/api/payrolls/{$payroll}/approve")->assertForbidden();
            $this->postJson("/api/payrolls/{$payroll}/pay")->assertForbidden();
            $this->deleteJson("/api/payrolls/{$payroll}")->assertForbidden();
        }
    }

    public function test_karyawan_hanya_melihat_slip_sendiri_dari_rekap_yang_disetujui(): void
    {
        $this->attendance($this->t['buruh'], '2026-11-03');

        $payroll = $this->createPayroll('2026-11-01', '2026-11-10')->assertCreated()->json('data.id');

        Sanctum::actingAs($this->t['buruh']);
        $this->getJson('/api/payrolls/mine')->assertOk()->assertJsonCount(0, 'data');

        Sanctum::actingAs($this->t['owner']);
        $this->postJson("/api/payrolls/{$payroll}/approve")->assertOk();

        Sanctum::actingAs($this->t['buruh']);
        $this->getJson('/api/payrolls/mine')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.user_id', $this->t['buruh']->id)
            ->assertJsonPath('data.0.payroll.status', 'disetujui');

        Sanctum::actingAs($this->t['mandor']);
        $this->getJson('/api/payrolls/mine')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.user_id', $this->t['mandor']->id);

        Sanctum::actingAs($this->t['owner']);
        $this->getJson('/api/payrolls/mine')->assertForbidden();
    }

    public function test_karyawan_dengan_riwayat_absensi_tidak_dapat_dihapus(): void
    {
        $this->attendance($this->t['buruh'], '2026-11-03');

        Sanctum::actingAs($this->t['owner']);

        $this->deleteJson('/api/workers/' . $this->t['buruh']->id)->assertUnprocessable();
        $this->assertNotNull(User::find($this->t['buruh']->id));
    }

    public function test_rekap_perusahaan_lain_tidak_dapat_diakses(): void
    {
        $b = $this->makeTenant('b');

        Sanctum::actingAs($b['owner']);
        $foreign = $this->postJson('/api/payrolls', [
            'period_start' => '2026-11-01',
            'period_end'   => '2026-11-10',
        ])->assertCreated()->json('data.id');

        Sanctum::actingAs($this->t['owner']);

        $this->getJson("/api/payrolls/{$foreign}")->assertNotFound();
        $this->postJson("/api/payrolls/{$foreign}/approve")->assertNotFound();
        $this->getJson('/api/payrolls')->assertOk()->assertJsonCount(0, 'data');
        $this->assertSame(1, Payroll::withoutGlobalScopes()->where('company_id', $b['company']->id)->count());
    }
}
