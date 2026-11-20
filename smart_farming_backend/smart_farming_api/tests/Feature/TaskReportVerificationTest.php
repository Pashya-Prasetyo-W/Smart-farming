<?php

namespace Tests\Feature;

use App\Models\Task;
use App\Models\TaskReport;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\Feature\Concerns\CreatesTenants;
use Tests\TestCase;

class TaskReportVerificationTest extends TestCase
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

    private function makeTask(User $assignee, string $status = 'dikerjakan', ?array $tenant = null): Task
    {
        $tenant ??= $this->t;

        $task = new Task();
        $task->forceFill([
            'company_id'  => $tenant['company']->id,
            'planting_id' => $tenant['planting']->id,
            'assigned_to' => $assignee->id,
            'title'       => 'Penyiraman',
            'task_date'   => '2026-11-20',
            'due_date'    => '2026-11-21',
            'status'      => $status,
        ])->save();

        return $task;
    }

    private function submitReport(User $worker, Task $task): TaskReport
    {
        Sanctum::actingAs($worker);

        $this->postJson("/api/tasks/{$task->id}/report", ['media_urls' => ['foto.jpg']])
            ->assertCreated();

        return TaskReport::where('task_id', $task->id)->firstOrFail();
    }

    private function pendingReport(?User $worker = null): TaskReport
    {
        $worker ??= $this->t['buruh'];

        return $this->submitReport($worker, $this->makeTask($worker));
    }

    public function test_laporan_buruh_menunggu_verifikasi_mandor(): void
    {
        $report = $this->pendingReport();

        $this->assertSame('menunggu', $report->review_status);
        $this->assertSame('mandor', $report->reviewer_role);
        $this->assertSame('menunggu_verifikasi', $report->task->fresh()->status->value);
    }

    public function test_laporan_mandor_menunggu_verifikasi_pemilik(): void
    {
        $report = $this->pendingReport($this->t['mandor']);

        $this->assertSame('pemilik', $report->reviewer_role);
    }

    public function test_mandor_memverifikasi_laporan_buruh(): void
    {
        $report = $this->pendingReport();

        Sanctum::actingAs($this->t['mandor']);

        $this->postJson("/api/task-reports/{$report->id}/verify")
            ->assertOk()
            ->assertJsonPath('data.review_status', 'terverifikasi')
            ->assertJsonPath('data.reviewer.id', $this->t['mandor']->id)
            ->assertJsonPath('data.task.status', 'selesai');

        $this->assertSame('selesai', $report->task->fresh()->status->value);
        $this->postJson("/api/task-reports/{$report->id}/verify")->assertUnprocessable();
    }

    public function test_penolakan_wajib_alasan_dan_mengubah_status_tugas(): void
    {
        $report = $this->pendingReport();

        Sanctum::actingAs($this->t['mandor']);

        $this->postJson("/api/task-reports/{$report->id}/reject")
            ->assertUnprocessable()
            ->assertJsonValidationErrors('reason');

        $this->postJson("/api/task-reports/{$report->id}/reject", ['reason' => 'Foto tidak jelas'])
            ->assertOk()
            ->assertJsonPath('data.review_status', 'ditolak')
            ->assertJsonPath('data.reject_reason', 'Foto tidak jelas');

        $this->assertSame('ditolak', $report->task->fresh()->status->value);
    }

    public function test_mandor_tidak_dapat_memverifikasi_laporan_sendiri_atau_mandor_lain(): void
    {
        $other = User::create([
            'name'       => 'Mandor lain',
            'email'      => 'mandor-lain@test.com',
            'password'   => 'password123',
            'role'       => 'mandor',
            'company_id' => $this->t['company']->id,
        ]);

        $mine = $this->pendingReport($this->t['mandor']);
        $others = $this->pendingReport($other);

        Sanctum::actingAs($this->t['mandor']);

        $this->postJson("/api/task-reports/{$mine->id}/verify")->assertForbidden();
        $this->postJson("/api/task-reports/{$others->id}/verify")->assertForbidden();
        $this->postJson("/api/task-reports/{$others->id}/reject", ['reason' => 'x'])->assertForbidden();
    }

    public function test_pemilik_memverifikasi_laporan_mandor(): void
    {
        $report = $this->pendingReport($this->t['mandor']);

        Sanctum::actingAs($this->t['owner']);

        $this->postJson("/api/task-reports/{$report->id}/verify")
            ->assertOk()
            ->assertJsonPath('data.reviewed_role', 'pemilik');

        $this->assertSame('selesai', $report->task->fresh()->status->value);
    }

    public function test_buruh_tidak_dapat_memverifikasi_atau_melihat_antrean(): void
    {
        $report = $this->pendingReport();

        Sanctum::actingAs($this->t['buruh']);

        $this->postJson("/api/task-reports/{$report->id}/verify")->assertForbidden();
        $this->postJson("/api/task-reports/{$report->id}/reject", ['reason' => 'x'])->assertForbidden();
        $this->getJson('/api/task-reports/queue')->assertForbidden();
        $this->getJson('/api/task-reports')->assertForbidden();
    }

    public function test_keberatan_buruh_ke_mandor_lalu_ke_pemilik_dan_final(): void
    {
        $report = $this->pendingReport();

        Sanctum::actingAs($this->t['mandor']);
        $this->postJson("/api/task-reports/{$report->id}/reject", ['reason' => 'Kurang'])->assertOk();

        Sanctum::actingAs($this->t['buruh']);
        $this->postJson("/api/task-reports/{$report->id}/object", ['note' => 'Sudah benar'])
            ->assertOk()
            ->assertJsonPath('data.review_status', 'keberatan')
            ->assertJsonPath('data.reviewer_role', 'mandor')
            ->assertJsonPath('data.objection_count', 1);

        $this->assertSame('menunggu_verifikasi', $report->task->fresh()->status->value);

        Sanctum::actingAs($this->t['mandor']);
        $this->postJson("/api/task-reports/{$report->id}/reject", ['reason' => 'Tetap kurang'])->assertOk();

        Sanctum::actingAs($this->t['buruh']);
        $this->postJson("/api/task-reports/{$report->id}/object", ['note' => 'Banding'])
            ->assertOk()
            ->assertJsonPath('data.reviewer_role', 'pemilik')
            ->assertJsonPath('data.objection_count', 2);

        Sanctum::actingAs($this->t['mandor']);
        $this->postJson("/api/task-reports/{$report->id}/verify")->assertForbidden();

        Sanctum::actingAs($this->t['owner']);
        $this->postJson("/api/task-reports/{$report->id}/reject", ['reason' => 'Final'])
            ->assertOk()
            ->assertJsonPath('data.is_final', true);

        $this->assertSame('ditolak', $report->task->fresh()->status->value);

        Sanctum::actingAs($this->t['buruh']);
        $this->postJson("/api/task-reports/{$report->id}/object", ['note' => 'Lagi'])->assertUnprocessable();
    }

    public function test_penolakan_pemilik_atas_keberatan_pertama_mandor_bersifat_final(): void
    {
        $report = $this->pendingReport($this->t['mandor']);

        Sanctum::actingAs($this->t['owner']);
        $this->postJson("/api/task-reports/{$report->id}/reject", ['reason' => 'Kurang'])
            ->assertOk()
            ->assertJsonPath('data.is_final', false);

        Sanctum::actingAs($this->t['mandor']);
        $this->postJson("/api/task-reports/{$report->id}/object", ['note' => 'Sudah benar'])
            ->assertOk()
            ->assertJsonPath('data.reviewer_role', 'pemilik');

        Sanctum::actingAs($this->t['owner']);
        $this->postJson("/api/task-reports/{$report->id}/reject", ['reason' => 'Tetap'])
            ->assertOk()
            ->assertJsonPath('data.is_final', true);

        Sanctum::actingAs($this->t['mandor']);
        $this->postJson("/api/task-reports/{$report->id}/object", ['note' => 'Lagi'])->assertUnprocessable();
    }

    public function test_keberatan_hanya_oleh_pelaksana_dan_hanya_saat_ditolak(): void
    {
        $report = $this->pendingReport();

        Sanctum::actingAs($this->t['buruh']);
        $this->postJson("/api/task-reports/{$report->id}/object", ['note' => 'x'])->assertUnprocessable();

        Sanctum::actingAs($this->t['mandor']);
        $this->postJson("/api/task-reports/{$report->id}/reject", ['reason' => 'Kurang'])->assertOk();

        $stranger = User::create([
            'name'       => 'Buruh lain',
            'email'      => 'buruh-lain@test.com',
            'password'   => 'password123',
            'role'       => 'buruh',
            'company_id' => $this->t['company']->id,
        ]);

        Sanctum::actingAs($stranger);
        $this->postJson("/api/task-reports/{$report->id}/object", ['note' => 'x'])->assertForbidden();
    }

    public function test_laporan_menunggu_lebih_dari_24_jam_naik_ke_pemilik(): void
    {
        $report = $this->pendingReport();
        $report->forceFill(['reviewer_assigned_at' => now()->subHours(25)])->save();

        Sanctum::actingAs($this->t['mandor']);
        $this->getJson('/api/task-reports/queue')->assertOk()->assertJsonCount(0, 'data');

        $report->refresh();
        $this->assertSame('pemilik', $report->reviewer_role);
        $this->assertNotNull($report->escalated_at);
        $this->postJson("/api/task-reports/{$report->id}/verify")->assertForbidden();

        Sanctum::actingAs($this->t['owner']);
        $this->getJson('/api/task-reports/queue')->assertOk()->assertJsonCount(1, 'data');
        $this->postJson("/api/task-reports/{$report->id}/verify")->assertOk();
    }

    public function test_laporan_di_bawah_24_jam_tidak_dinaikkan(): void
    {
        $report = $this->pendingReport();
        $report->forceFill(['reviewer_assigned_at' => now()->subHours(23)])->save();

        $this->artisan('reports:escalate')->assertSuccessful();

        $this->assertSame('mandor', $report->fresh()->reviewer_role);
    }

    public function test_perintah_eskalasi_menaikkan_laporan_tertunda(): void
    {
        $report = $this->pendingReport();
        $report->forceFill(['reviewer_assigned_at' => now()->subHours(30)])->save();

        $this->artisan('reports:escalate')->assertSuccessful();

        $this->assertSame('pemilik', $report->fresh()->reviewer_role);
    }

    public function test_antrean_mandor_hanya_buruh_dan_pemilik_melihat_semua(): void
    {
        $this->pendingReport();
        $this->pendingReport($this->t['mandor']);

        Sanctum::actingAs($this->t['mandor']);
        $this->getJson('/api/task-reports/queue')->assertOk()->assertJsonCount(1, 'data');

        Sanctum::actingAs($this->t['owner']);
        $this->getJson('/api/task-reports/queue')->assertOk()->assertJsonCount(2, 'data');
    }

    public function test_riwayat_dapat_difilter_dan_dibatasi_per_peran(): void
    {
        $verified = $this->pendingReport();
        $this->pendingReport($this->t['mandor']);

        Sanctum::actingAs($this->t['mandor']);
        $this->postJson("/api/task-reports/{$verified->id}/verify")->assertOk();

        $this->getJson('/api/task-reports')->assertOk()->assertJsonCount(1, 'data');

        Sanctum::actingAs($this->t['owner']);
        $this->getJson('/api/task-reports')->assertOk()->assertJsonCount(2, 'data');
        $this->getJson('/api/task-reports?status=terverifikasi')->assertOk()->assertJsonCount(1, 'data');
        $this->getJson('/api/task-reports?user_id=' . $this->t['mandor']->id)->assertOk()->assertJsonCount(1, 'data');
        $this->getJson('/api/task-reports?from=2026-11-21')->assertOk()->assertJsonCount(0, 'data');
    }

    public function test_antrean_menyertakan_pemakaian_bahan(): void
    {
        $worker = $this->t['buruh'];
        $task = $this->makeTask($worker);

        $task->resources()->attach($this->t['resource']->id, [
            'company_id'        => $this->t['company']->id,
            'max_allocated_qty' => 5,
            'actual_used_qty'   => 0,
            'variance_qty'      => 0,
            'is_over_allocated' => false,
        ]);

        Sanctum::actingAs($worker);

        $this->postJson("/api/tasks/{$task->id}/report", [
            'media_urls' => ['foto.jpg'],
            'resources'  => [['resource_id' => $this->t['resource']->id, 'actual_used_qty' => 7]],
        ])->assertCreated();

        Sanctum::actingAs($this->t['mandor']);

        $response = $this->getJson('/api/task-reports/queue')->assertOk();

        $resource = $response->json('data.0.task.resources.0');

        $this->assertSame($this->t['resource']->id, $resource['id']);
        $this->assertEquals(7, $resource['pivot']['actual_used_qty']);
        $this->assertEquals(5, $resource['pivot']['max_allocated_qty']);
        $this->assertTrue((bool) $resource['pivot']['is_over_allocated']);
    }

    public function test_detail_tugas_menyertakan_status_verifikasi(): void
    {
        $report = $this->pendingReport();

        Sanctum::actingAs($this->t['buruh']);

        $this->getJson("/api/tasks/{$report->task_id}")
            ->assertOk()
            ->assertJsonPath('data.status', 'menunggu_verifikasi')
            ->assertJsonPath('data.report.review_status', 'menunggu');
    }

    public function test_laporan_perusahaan_lain_tidak_dapat_diakses(): void
    {
        $b = $this->makeTenant('b');
        $task = $this->makeTask($b['buruh'], 'dikerjakan', $b);

        Sanctum::actingAs($b['buruh']);
        $this->postJson("/api/tasks/{$task->id}/report", ['media_urls' => ['foto.jpg']])->assertCreated();
        $foreign = TaskReport::where('task_id', $task->id)->firstOrFail();

        Sanctum::actingAs($this->t['owner']);

        $this->postJson("/api/task-reports/{$foreign->id}/verify")->assertNotFound();
        $this->postJson("/api/task-reports/{$foreign->id}/reject", ['reason' => 'x'])->assertNotFound();
        $this->getJson('/api/task-reports/queue')->assertOk()->assertJsonCount(0, 'data');
    }
}
