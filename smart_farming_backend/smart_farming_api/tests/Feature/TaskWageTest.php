<?php

namespace Tests\Feature;

use App\Models\Task;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\Feature\Concerns\CreatesTenants;
use Tests\TestCase;

class TaskWageTest extends TestCase
{
    use RefreshDatabase, CreatesTenants;

    private array $t;

    protected function setUp(): void
    {
        parent::setUp();

        $this->t = $this->makeTenant('a');
    }

    private function setWageType($worker, string $type, int $amount = 0): void
    {
        $worker->wage()->forceCreate([
            'company_id' => $this->t['company']->id,
            'wage_type'  => $type,
            'amount'     => $amount,
        ]);
    }

    public function test_tugas_untuk_buruh_borongan_wajib_punya_upah_tugas(): void
    {
        $this->setWageType($this->t['buruh'], 'borongan');

        Sanctum::actingAs($this->t['owner']);

        $this->postJson('/api/tasks', $this->taskPayload($this->t))
            ->assertUnprocessable()
            ->assertJsonValidationErrors('wage_amount');

        $this->postJson('/api/tasks', $this->taskPayload($this->t, ['wage_amount' => 0]))
            ->assertUnprocessable()
            ->assertJsonValidationErrors('wage_amount');

        $response = $this->postJson('/api/tasks', $this->taskPayload($this->t, ['wage_amount' => 120000]))
            ->assertCreated();

        $this->assertEquals(120000, $response->json('data.wage_amount'));
    }

    public function test_tiap_tugas_borongan_boleh_berbeda_upah(): void
    {
        $this->setWageType($this->t['buruh'], 'borongan');

        Sanctum::actingAs($this->t['mandor']);

        $ringan = $this->postJson('/api/tasks', $this->taskPayload($this->t, [
            'title' => 'Menyiram', 'wage_amount' => 50000,
        ]))->assertCreated()->json('data.id');

        $berat = $this->postJson('/api/tasks', $this->taskPayload($this->t, [
            'title' => 'Membajak lahan', 'wage_amount' => 300000,
        ]))->assertCreated()->json('data.id');

        $this->assertEquals(50000, Task::find($ringan)->wage_amount);
        $this->assertEquals(300000, Task::find($berat)->wage_amount);
    }

    public function test_upah_tugas_diabaikan_untuk_buruh_harian_dan_mandor_bulanan(): void
    {
        $this->setWageType($this->t['buruh'], 'harian', 80000);
        $this->setWageType($this->t['mandor'], 'bulanan', 4500000);

        Sanctum::actingAs($this->t['owner']);

        $untukBuruh = $this->postJson('/api/tasks', $this->taskPayload($this->t, ['wage_amount' => 99999]))
            ->assertCreated()->json('data.id');

        $untukMandor = $this->postJson('/api/tasks', $this->taskPayload($this->t, [
            'assigned_to' => $this->t['mandor']->id,
            'wage_amount' => 99999,
        ]))->assertCreated()->json('data.id');

        $this->assertNull(Task::find($untukBuruh)->wage_amount);
        $this->assertNull(Task::find($untukMandor)->wage_amount);
    }

    public function test_buruh_tanpa_data_upah_dianggap_bukan_borongan(): void
    {
        Sanctum::actingAs($this->t['owner']);

        $id = $this->postJson('/api/tasks', $this->taskPayload($this->t))
            ->assertCreated()->json('data.id');

        $this->assertNull(Task::find($id)->wage_amount);
    }

    public function test_ganti_pelaksana_ke_non_borongan_menghapus_upah_tugas(): void
    {
        $this->setWageType($this->t['buruh'], 'borongan');
        $this->setWageType($this->t['mandor'], 'bulanan', 4500000);

        Sanctum::actingAs($this->t['owner']);

        $id = $this->postJson('/api/tasks', $this->taskPayload($this->t, ['wage_amount' => 120000]))
            ->assertCreated()->json('data.id');

        $this->putJson('/api/tasks/' . $id, $this->taskPayload($this->t, [
            'assigned_to' => $this->t['mandor']->id,
        ]))->assertOk();

        $this->assertNull(Task::find($id)->wage_amount);
    }

    public function test_ubah_upah_tugas_borongan_selama_menunggu(): void
    {
        $this->setWageType($this->t['buruh'], 'borongan');

        Sanctum::actingAs($this->t['owner']);

        $id = $this->postJson('/api/tasks', $this->taskPayload($this->t, ['wage_amount' => 120000]))
            ->assertCreated()->json('data.id');

        $this->putJson('/api/tasks/' . $id, $this->taskPayload($this->t, ['wage_amount' => 175000]))
            ->assertOk();

        $this->assertEquals(175000, Task::find($id)->wage_amount);
    }

    public function test_upah_tugas_tidak_bisa_diubah_setelah_dikerjakan(): void
    {
        $this->setWageType($this->t['buruh'], 'borongan');

        Sanctum::actingAs($this->t['owner']);

        $id = $this->postJson('/api/tasks', $this->taskPayload($this->t, ['wage_amount' => 120000]))
            ->assertCreated()->json('data.id');

        Sanctum::actingAs($this->t['buruh']);
        $this->postJson('/api/tasks/' . $id . '/start')->assertOk();

        Sanctum::actingAs($this->t['owner']);
        $this->putJson('/api/tasks/' . $id, $this->taskPayload($this->t, ['wage_amount' => 999999]))
            ->assertUnprocessable();

        $this->assertEquals(120000, Task::find($id)->wage_amount);
    }

    public function test_buruh_melihat_upah_tugas_miliknya(): void
    {
        $this->setWageType($this->t['buruh'], 'borongan');

        Sanctum::actingAs($this->t['mandor']);
        $id = $this->postJson('/api/tasks', $this->taskPayload($this->t, ['wage_amount' => 120000]))
            ->assertCreated()->json('data.id');

        Sanctum::actingAs($this->t['buruh']);
        $this->assertEquals(120000, $this->getJson('/api/tasks/' . $id)->assertOk()->json('data.wage_amount'));
        $this->assertEquals(120000, $this->getJson('/api/tasks')->assertOk()->json('data.0.wage_amount'));
    }

    public function test_mandor_melihat_tipe_upah_buruh_tanpa_nominal(): void
    {
        $this->setWageType($this->t['buruh'], 'borongan');

        Sanctum::actingAs($this->t['mandor']);
        $row = $this->getJson('/api/workers')->assertOk()->json('data.0');

        $this->assertSame('borongan', $row['wage_type']);
        $this->assertArrayNotHasKey('wage', $row);
    }
}
