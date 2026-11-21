<?php

namespace Tests\Feature;

use App\Models\Finance;
use App\Models\Task;
use App\Models\Tool;
use App\Models\ToolIncident;
use App\Models\ToolUnit;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\Feature\Concerns\CreatesTenants;
use Tests\TestCase;

class InventoryTest extends TestCase
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

    private function createTask(array $resources = [], array $tools = []): \Illuminate\Testing\TestResponse
    {
        Sanctum::actingAs($this->t['owner']);

        return $this->postJson('/api/tasks', $this->taskPayload($this->t, array_filter([
            'resources' => $resources ?: null,
            'tools'     => $tools ?: null,
        ])));
    }

    private function allocate(float $qty): array
    {
        return [['resource_id' => $this->t['resource']->id, 'max_allocated_qty' => $qty]];
    }

    private function purchase(array $overrides = []): \Illuminate\Testing\TestResponse
    {
        return $this->postJson('/api/resource-purchases', array_merge([
            'resource_id' => $this->t['resource']->id,
            'qty'         => 50,
            'unit_price'  => 12000,
        ], $overrides));
    }

    private function runTaskWithTools(): Task
    {
        $response = $this->createTask([], [['tool_id' => $this->t['tool']->id, 'qty' => 2]])->assertCreated();

        $task = Task::findOrFail($response->json('data.id'));

        Sanctum::actingAs($this->t['buruh']);
        $this->postJson("/api/tasks/{$task->id}/start")->assertOk();

        return $task;
    }

    public function test_tugas_tidak_boleh_memesan_stok_yang_sudah_dialokasikan(): void
    {
        $this->createTask($this->allocate(60))->assertCreated();

        $this->createTask($this->allocate(60))
            ->assertUnprocessable()
            ->assertJsonValidationErrors('resources');

        $this->createTask($this->allocate(40))->assertCreated();

        $resource = $this->getJson('/api/resources')->assertOk()->json('data.0');

        $this->assertEquals(100, $resource['stock_qty']);
        $this->assertEquals(100, $resource['reserved_qty']);
        $this->assertEquals(0, $resource['available_qty']);
    }

    public function test_pembatalan_tugas_melepas_reservasi(): void
    {
        $taskId = $this->createTask($this->allocate(60))->assertCreated()->json('data.id');

        $this->postJson("/api/tasks/{$taskId}/cancel", ['reason' => 'Hujan deras'])->assertOk();

        $resource = $this->getJson('/api/resources')->assertOk()->json('data.0');

        $this->assertEquals(0, $resource['reserved_qty']);
        $this->assertEquals(100, $resource['available_qty']);

        $this->createTask($this->allocate(100))->assertCreated();
    }

    public function test_edit_tugas_tidak_menghitung_reservasi_milik_sendiri(): void
    {
        $taskId = $this->createTask($this->allocate(60))->assertCreated()->json('data.id');

        $this->putJson("/api/tasks/{$taskId}", $this->taskPayload($this->t, [
            'resources' => $this->allocate(90),
        ]))->assertOk();

        $this->putJson("/api/tasks/{$taskId}", $this->taskPayload($this->t, [
            'resources' => $this->allocate(101),
        ]))->assertUnprocessable()->assertJsonValidationErrors('resources');
    }

    public function test_pembelian_pemilik_menambah_stok_dan_dicatat_di_keuangan(): void
    {
        Sanctum::actingAs($this->t['owner']);

        $this->purchase(['supplier' => 'Toko Tani'])
            ->assertCreated()
            ->assertJsonPath('data.status', 'disetujui');

        $resource = $this->t['resource']->fresh();

        $this->assertEquals(150, $resource->stock_qty);
        $this->assertEquals(10666.67, (float) $resource->unit_price);

        $finance = Finance::where('category', 'pembelian')->firstOrFail();

        $this->assertSame('pengeluaran', $finance->type);
        $this->assertNull($finance->planting_id);
        $this->assertEquals(600000, $finance->amount);
        $this->assertSame('2026-11-20', $finance->record_date->toDateString());
        $this->assertSame(0.0, (float) $this->t['planting']->fresh()->total_cost);
    }

    public function test_pembelian_stok_tidak_dihitung_sebagai_biaya_di_dasbor(): void
    {
        Sanctum::actingAs($this->t['owner']);

        $this->purchase()->assertCreated();

        Finance::forceCreate([
            'company_id'  => $this->t['company']->id,
            'type'        => 'pengeluaran',
            'category'    => 'lainnya',
            'amount'      => 25000,
            'description' => 'Biaya lain',
            'record_date' => '2026-11-20',
        ]);

        $stats = $this->getJson('/api/dashboard/owner')->assertOk()->json('data');

        $this->assertEquals(25000, $stats['total_expense']);
        $this->assertEquals(600000, $stats['stock_purchases']);
        $this->assertEquals(-25000, $stats['net_profit']);
    }

    public function test_mandor_di_bawah_batas_langsung_disetujui(): void
    {
        Sanctum::actingAs($this->t['mandor']);

        $this->purchase(['qty' => 10, 'unit_price' => 10000])
            ->assertCreated()
            ->assertJsonPath('data.status', 'disetujui');

        $this->assertEquals(110, $this->t['resource']->fresh()->stock_qty);
        $this->assertSame(1, Finance::where('category', 'pembelian')->count());
    }

    public function test_mandor_di_atas_batas_menunggu_persetujuan_pemilik(): void
    {
        Sanctum::actingAs($this->t['mandor']);

        $id = $this->purchase(['qty' => 100, 'unit_price' => 10000])
            ->assertCreated()
            ->assertJsonPath('data.status', 'menunggu')
            ->json('data.id');

        $this->assertEquals(100, $this->t['resource']->fresh()->stock_qty);
        $this->assertSame(0, Finance::where('category', 'pembelian')->count());

        $this->postJson("/api/resource-purchases/{$id}/approve")->assertForbidden();

        Sanctum::actingAs($this->t['owner']);

        $this->postJson("/api/resource-purchases/{$id}/approve")
            ->assertOk()
            ->assertJsonPath('data.status', 'disetujui');

        $this->assertEquals(200, $this->t['resource']->fresh()->stock_qty);
        $this->assertEquals(1000000, Finance::where('category', 'pembelian')->firstOrFail()->amount);

        $this->postJson("/api/resource-purchases/{$id}/approve")->assertUnprocessable();
        $this->assertEquals(200, $this->t['resource']->fresh()->stock_qty);
    }

    public function test_penolakan_pembelian_wajib_beralasan_dan_tidak_mengubah_stok(): void
    {
        Sanctum::actingAs($this->t['mandor']);
        $id = $this->purchase(['qty' => 100, 'unit_price' => 10000])->assertCreated()->json('data.id');

        Sanctum::actingAs($this->t['owner']);

        $this->postJson("/api/resource-purchases/{$id}/reject")->assertUnprocessable();

        $this->postJson("/api/resource-purchases/{$id}/reject", ['reason' => 'Harga terlalu mahal'])
            ->assertOk()
            ->assertJsonPath('data.status', 'ditolak');

        $this->assertEquals(100, $this->t['resource']->fresh()->stock_qty);
        $this->assertSame(0, Finance::where('category', 'pembelian')->count());
    }

    public function test_pengaju_dapat_membatalkan_pengajuan_yang_masih_menunggu(): void
    {
        Sanctum::actingAs($this->t['mandor']);
        $id = $this->purchase(['qty' => 100, 'unit_price' => 10000])->assertCreated()->json('data.id');

        $this->postJson("/api/resource-purchases/{$id}/cancel")
            ->assertOk()
            ->assertJsonPath('data.status', 'dibatalkan');

        $this->postJson("/api/resource-purchases/{$id}/cancel")->assertUnprocessable();

        Sanctum::actingAs($this->t['owner']);
        $this->postJson("/api/resource-purchases/{$id}/approve")->assertUnprocessable();
    }

    public function test_buruh_dan_perusahaan_lain_tidak_dapat_mengakses_pembelian(): void
    {
        Sanctum::actingAs($this->t['buruh']);
        $this->getJson('/api/resource-purchases')->assertForbidden();
        $this->purchase()->assertForbidden();

        $other = $this->makeTenant('b');
        Sanctum::actingAs($other['owner']);

        $this->purchase()->assertUnprocessable()->assertJsonValidationErrors('resource_id');
    }

    public function test_mandor_tidak_dapat_mengubah_atau_menghapus_data_bahan_dan_alat(): void
    {
        Sanctum::actingAs($this->t['mandor']);

        $this->putJson('/api/resources/' . $this->t['resource']->id, ['name' => 'X', 'unit' => 'kg', 'stock_qty' => 999, 'unit_price' => 1])->assertForbidden();
        $this->deleteJson('/api/resources/' . $this->t['resource']->id)->assertForbidden();
        $this->putJson('/api/tools/' . $this->t['tool']->id, ['name' => 'X', 'total_qty' => 9])->assertForbidden();
        $this->deleteJson('/api/tools/' . $this->t['tool']->id)->assertForbidden();

        $this->getJson('/api/resources')->assertOk();
        $this->getJson('/api/tools')->assertOk();

        Sanctum::actingAs($this->t['owner']);

        $this->postJson('/api/resources', ['name' => 'Benih', 'unit' => 'kg', 'stock_qty' => 5, 'unit_price' => 1000])->assertCreated();
    }

    public function test_laporan_mencatat_alat_hilang_dan_rusak(): void
    {
        $task = $this->runTaskWithTools();

        $this->postJson("/api/tasks/{$task->id}/report", [
            'media_urls' => ['foto.jpg'],
            'notes'      => 'Selesai',
            'tools'      => [['tool_id' => $this->t['tool']->id, 'lost_qty' => 1, 'damaged_qty' => 1]],
        ])->assertCreated();

        $units = ToolUnit::where('tool_id', $this->t['tool']->id)->orderBy('id')->get();

        $this->assertSame(['hilang', 'rusak'], $units->pluck('condition')->all());
        $this->assertSame([false, false], $units->pluck('is_available')->all());

        $tool = $this->t['tool']->fresh();
        $this->assertSame(0, $tool->available_qty);
        $this->assertSame(2, $tool->total_qty);

        $this->assertSame(2, ToolIncident::where('task_id', $task->id)->where('status', 'terbuka')->count());

        $pivot = $task->fresh()->tools->first()->pivot;
        $this->assertSame(1, (int) $pivot->lost_qty);
        $this->assertSame(1, (int) $pivot->damaged_qty);

        Sanctum::actingAs($this->t['mandor']);

        $queued = $this->getJson('/api/task-reports/queue')->assertOk()->json('data.0.task.tools.0.pivot');

        $this->assertSame(1, (int) $queued['lost_qty']);
        $this->assertSame(1, (int) $queued['damaged_qty']);
    }

    public function test_laporan_tanpa_kerusakan_mengembalikan_semua_alat(): void
    {
        $task = $this->runTaskWithTools();

        $this->assertSame(0, $this->t['tool']->fresh()->available_qty);

        $this->postJson("/api/tasks/{$task->id}/report", ['media_urls' => ['foto.jpg']])->assertCreated();

        $this->assertSame(2, $this->t['tool']->fresh()->available_qty);
        $this->assertSame(0, ToolIncident::count());
    }

    public function test_laporan_dengan_jumlah_hilang_dan_rusak_melebihi_pinjaman_ditolak(): void
    {
        $task = $this->runTaskWithTools();

        $this->postJson("/api/tasks/{$task->id}/report", [
            'media_urls' => ['foto.jpg'],
            'tools'      => [['tool_id' => $this->t['tool']->id, 'lost_qty' => 2, 'damaged_qty' => 1]],
        ])->assertUnprocessable()->assertJsonValidationErrors('tools');

        $this->assertSame('dikerjakan', $task->fresh()->status->value);
        $this->assertSame(0, $this->t['tool']->fresh()->available_qty);
        $this->assertSame(0, ToolIncident::count());
    }

    public function test_mandor_mencatat_alat_rusak_secara_manual(): void
    {
        Sanctum::actingAs($this->t['mandor']);

        $this->postJson('/api/tool-incidents', [
            'tool_id' => $this->t['tool']->id,
            'kind'    => 'rusak',
            'qty'     => 1,
            'notes'   => 'Gagang patah',
        ])->assertCreated()->assertJsonCount(1, 'data');

        $this->assertSame(1, $this->t['tool']->fresh()->available_qty);

        $this->postJson('/api/tool-incidents', [
            'tool_id' => $this->t['tool']->id,
            'kind'    => 'hilang',
            'qty'     => 2,
        ])->assertUnprocessable()->assertJsonValidationErrors('qty');

        $this->postJson('/api/tool-incidents', ['tool_id' => $this->t['tool']->id, 'kind' => 'lainnya'])
            ->assertUnprocessable();

        $this->getJson('/api/tool-incidents?status=terbuka')->assertOk()->assertJsonCount(1, 'data');
    }

    public function test_hanya_pemilik_yang_menyelesaikan_kejadian_alat(): void
    {
        Sanctum::actingAs($this->t['mandor']);

        $id = $this->postJson('/api/tool-incidents', ['tool_id' => $this->t['tool']->id, 'kind' => 'rusak'])
            ->assertCreated()->json('data.0.id');

        $this->postJson("/api/tool-incidents/{$id}/resolve", ['resolution' => 'diperbaiki', 'cost' => 50000])
            ->assertForbidden();

        Sanctum::actingAs($this->t['owner']);

        $this->postJson("/api/tool-incidents/{$id}/resolve", ['resolution' => 'ditemukan'])->assertUnprocessable();

        $this->postJson("/api/tool-incidents/{$id}/resolve", ['resolution' => 'diperbaiki', 'cost' => 50000])
            ->assertOk()
            ->assertJsonPath('data.status', 'selesai');

        $this->assertSame(2, $this->t['tool']->fresh()->available_qty);
        $this->assertSame('baik', ToolUnit::where('tool_id', $this->t['tool']->id)->orderBy('id')->first()->condition);

        $finance = Finance::where('category', 'perawatan')->firstOrFail();
        $this->assertEquals(50000, $finance->amount);
        $this->assertNull($finance->planting_id);

        $this->postJson("/api/tool-incidents/{$id}/resolve", ['resolution' => 'diperbaiki'])->assertUnprocessable();
    }

    public function test_alat_hilang_dihapuskan_mengurangi_jumlah_total(): void
    {
        Sanctum::actingAs($this->t['mandor']);

        $id = $this->postJson('/api/tool-incidents', ['tool_id' => $this->t['tool']->id, 'kind' => 'hilang'])
            ->assertCreated()->json('data.0.id');

        Sanctum::actingAs($this->t['owner']);

        $this->postJson("/api/tool-incidents/{$id}/resolve", ['resolution' => 'dihapuskan', 'cost' => 999])
            ->assertOk()
            ->assertJsonPath('data.status', 'selesai');

        $tool = Tool::findOrFail($this->t['tool']->id);

        $this->assertSame(1, $tool->total_qty);
        $this->assertSame(1, $tool->available_qty);
        $this->assertSame(0, Finance::where('category', 'perawatan')->count());
    }

    public function test_daftar_alat_menyertakan_jumlah_rusak_dan_hilang(): void
    {
        Sanctum::actingAs($this->t['owner']);

        $this->postJson('/api/tool-incidents', ['tool_id' => $this->t['tool']->id, 'kind' => 'rusak'])->assertCreated();
        $this->postJson('/api/tool-incidents', ['tool_id' => $this->t['tool']->id, 'kind' => 'hilang'])->assertCreated();

        $tool = $this->getJson('/api/tools')->assertOk()->json('data.0');

        $this->assertSame(1, $tool['damaged_units_count']);
        $this->assertSame(1, $tool['lost_units_count']);
        $this->assertSame(0, $tool['available_qty']);
    }
}
