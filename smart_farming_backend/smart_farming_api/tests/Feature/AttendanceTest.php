<?php

namespace Tests\Feature;

use App\Models\Attendance;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\Feature\Concerns\CreatesTenants;
use Tests\TestCase;

class AttendanceTest extends TestCase
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

    private function makeAttendance(User $user, string $date, array $overrides = []): Attendance
    {
        $attendance = new Attendance();
        $attendance->forceFill(array_merge([
            'company_id'           => $user->company_id,
            'user_id'              => $user->id,
            'work_date'            => $date,
            'check_in_at'          => Carbon::parse($date . ' 01:00:00', 'UTC'),
            'check_out_at'         => Carbon::parse($date . ' 09:00:00', 'UTC'),
            'source'               => 'mandiri',
            'status'               => 'menunggu',
            'reviewer_role'        => $user->role === 'mandor' ? 'pemilik' : 'mandor',
            'reviewer_assigned_at' => now(),
        ], $overrides))->save();

        return $attendance;
    }

    public function test_buruh_dapat_absen_masuk_dan_pulang(): void
    {
        Sanctum::actingAs($this->t['buruh']);

        $this->postJson('/api/attendances/check-in')
            ->assertCreated()
            ->assertJsonPath('data.status', 'menunggu')
            ->assertJsonPath('data.reviewer_role', 'mandor')
            ->assertJsonPath('data.work_date', '2026-11-20');

        $this->postJson('/api/attendances/check-out')
            ->assertOk()
            ->assertJsonPath('data.user.id', $this->t['buruh']->id);

        $this->assertNotNull(Attendance::first()->check_out_at);
        $this->getJson('/api/attendances/today')
            ->assertOk()
            ->assertJsonPath('data.id', Attendance::first()->id);
    }

    public function test_absen_masuk_hanya_sekali_sehari_dan_pulang_hanya_sekali(): void
    {
        Sanctum::actingAs($this->t['buruh']);

        $this->postJson('/api/attendances/check-out')->assertUnprocessable();

        $this->postJson('/api/attendances/check-in')->assertCreated();
        $this->postJson('/api/attendances/check-in')->assertUnprocessable();

        $this->postJson('/api/attendances/check-out')->assertOk();
        $this->postJson('/api/attendances/check-out')->assertUnprocessable();

        $this->assertSame(1, Attendance::count());
    }

    public function test_tanggal_kerja_mengikuti_zona_waktu_bisnis(): void
    {
        Carbon::setTestNow(Carbon::parse('2026-11-20 20:00:00', 'UTC'));

        Sanctum::actingAs($this->t['buruh']);

        $this->postJson('/api/attendances/check-in')
            ->assertCreated()
            ->assertJsonPath('data.work_date', '2026-11-21');
    }

    public function test_mandor_absen_dan_diverifikasi_pemilik(): void
    {
        Sanctum::actingAs($this->t['mandor']);

        $this->postJson('/api/attendances/check-in')
            ->assertCreated()
            ->assertJsonPath('data.reviewer_role', 'pemilik');
    }

    public function test_pemilik_tidak_dapat_absen(): void
    {
        Sanctum::actingAs($this->t['owner']);

        $this->postJson('/api/attendances/check-in')->assertForbidden();
        $this->getJson('/api/attendances/mine')->assertForbidden();
    }

    public function test_akun_nonaktif_tidak_dapat_absen(): void
    {
        $this->t['buruh']->forceFill(['is_active' => false])->save();

        Sanctum::actingAs($this->t['buruh']);

        $this->postJson('/api/attendances/check-in')->assertForbidden();
    }

    public function test_mandor_memverifikasi_absensi_buruh_setelah_pulang(): void
    {
        $attendance = $this->makeAttendance($this->t['buruh'], '2026-11-20');

        Sanctum::actingAs($this->t['mandor']);

        $this->postJson("/api/attendances/{$attendance->id}/verify")
            ->assertOk()
            ->assertJsonPath('data.status', 'terverifikasi')
            ->assertJsonPath('data.reviewer.id', $this->t['mandor']->id);

        $this->postJson("/api/attendances/{$attendance->id}/verify")->assertUnprocessable();
    }

    public function test_absensi_hari_ini_belum_pulang_tidak_dapat_diverifikasi_tetapi_hari_lalu_dapat(): void
    {
        $today = $this->makeAttendance($this->t['buruh'], '2026-11-20', ['check_out_at' => null]);

        Sanctum::actingAs($this->t['mandor']);

        $this->postJson("/api/attendances/{$today->id}/verify")->assertUnprocessable();

        $today->delete();
        $past = $this->makeAttendance($this->t['buruh'], '2026-11-18', ['check_out_at' => null]);

        $this->postJson("/api/attendances/{$past->id}/verify")->assertOk();
    }

    public function test_mandor_tidak_dapat_memverifikasi_absensi_mandor_atau_miliknya_sendiri(): void
    {
        $other = User::create([
            'name'       => 'Mandor lain',
            'email'      => 'mandor-lain@test.com',
            'password'   => 'password123',
            'role'       => 'mandor',
            'company_id' => $this->t['company']->id,
        ]);

        $mine = $this->makeAttendance($this->t['mandor'], '2026-11-19');
        $others = $this->makeAttendance($other, '2026-11-19');

        Sanctum::actingAs($this->t['mandor']);

        $this->postJson("/api/attendances/{$mine->id}/verify")->assertForbidden();
        $this->postJson("/api/attendances/{$others->id}/verify")->assertForbidden();
        $this->postJson("/api/attendances/{$others->id}/reject", ['reason' => 'x'])->assertForbidden();
    }

    public function test_pemilik_memverifikasi_absensi_mandor(): void
    {
        $attendance = $this->makeAttendance($this->t['mandor'], '2026-11-19');

        Sanctum::actingAs($this->t['owner']);

        $this->postJson("/api/attendances/{$attendance->id}/verify")
            ->assertOk()
            ->assertJsonPath('data.status', 'terverifikasi')
            ->assertJsonPath('data.reviewed_role', 'pemilik');
    }

    public function test_buruh_tidak_dapat_memverifikasi(): void
    {
        $attendance = $this->makeAttendance($this->t['buruh'], '2026-11-19');

        Sanctum::actingAs($this->t['buruh']);

        $this->postJson("/api/attendances/{$attendance->id}/verify")->assertForbidden();
        $this->postJson("/api/attendances/{$attendance->id}/reject", ['reason' => 'x'])->assertForbidden();
        $this->getJson('/api/attendances/queue')->assertForbidden();
    }

    public function test_penolakan_wajib_alasan(): void
    {
        $attendance = $this->makeAttendance($this->t['buruh'], '2026-11-19');

        Sanctum::actingAs($this->t['mandor']);

        $this->postJson("/api/attendances/{$attendance->id}/reject")
            ->assertUnprocessable()
            ->assertJsonValidationErrors('reason');

        $this->postJson("/api/attendances/{$attendance->id}/reject", ['reason' => 'Tidak terlihat di lahan'])
            ->assertOk()
            ->assertJsonPath('data.status', 'ditolak')
            ->assertJsonPath('data.reject_reason', 'Tidak terlihat di lahan');
    }

    public function test_keberatan_buruh_ke_mandor_lalu_ke_pemilik_dan_final(): void
    {
        $attendance = $this->makeAttendance($this->t['buruh'], '2026-11-19');

        Sanctum::actingAs($this->t['mandor']);
        $this->postJson("/api/attendances/{$attendance->id}/reject", ['reason' => 'Salah'])->assertOk();

        Sanctum::actingAs($this->t['buruh']);
        $this->postJson("/api/attendances/{$attendance->id}/object", ['note' => 'Saya hadir'])
            ->assertOk()
            ->assertJsonPath('data.status', 'keberatan')
            ->assertJsonPath('data.reviewer_role', 'mandor')
            ->assertJsonPath('data.objection_count', 1);

        Sanctum::actingAs($this->t['mandor']);
        $this->postJson("/api/attendances/{$attendance->id}/reject", ['reason' => 'Tetap tidak'])->assertOk();

        Sanctum::actingAs($this->t['buruh']);
        $this->postJson("/api/attendances/{$attendance->id}/object", ['note' => 'Banding ke pemilik'])
            ->assertOk()
            ->assertJsonPath('data.reviewer_role', 'pemilik')
            ->assertJsonPath('data.objection_count', 2);

        Sanctum::actingAs($this->t['mandor']);
        $this->postJson("/api/attendances/{$attendance->id}/verify")->assertForbidden();

        Sanctum::actingAs($this->t['owner']);
        $this->postJson("/api/attendances/{$attendance->id}/reject", ['reason' => 'Final'])
            ->assertOk()
            ->assertJsonPath('data.is_final', true);

        Sanctum::actingAs($this->t['buruh']);
        $this->postJson("/api/attendances/{$attendance->id}/object", ['note' => 'Lagi'])->assertUnprocessable();
    }

    public function test_penolakan_pemilik_atas_keberatan_pertama_bersifat_final(): void
    {
        $attendance = $this->makeAttendance($this->t['mandor'], '2026-11-19');

        Sanctum::actingAs($this->t['owner']);
        $this->postJson("/api/attendances/{$attendance->id}/reject", ['reason' => 'Salah'])
            ->assertOk()
            ->assertJsonPath('data.is_final', false);

        Sanctum::actingAs($this->t['mandor']);
        $this->postJson("/api/attendances/{$attendance->id}/object", ['note' => 'Saya hadir'])
            ->assertOk()
            ->assertJsonPath('data.reviewer_role', 'pemilik');

        Sanctum::actingAs($this->t['owner']);
        $this->postJson("/api/attendances/{$attendance->id}/reject", ['reason' => 'Tetap'])
            ->assertOk()
            ->assertJsonPath('data.is_final', true);

        Sanctum::actingAs($this->t['mandor']);
        $this->postJson("/api/attendances/{$attendance->id}/object", ['note' => 'Lagi'])->assertUnprocessable();
    }

    public function test_keberatan_hanya_oleh_pemilik_absensi_dan_hanya_saat_ditolak(): void
    {
        $attendance = $this->makeAttendance($this->t['buruh'], '2026-11-19');

        Sanctum::actingAs($this->t['buruh']);
        $this->postJson("/api/attendances/{$attendance->id}/object", ['note' => 'x'])->assertUnprocessable();

        Sanctum::actingAs($this->t['mandor']);
        $this->postJson("/api/attendances/{$attendance->id}/reject", ['reason' => 'Salah'])->assertOk();

        $stranger = User::create([
            'name'       => 'Buruh lain',
            'email'      => 'buruh-lain@test.com',
            'password'   => 'password123',
            'role'       => 'buruh',
            'company_id' => $this->t['company']->id,
        ]);

        Sanctum::actingAs($stranger);
        $this->postJson("/api/attendances/{$attendance->id}/object", ['note' => 'x'])->assertForbidden();
    }

    public function test_absensi_menunggu_lebih_dari_24_jam_naik_ke_pemilik(): void
    {
        $attendance = $this->makeAttendance($this->t['buruh'], '2026-11-19', [
            'reviewer_assigned_at' => now()->subHours(25),
        ]);

        Sanctum::actingAs($this->t['mandor']);
        $this->getJson('/api/attendances/queue')->assertOk()->assertJsonCount(0, 'data');

        $attendance->refresh();
        $this->assertSame('pemilik', $attendance->reviewer_role);
        $this->assertNotNull($attendance->escalated_at);
        $this->postJson("/api/attendances/{$attendance->id}/verify")->assertForbidden();

        Sanctum::actingAs($this->t['owner']);
        $this->getJson('/api/attendances/queue')->assertOk()->assertJsonCount(1, 'data');
        $this->postJson("/api/attendances/{$attendance->id}/verify")->assertOk();
    }

    public function test_absensi_di_bawah_24_jam_tidak_dinaikkan(): void
    {
        $this->makeAttendance($this->t['buruh'], '2026-11-19', [
            'reviewer_assigned_at' => now()->subHours(23),
        ]);

        $this->artisan('attendances:escalate')->assertSuccessful();

        $this->assertSame('mandor', Attendance::first()->reviewer_role);
    }

    public function test_perintah_eskalasi_menaikkan_absensi_tertunda(): void
    {
        $this->makeAttendance($this->t['buruh'], '2026-11-18', [
            'reviewer_assigned_at' => now()->subHours(30),
        ]);

        $this->artisan('attendances:escalate')->assertSuccessful();

        $this->assertSame('pemilik', Attendance::first()->reviewer_role);
    }

    public function test_antrean_mandor_hanya_buruh_dan_pemilik_melihat_semua(): void
    {
        $this->makeAttendance($this->t['buruh'], '2026-11-19');
        $this->makeAttendance($this->t['mandor'], '2026-11-19');

        Sanctum::actingAs($this->t['mandor']);
        $this->getJson('/api/attendances/queue')->assertOk()->assertJsonCount(1, 'data');

        Sanctum::actingAs($this->t['owner']);
        $this->getJson('/api/attendances/queue')->assertOk()->assertJsonCount(2, 'data');
    }

    public function test_riwayat_dapat_difilter_dan_dibatasi_per_peran(): void
    {
        $this->makeAttendance($this->t['buruh'], '2026-11-19');
        $this->makeAttendance($this->t['buruh'], '2026-11-10', ['status' => 'terverifikasi']);
        $this->makeAttendance($this->t['mandor'], '2026-11-19');

        Sanctum::actingAs($this->t['mandor']);
        $this->getJson('/api/attendances?from=2026-11-01&to=2026-11-30')
            ->assertOk()
            ->assertJsonCount(2, 'data');

        Sanctum::actingAs($this->t['owner']);
        $this->getJson('/api/attendances?from=2026-11-01&to=2026-11-30')
            ->assertOk()
            ->assertJsonCount(3, 'data');

        $this->getJson('/api/attendances?from=2026-11-01&to=2026-11-30&status=terverifikasi')
            ->assertOk()
            ->assertJsonCount(1, 'data');

        $this->getJson('/api/attendances?from=2026-11-01&to=2026-11-30&user_id=' . $this->t['mandor']->id)
            ->assertOk()
            ->assertJsonCount(1, 'data');
    }

    public function test_karyawan_hanya_melihat_absensi_sendiri(): void
    {
        $this->makeAttendance($this->t['buruh'], '2026-11-19');
        $this->makeAttendance($this->t['mandor'], '2026-11-19');

        Sanctum::actingAs($this->t['buruh']);

        $this->getJson('/api/attendances/mine')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.user_id', $this->t['buruh']->id);
    }

    public function test_mandor_mencatat_absensi_buruh_langsung_terverifikasi(): void
    {
        Sanctum::actingAs($this->t['mandor']);

        $this->postJson('/api/attendances', [
            'user_id'        => $this->t['buruh']->id,
            'work_date'      => '2026-11-18',
            'check_in_time'  => '08:00',
            'check_out_time' => '16:00',
        ])
            ->assertCreated()
            ->assertJsonPath('data.status', 'terverifikasi')
            ->assertJsonPath('data.source', 'dicatat')
            ->assertJsonPath('data.recorder.id', $this->t['mandor']->id);

        $attendance = Attendance::first();
        $this->assertSame('01:00', $attendance->check_in_at->format('H:i'));
        $this->assertSame('09:00', $attendance->check_out_at->format('H:i'));
    }

    public function test_pencatatan_manual_dibatasi_aturan(): void
    {
        Sanctum::actingAs($this->t['mandor']);

        $payload = [
            'user_id'       => $this->t['buruh']->id,
            'work_date'     => '2026-11-18',
            'check_in_time' => '08:00',
        ];

        $this->postJson('/api/attendances', array_merge($payload, ['user_id' => $this->t['mandor']->id]))
            ->assertUnprocessable();

        $this->postJson('/api/attendances', array_merge($payload, ['work_date' => '2026-11-25']))
            ->assertUnprocessable();

        $this->postJson('/api/attendances', array_merge($payload, ['work_date' => '2026-11-05']))
            ->assertUnprocessable();

        $this->postJson('/api/attendances', array_merge($payload, ['check_out_time' => '07:00']))
            ->assertUnprocessable();

        $this->postJson('/api/attendances', $payload)->assertCreated();
        $this->postJson('/api/attendances', $payload)->assertUnprocessable();
    }

    public function test_pemilik_mencatat_absensi_mandor_hingga_31_hari(): void
    {
        Sanctum::actingAs($this->t['owner']);

        $this->postJson('/api/attendances', [
            'user_id'       => $this->t['mandor']->id,
            'work_date'     => '2026-10-25',
            'check_in_time' => '08:00',
        ])->assertCreated()->assertJsonPath('data.reviewed_role', 'pemilik');

        $this->postJson('/api/attendances', [
            'user_id'       => $this->t['buruh']->id,
            'work_date'     => '2026-10-01',
            'check_in_time' => '08:00',
        ])->assertUnprocessable();
    }

    public function test_pencatatan_manual_untuk_perusahaan_lain_ditolak(): void
    {
        $b = $this->makeTenant('b');

        Sanctum::actingAs($this->t['owner']);

        $this->postJson('/api/attendances', [
            'user_id'       => $b['buruh']->id,
            'work_date'     => '2026-11-18',
            'check_in_time' => '08:00',
        ])->assertUnprocessable();
    }

    public function test_absensi_perusahaan_lain_tidak_dapat_diakses(): void
    {
        $b = $this->makeTenant('b');
        $foreign = $this->makeAttendance($b['buruh'], '2026-11-19');

        Sanctum::actingAs($this->t['owner']);

        $this->postJson("/api/attendances/{$foreign->id}/verify")->assertNotFound();
        $this->postJson("/api/attendances/{$foreign->id}/reject", ['reason' => 'x'])->assertNotFound();
        $this->getJson('/api/attendances?from=2026-11-01&to=2026-11-30')
            ->assertOk()
            ->assertJsonCount(0, 'data');
    }
}
