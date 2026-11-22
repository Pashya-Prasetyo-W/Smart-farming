<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\Feature\Concerns\CreatesTenants;
use Tests\TestCase;

class RoleAccessTest extends TestCase
{
    use RefreshDatabase, CreatesTenants;

    private array $t;

    protected function setUp(): void
    {
        parent::setUp();

        $this->t = $this->makeTenant('a');
    }

    public function test_registrasi_publik_selalu_membuat_pemilik_walau_minta_role_lain(): void
    {
        $this->postJson('/api/auth/register', [
            'name'         => 'Orang Baru',
            'email'        => 'baru@test.com',
            'password'     => 'password123',
            'company_name' => 'Kebun Baru',
            'role'         => 'mandor',
        ])->assertCreated()->assertJsonPath('data.user.role', 'pemilik');
    }

    public function test_buruh_tidak_bisa_input_data_atau_melihat_keuangan_dan_inventaris(): void
    {
        Sanctum::actingAs($this->t['buruh']);

        $this->postJson('/api/tasks', $this->taskPayload($this->t))->assertForbidden();
        $this->getJson('/api/finances')->assertForbidden();
        $this->getJson('/api/resources')->assertForbidden();
        $this->getJson('/api/tools')->assertForbidden();
        $this->getJson('/api/workers')->assertForbidden();
        $this->getJson('/api/plantings')->assertForbidden();
        $this->getJson('/api/dashboard/owner')->assertForbidden();
    }

    public function test_mandor_bisa_input_data_lapangan(): void
    {
        Sanctum::actingAs($this->t['mandor']);

        $this->postJson('/api/resources', [
            'name' => 'Pestisida', 'unit' => 'liter', 'stock_qty' => 10, 'unit_price' => 50000,
        ])->assertCreated();

        $this->postJson('/api/tools', [
            'name' => 'Sabit', 'total_qty' => 2,
        ])->assertCreated();

        $this->postJson('/api/tasks', $this->taskPayload($this->t))->assertCreated();

        $this->getJson('/api/dashboard/mandor')
            ->assertOk()
            ->assertJsonStructure(['data' => ['total_lands', 'active_tasks', 'active_workers']]);
    }

    public function test_mandor_tidak_bisa_keuangan_dan_keputusan_siklus_tanam(): void
    {
        Sanctum::actingAs($this->t['mandor']);

        $this->getJson('/api/finances')->assertForbidden();
        $this->postJson('/api/finances', [
            'type' => 'pemasukan', 'amount' => 1000, 'description' => 'x',
        ])->assertForbidden();
        $this->postJson('/api/plantings/' . $this->t['planting']->id . '/harvest', ['harvest_kg' => 5])
            ->assertForbidden();
        $this->postJson('/api/plantings/' . $this->t['planting']->id . '/cancel')
            ->assertForbidden();
        $this->getJson('/api/dashboard/owner')->assertForbidden();
    }

    public function test_mandor_bisa_menambah_dan_mengubah_lahan_tetapi_buruh_tidak(): void
    {
        $payload = ['name' => 'Lahan Baru', 'area_sqm' => 10, 'location_lat' => 0, 'location_long' => 0];

        Sanctum::actingAs($this->t['mandor']);
        $id = $this->postJson('/api/lands', $payload)->assertCreated()->json('data.id');
        $this->putJson("/api/lands/{$id}", array_merge($payload, ['name' => 'Lahan Ganti']))
            ->assertOk()
            ->assertJsonPath('data.name', 'Lahan Ganti');

        Sanctum::actingAs($this->t['buruh']);
        $this->postJson('/api/lands', $payload)->assertForbidden();
        $this->putJson("/api/lands/{$id}", $payload)->assertForbidden();
    }

    public function test_pemilik_bisa_semua_area_tanpa_dashboard_mandor(): void
    {
        Sanctum::actingAs($this->t['owner']);

        $this->getJson('/api/finances')->assertOk();
        $this->getJson('/api/dashboard/owner')->assertOk();
        $this->getJson('/api/workers')->assertOk();
        $this->getJson('/api/dashboard/mandor')->assertForbidden();
    }

    public function test_buruh_hanya_melihat_tugas_miliknya(): void
    {
        $buruh2 = User::create([
            'name'       => 'Buruh Lain',
            'email'      => 'buruh-lain@test.com',
            'password'   => 'password123',
            'role'       => 'buruh',
            'company_id' => $this->t['company']->id,
        ]);

        Sanctum::actingAs($this->t['mandor']);
        $taskId = $this->postJson('/api/tasks', $this->taskPayload($this->t, [
            'assigned_to' => $buruh2->id,
        ]))->assertCreated()->json('data.id');

        Sanctum::actingAs($this->t['buruh']);
        $this->getJson('/api/tasks')->assertOk()->assertJsonCount(0, 'data');
        $this->getJson('/api/tasks/' . $taskId)->assertForbidden();
        $this->postJson('/api/tasks/' . $taskId . '/start')->assertForbidden();

        Sanctum::actingAs($buruh2);
        $this->getJson('/api/tasks')->assertOk()->assertJsonCount(1, 'data');
        $this->getJson('/api/tasks/' . $taskId)->assertOk();
    }

    public function test_mandor_melihat_semua_tugas_perusahaan(): void
    {
        Sanctum::actingAs($this->t['owner']);
        $this->postJson('/api/tasks', $this->taskPayload($this->t))->assertCreated();

        Sanctum::actingAs($this->t['mandor']);
        $this->getJson('/api/tasks')->assertOk()->assertJsonCount(1, 'data');
    }

    public function test_mandor_yang_ditugaskan_bisa_memulai_tugasnya_sendiri(): void
    {
        Sanctum::actingAs($this->t['owner']);
        $taskId = $this->postJson('/api/tasks', $this->taskPayload($this->t, [
            'assigned_to' => $this->t['mandor']->id,
        ]))->assertCreated()->json('data.id');

        Sanctum::actingAs($this->t['mandor']);
        $this->postJson('/api/tasks/' . $taskId . '/start')
            ->assertOk()
            ->assertJsonPath('data.status', 'dikerjakan');
    }

    public function test_pemilik_tidak_bisa_memulai_tugas_pelaksana(): void
    {
        Sanctum::actingAs($this->t['owner']);
        $taskId = $this->postJson('/api/tasks', $this->taskPayload($this->t))
            ->assertCreated()
            ->json('data.id');

        $this->postJson('/api/tasks/' . $taskId . '/start')->assertForbidden();
    }
}
