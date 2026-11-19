<?php

namespace Tests\Feature;

use App\Models\Land;
use App\Models\Planting;
use App\Models\Resource;
use App\Models\Tool;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\Feature\Concerns\CreatesTenants;
use Tests\TestCase;

class TenantIsolationTest extends TestCase
{
    use RefreshDatabase, CreatesTenants;

    private array $a;
    private array $b;

    protected function setUp(): void
    {
        parent::setUp();

        $this->a = $this->makeTenant('a');
        $this->b = $this->makeTenant('b');
    }

    public function test_daftar_lahan_hanya_berisi_data_perusahaan_sendiri(): void
    {
        Sanctum::actingAs($this->b['owner']);

        $response = $this->getJson('/api/lands')->assertOk();

        $ids = collect($response->json('data'))->pluck('id')->all();

        $this->assertSame([$this->b['land']->id], $ids);
    }

    public function test_tidak_bisa_mengubah_lahan_perusahaan_lain(): void
    {
        Sanctum::actingAs($this->b['owner']);

        $this->putJson('/api/lands/' . $this->a['land']->id, [
            'name'          => 'Diretas',
            'area_sqm'      => 1,
            'location_lat'  => 0,
            'location_long' => 0,
        ])->assertNotFound();

        $this->assertSame(
            'Lahan a',
            Land::withoutGlobalScopes()->find($this->a['land']->id)->name
        );
    }

    public function test_tidak_bisa_memanen_atau_membatalkan_siklus_tanam_perusahaan_lain(): void
    {
        Sanctum::actingAs($this->b['owner']);

        $this->postJson('/api/plantings/' . $this->a['planting']->id . '/harvest', ['harvest_kg' => 10])
            ->assertNotFound();
        $this->postJson('/api/plantings/' . $this->a['planting']->id . '/cancel')
            ->assertNotFound();

        $this->assertSame(
            'berjalan',
            Planting::withoutGlobalScopes()->find($this->a['planting']->id)->status
        );
    }

    public function test_tidak_bisa_membuat_tugas_di_siklus_tanam_perusahaan_lain(): void
    {
        Sanctum::actingAs($this->b['owner']);

        $this->postJson('/api/tasks', $this->taskPayload($this->b, [
            'planting_id' => $this->a['planting']->id,
        ]))->assertUnprocessable()->assertJsonValidationErrors('planting_id');
    }

    public function test_tidak_bisa_menugaskan_tugas_ke_buruh_perusahaan_lain(): void
    {
        Sanctum::actingAs($this->b['owner']);

        $this->postJson('/api/tasks', $this->taskPayload($this->b, [
            'assigned_to' => $this->a['buruh']->id,
        ]))->assertUnprocessable()->assertJsonValidationErrors('assigned_to');
    }

    public function test_tidak_bisa_memakai_bahan_atau_alat_perusahaan_lain_di_tugas(): void
    {
        Sanctum::actingAs($this->b['owner']);

        $this->postJson('/api/tasks', $this->taskPayload($this->b, [
            'resources' => [['resource_id' => $this->a['resource']->id, 'max_allocated_qty' => 1]],
        ]))->assertUnprocessable()->assertJsonValidationErrors('resources.0.resource_id');

        $this->postJson('/api/tasks', $this->taskPayload($this->b, [
            'tools' => [['tool_id' => $this->a['tool']->id, 'qty' => 1]],
        ]))->assertUnprocessable()->assertJsonValidationErrors('tools.0.tool_id');
    }

    public function test_tidak_bisa_mengubah_atau_menghapus_bahan_dan_alat_perusahaan_lain(): void
    {
        Sanctum::actingAs($this->b['owner']);

        $this->putJson('/api/resources/' . $this->a['resource']->id, [
            'name' => 'Diretas', 'unit' => 'kg', 'stock_qty' => 0, 'unit_price' => 0,
        ])->assertNotFound();
        $this->deleteJson('/api/resources/' . $this->a['resource']->id)->assertNotFound();
        $this->putJson('/api/tools/' . $this->a['tool']->id, [
            'name' => 'Diretas', 'total_qty' => 1,
        ])->assertNotFound();
        $this->deleteJson('/api/tools/' . $this->a['tool']->id)->assertNotFound();

        $this->assertNotNull(Resource::withoutGlobalScopes()->find($this->a['resource']->id));
        $this->assertNotNull(Tool::withoutGlobalScopes()->find($this->a['tool']->id));
    }

    public function test_tidak_bisa_melihat_tugas_perusahaan_lain(): void
    {
        $this->postJson('/api/tasks', [])->assertUnauthorized();

        Sanctum::actingAs($this->a['owner']);
        $taskId = $this->postJson('/api/tasks', $this->taskPayload($this->a))
            ->assertCreated()
            ->json('data.id');

        Sanctum::actingAs($this->b['owner']);
        $this->getJson('/api/tasks/' . $taskId)->assertNotFound();
    }

    public function test_tidak_bisa_melaporkan_insiden_di_lahan_perusahaan_lain(): void
    {
        Sanctum::actingAs($this->b['buruh']);

        $this->postJson('/api/incidents', [
            'land_id'     => $this->a['land']->id,
            'type'        => 'hama',
            'description' => 'Ada hama',
        ])->assertUnprocessable()->assertJsonValidationErrors('land_id');
    }
}
