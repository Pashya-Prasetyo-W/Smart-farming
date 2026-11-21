<?php

namespace Tests\Feature;

use App\Models\Task;
use App\Models\Tool;
use App\Models\User;
use App\Models\WorkerWage;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\Feature\Concerns\CreatesTenants;
use Tests\TestCase;

class MultiAssigneeTaskTest extends TestCase
{
    use RefreshDatabase, CreatesTenants;

    private array $t;

    protected function setUp(): void
    {
        parent::setUp();

        $this->t = $this->makeTenant('a');
    }

    private function extraBuruh(string $name, ?string $wageType = null, bool $active = true): User
    {
        $user = User::create([
            'name'       => $name,
            'email'      => strtolower(str_replace(' ', '', $name)) . '@test.com',
            'password'   => 'password123',
            'role'       => 'buruh',
            'company_id' => $this->t['company']->id,
        ]);

        if (! $active) {
            $user->forceFill(['is_active' => false])->save();
        }

        if ($wageType) {
            $wage = new WorkerWage();
            $wage->forceFill([
                'company_id' => $this->t['company']->id,
                'user_id'    => $user->id,
                'wage_type'  => $wageType,
                'amount'     => $wageType === 'borongan' ? 0 : 80000,
            ])->save();
        }

        return $user;
    }

    private function groupPayload(array $ids, array $overrides = []): array
    {
        $payload = $this->taskPayload($this->t, $overrides);
        unset($payload['assigned_to']);
        $payload['assignee_ids'] = $ids;

        return $payload;
    }

    public function test_satu_form_membuat_tugas_untuk_setiap_karyawan_terpilih(): void
    {
        $second = $this->extraBuruh('Buruh Dua');
        $third = $this->extraBuruh('Buruh Tiga');

        Sanctum::actingAs($this->t['owner']);

        $response = $this->postJson('/api/tasks', $this->groupPayload([
            $this->t['buruh']->id, $second->id, $third->id,
        ]))->assertCreated()->assertJsonCount(3, 'data');

        $this->assertSame('3 tugas berhasil dibuat.', $response->json('message'));
        $this->assertSame(3, Task::where('title', 'Pemupukan')->count());
        $this->assertEqualsCanonicalizing(
            [$this->t['buruh']->id, $second->id, $third->id],
            Task::pluck('assigned_to')->all()
        );
    }

    public function test_tidak_bisa_membuat_tugas_tanpa_karyawan_terpilih(): void
    {
        Sanctum::actingAs($this->t['owner']);

        $this->postJson('/api/tasks', $this->groupPayload([]))
            ->assertUnprocessable()
            ->assertJsonValidationErrors('assignee_ids');

        $payload = $this->groupPayload([]);
        unset($payload['assignee_ids']);

        $this->postJson('/api/tasks', $payload)->assertUnprocessable();

        $this->assertSame(0, Task::count());
    }

    public function test_karyawan_nonaktif_atau_perusahaan_lain_ditolak_dan_tidak_ada_tugas_yang_terbentuk(): void
    {
        $inactive = $this->extraBuruh('Buruh Nonaktif', null, false);
        $other = $this->makeTenant('b');

        Sanctum::actingAs($this->t['owner']);

        $this->postJson('/api/tasks', $this->groupPayload([$this->t['buruh']->id, $inactive->id]))
            ->assertUnprocessable()
            ->assertJsonValidationErrors('assignee_ids.1');

        $this->postJson('/api/tasks', $this->groupPayload([$this->t['buruh']->id, $other['buruh']->id]))
            ->assertUnprocessable()
            ->assertJsonValidationErrors('assignee_ids.1');

        $this->postJson('/api/tasks', $this->groupPayload([$this->t['buruh']->id, $this->t['buruh']->id]))
            ->assertUnprocessable();

        $this->assertSame(0, Task::count());
    }

    public function test_mandor_dapat_menugaskan_beberapa_buruh(): void
    {
        $second = $this->extraBuruh('Buruh Dua');

        Sanctum::actingAs($this->t['mandor']);

        $this->postJson('/api/tasks', $this->groupPayload([$this->t['buruh']->id, $second->id]))
            ->assertCreated()
            ->assertJsonCount(2, 'data');
    }

    public function test_jumlah_bahan_dibagi_rata_ke_semua_tugas(): void
    {
        $second = $this->extraBuruh('Buruh Dua');
        $third = $this->extraBuruh('Buruh Tiga');

        Sanctum::actingAs($this->t['owner']);

        $this->postJson('/api/tasks', $this->groupPayload(
            [$this->t['buruh']->id, $second->id, $third->id],
            ['resources' => [['resource_id' => $this->t['resource']->id, 'max_allocated_qty' => 100]]]
        ))->assertCreated();

        $shares = Task::orderBy('id')->get()->map(
            fn (Task $task) => (float) $task->resources()->first()->pivot->max_allocated_qty
        )->all();

        $this->assertSame([33.33, 33.33, 33.34], $shares);
        $this->assertEqualsWithDelta(100, array_sum($shares), 0.001);

        $resource = $this->getJson('/api/resources')->assertOk()->json('data.0');
        $this->assertEquals(100, $resource['reserved_qty']);
    }

    public function test_bahan_melebihi_stok_tersedia_membatalkan_semua_tugas(): void
    {
        $second = $this->extraBuruh('Buruh Dua');

        Sanctum::actingAs($this->t['owner']);

        $this->postJson('/api/tasks', $this->groupPayload(
            [$this->t['buruh']->id, $second->id],
            ['resources' => [['resource_id' => $this->t['resource']->id, 'max_allocated_qty' => 101]]]
        ))->assertUnprocessable()->assertJsonValidationErrors('resources');

        $this->assertSame(0, Task::count());
    }

    private function toolShares(): array
    {
        return Task::orderBy('id')->get()->map(
            fn (Task $task) => (int) ($task->tools()->first()?->pivot->qty ?? 0)
        )->all();
    }

    public function test_jumlah_alat_dibagi_rata_ke_semua_tugas(): void
    {
        $second = $this->extraBuruh('Buruh Dua');
        $third = $this->extraBuruh('Buruh Tiga');

        $bigTool = new Tool();
        $bigTool->forceFill([
            'company_id'    => $this->t['company']->id,
            'name'          => 'Sabit',
            'unit_label'    => 'buah',
            'total_qty'     => 5,
            'available_qty' => 5,
        ])->save();

        Sanctum::actingAs($this->t['owner']);

        $this->postJson('/api/tasks', $this->groupPayload(
            [$this->t['buruh']->id, $second->id, $third->id],
            ['tools' => [['tool_id' => $bigTool->id, 'qty' => 5]]]
        ))->assertCreated();

        $this->assertSame([2, 2, 1], $this->toolShares());
    }

    public function test_alat_lebih_sedikit_dari_karyawan_hanya_diberikan_ke_sebagian(): void
    {
        $second = $this->extraBuruh('Buruh Dua');
        $third = $this->extraBuruh('Buruh Tiga');

        Sanctum::actingAs($this->t['owner']);

        $this->postJson('/api/tasks', $this->groupPayload(
            [$this->t['buruh']->id, $second->id, $third->id],
            ['tools' => [['tool_id' => $this->t['tool']->id, 'qty' => 2]]]
        ))->assertCreated()->assertJsonCount(3, 'data');

        $this->assertSame([1, 1, 0], $this->toolShares());
    }

    public function test_total_alat_melebihi_ketersediaan_membatalkan_semua_tugas(): void
    {
        $second = $this->extraBuruh('Buruh Dua');

        Sanctum::actingAs($this->t['owner']);

        $this->postJson('/api/tasks', $this->groupPayload(
            [$this->t['buruh']->id, $second->id],
            ['tools' => [['tool_id' => $this->t['tool']->id, 'qty' => 3]]]
        ))->assertUnprocessable()->assertJsonValidationErrors('tools');

        $this->assertSame(0, Task::count());
    }

    public function test_upah_borongan_hanya_berlaku_untuk_pekerja_borongan(): void
    {
        $borongan = $this->extraBuruh('Buruh Borong', 'borongan');
        $harian = $this->extraBuruh('Buruh Harian', 'harian');

        Sanctum::actingAs($this->t['owner']);

        $this->postJson('/api/tasks', $this->groupPayload([$borongan->id, $harian->id]))
            ->assertUnprocessable()
            ->assertJsonValidationErrors('wage_amount');

        $this->assertSame(0, Task::count());

        $this->postJson('/api/tasks', $this->groupPayload([$borongan->id, $harian->id], ['wage_amount' => 250000]))
            ->assertCreated();

        $this->assertEquals(250000, Task::where('assigned_to', $borongan->id)->value('wage_amount'));
        $this->assertNull(Task::where('assigned_to', $harian->id)->value('wage_amount'));
    }

    public function test_format_lama_dengan_satu_pelaksana_tetap_berfungsi(): void
    {
        Sanctum::actingAs($this->t['owner']);

        $this->postJson('/api/tasks', $this->taskPayload($this->t))
            ->assertCreated()
            ->assertJsonPath('data.assigned_to', $this->t['buruh']->id);
    }

    public function test_mengubah_tugas_tetap_satu_pelaksana(): void
    {
        $second = $this->extraBuruh('Buruh Dua');

        Sanctum::actingAs($this->t['owner']);

        $taskId = $this->postJson('/api/tasks', $this->taskPayload($this->t))->assertCreated()->json('data.id');

        $payload = $this->groupPayload([$second->id]);

        $this->putJson("/api/tasks/{$taskId}", $payload)
            ->assertUnprocessable()
            ->assertJsonValidationErrors('assigned_to');

        $this->putJson("/api/tasks/{$taskId}", $this->taskPayload($this->t, ['assigned_to' => $second->id]))
            ->assertOk();
    }
}
