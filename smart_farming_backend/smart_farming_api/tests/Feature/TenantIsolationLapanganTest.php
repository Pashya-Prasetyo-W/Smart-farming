<?php

namespace Tests\Feature;

use App\Models\Concerns\BelongsToCompany;
use App\Models\Finance;
use App\Models\Harvest;
use App\Models\Resource;
use App\Models\ResourcePurchase;
use App\Models\ToolIncident;
use Illuminate\Contracts\Routing\UrlRoutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Route;
use Laravel\Sanctum\Sanctum;
use Tests\Feature\Concerns\CreatesTenants;
use Tests\TestCase;

class TenantIsolationLapanganTest extends TestCase
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

    public function test_semua_model_pada_route_api_memakai_filter_perusahaan(): void
    {
        $checked = 0;
        $unscoped = [];

        foreach (Route::getRoutes() as $route) {
            if (! str_starts_with($route->uri(), 'api/')) {
                continue;
            }

            foreach ($route->signatureParameters(['subClass' => UrlRoutable::class]) as $parameter) {
                $class = $parameter->getType()->getName();
                $checked++;

                if (! in_array(BelongsToCompany::class, class_uses_recursive($class), true)) {
                    $unscoped[] = $route->uri() . ' => ' . $class;
                }
            }
        }

        $this->assertGreaterThan(10, $checked);
        $this->assertSame([], $unscoped);
    }

    public function test_catatan_panen_perusahaan_lain_tidak_terbaca_atau_terhapus(): void
    {
        Sanctum::actingAs($this->a['mandor']);
        $harvestId = $this->postJson("/api/plantings/{$this->a['planting']->id}/harvests", [
            'quantity_kg' => 10, 'sold_kg' => 5, 'price_per_kg' => 1000,
        ])->assertCreated()->json('data.id');

        foreach (['owner', 'mandor'] as $role) {
            Sanctum::actingAs($this->b[$role]);

            $this->getJson("/api/plantings/{$this->a['planting']->id}/harvests")->assertNotFound();
            $this->postJson("/api/plantings/{$this->a['planting']->id}/harvests", ['quantity_kg' => 1])->assertNotFound();
            $this->deleteJson("/api/harvests/{$harvestId}")->assertNotFound();
        }

        Sanctum::actingAs($this->b['owner']);
        $this->getJson("/api/plantings/{$this->a['planting']->id}/summary")->assertNotFound();
        $this->getJson("/api/plantings/{$this->a['planting']->id}/hpp")->assertNotFound();

        $this->assertSame(1, Harvest::withoutGlobalScopes()->count());
        $this->assertSame(1, Finance::withoutGlobalScopes()->where('type', 'pemasukan')->count());
    }

    public function test_pembelian_bahan_perusahaan_lain_tidak_bisa_diputuskan_atau_dilihat(): void
    {
        Sanctum::actingAs($this->a['owner']);
        $id = $this->postJson('/api/resource-purchases', [
            'resource_id' => $this->a['resource']->id,
            'qty'         => 10,
            'unit_price'  => 1000,
        ])->assertCreated()->json('data.id');

        Sanctum::actingAs($this->b['owner']);

        $this->postJson("/api/resource-purchases/{$id}/approve")->assertNotFound();
        $this->postJson("/api/resource-purchases/{$id}/reject", ['reason' => 'x'])->assertNotFound();
        $this->postJson("/api/resource-purchases/{$id}/cancel")->assertNotFound();

        $this->assertSame([], $this->getJson('/api/resource-purchases')->assertOk()->json('data'));
        $this->assertSame(
            ResourcePurchase::STATUS_DISETUJUI,
            ResourcePurchase::withoutGlobalScopes()->findOrFail($id)->status
        );
        $this->assertEquals(110, Resource::withoutGlobalScopes()->find($this->a['resource']->id)->stock_qty);
    }

    public function test_insiden_alat_perusahaan_lain_tidak_bisa_dibuat_diselesaikan_atau_dilihat(): void
    {
        Sanctum::actingAs($this->a['mandor']);
        $this->postJson('/api/tool-incidents', [
            'tool_id' => $this->a['tool']->id, 'kind' => 'rusak', 'qty' => 1,
        ])->assertCreated();

        $incident = ToolIncident::withoutGlobalScopes()->firstOrFail();

        Sanctum::actingAs($this->b['owner']);

        $this->postJson('/api/tool-incidents', [
            'tool_id' => $this->a['tool']->id, 'kind' => 'rusak', 'qty' => 1,
        ])->assertUnprocessable()->assertJsonValidationErrors('tool_id');

        $this->postJson("/api/tool-incidents/{$incident->id}/resolve", ['resolution' => 'dihapuskan'])->assertNotFound();
        $this->assertSame([], $this->getJson('/api/tool-incidents')->assertOk()->json('data'));
        $this->assertSame(1, $this->a['tool']->fresh()->available_qty);
    }

    public function test_analitik_tidak_memuat_atau_menerima_data_perusahaan_lain(): void
    {
        Sanctum::actingAs($this->b['owner']);

        $this->getJson("/api/analytics/profit?land_id={$this->a['land']->id}")
            ->assertUnprocessable()
            ->assertJsonValidationErrors('land_id');

        $json = json_encode($this->getJson('/api/analytics/profit')->assertOk()->json());
        $this->assertStringNotContainsString('"land":"Lahan a"', $json);
        $this->assertStringNotContainsString('Lahan a', $json);

        $this->assertStringNotContainsString('Lahan a', json_encode($this->getJson('/api/analytics/risk')->assertOk()->json()));
    }

    public function test_akun_buruh_perusahaan_lain_tidak_bisa_dikelola(): void
    {
        Sanctum::actingAs($this->b['owner']);

        $id = $this->a['buruh']->id;

        $this->getJson('/api/workers')->assertOk();
        $this->putJson("/api/workers/{$id}", ['name' => 'Diretas'])->assertNotFound();
        $this->deleteJson("/api/workers/{$id}")->assertNotFound();
        $this->postJson("/api/workers/{$id}/deactivate")->assertNotFound();
        $this->postJson("/api/workers/{$id}/activate")->assertNotFound();

        $ids = collect($this->getJson('/api/workers')->json('data'))->pluck('id')->all();
        $this->assertNotContains($id, $ids);
        $this->assertSame('Buruh a', $this->a['buruh']->fresh()->name);
    }

    public function test_keuangan_dan_milestone_perusahaan_lain_ditolak(): void
    {
        Sanctum::actingAs($this->b['owner']);

        $this->postJson('/api/finances', [
            'type'        => 'pengeluaran',
            'category'    => 'lainnya',
            'amount'      => 1000,
            'description' => 'Salah sasaran',
            'planting_id' => $this->a['planting']->id,
        ])->assertUnprocessable()->assertJsonValidationErrors('planting_id');

        $this->postJson("/api/lands/{$this->a['land']->id}/milestones", [
            'title' => 'x', 'target_value' => 10, 'deadline' => now()->addDays(10)->toDateString(),
        ])->assertNotFound();

        $this->assertSame(0, Finance::withoutGlobalScopes()->count());
    }

    public function test_tugas_banyak_karyawan_menolak_buruh_perusahaan_lain(): void
    {
        Sanctum::actingAs($this->b['owner']);

        $payload = $this->taskPayload($this->b, ['assignee_ids' => [$this->b['buruh']->id, $this->a['buruh']->id]]);
        unset($payload['assigned_to']);

        $this->postJson('/api/tasks', $payload)
            ->assertUnprocessable()
            ->assertJsonValidationErrors('assignee_ids.1');
    }

    public function test_dashboard_pemilik_hanya_menghitung_perusahaan_sendiri(): void
    {
        Sanctum::actingAs($this->b['owner']);

        $this->getJson('/api/dashboard/owner')
            ->assertOk()
            ->assertJsonPath('data.total_lands', 1);
    }
}
