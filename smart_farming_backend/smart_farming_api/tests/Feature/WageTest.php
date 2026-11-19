<?php

namespace Tests\Feature;

use App\Models\WorkerAllowance;
use App\Models\WorkerWage;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\Feature\Concerns\CreatesTenants;
use Tests\TestCase;

class WageTest extends TestCase
{
    use RefreshDatabase, CreatesTenants;

    private array $t;

    protected function setUp(): void
    {
        parent::setUp();

        $this->t = $this->makeTenant('a');
    }

    private function account(string $name, string $role, array $extra = []): array
    {
        return array_merge([
            'name'     => $name,
            'email'    => strtolower(str_replace(' ', '.', $name)) . '@test.com',
            'password' => 'password123',
            'role'     => $role,
        ], $extra);
    }

    private function allowances(): array
    {
        return [
            ['name' => 'Tunjangan transport', 'amount' => 300000],
            ['name' => 'Tunjangan jabatan', 'amount' => 500000],
        ];
    }

    public function test_pemilik_membuat_buruh_dengan_upah_harian(): void
    {
        Sanctum::actingAs($this->t['owner']);

        $response = $this->postJson('/api/workers', $this->account('Buruh Baru', 'buruh', [
            'wage' => ['wage_type' => 'harian', 'amount' => 80000],
        ]))->assertCreated()->assertJsonPath('data.wage.wage_type', 'harian');

        $wage = WorkerWage::where('user_id', $response->json('data.id'))->first();
        $this->assertEquals(80000, $wage->amount);
        $this->assertSame($this->t['company']->id, $wage->company_id);
    }

    public function test_buruh_boleh_borongan_dan_tidak_boleh_bulanan(): void
    {
        Sanctum::actingAs($this->t['owner']);

        $this->postJson('/api/workers', $this->account('Buruh Borong', 'buruh', [
            'wage' => ['wage_type' => 'borongan', 'amount' => 150000],
        ]))->assertCreated();

        $this->postJson('/api/workers', $this->account('Buruh Bulanan', 'buruh', [
            'wage' => ['wage_type' => 'bulanan', 'amount' => 3000000],
        ]))->assertUnprocessable()->assertJsonValidationErrors('wage.wage_type');
    }

    public function test_upah_borongan_tidak_menyimpan_nominal(): void
    {
        Sanctum::actingAs($this->t['owner']);

        $response = $this->postJson('/api/workers', $this->account('Buruh Borong', 'buruh', [
            'wage' => ['wage_type' => 'borongan'],
        ]))->assertCreated()->assertJsonPath('data.wage.wage_type', 'borongan');

        $this->assertEquals(0, WorkerWage::where('user_id', $response->json('data.id'))->value('amount'));
    }

    public function test_mandor_wajib_bulanan_dengan_tunjangan_tetap(): void
    {
        Sanctum::actingAs($this->t['owner']);

        $this->postJson('/api/workers', $this->account('Mandor Harian', 'mandor', [
            'wage' => ['wage_type' => 'harian', 'amount' => 100000],
        ]))->assertUnprocessable()->assertJsonValidationErrors('wage.wage_type');

        $response = $this->postJson('/api/workers', $this->account('Mandor Baru', 'mandor', [
            'wage'       => ['wage_type' => 'bulanan', 'amount' => 4500000],
            'allowances' => $this->allowances(),
        ]))->assertCreated();

        $response->assertJsonCount(2, 'data.allowances');
        $this->assertSame(2, WorkerAllowance::where('user_id', $response->json('data.id'))->count());
    }

    public function test_buruh_tidak_mendapat_tunjangan(): void
    {
        Sanctum::actingAs($this->t['owner']);

        $response = $this->postJson('/api/workers', $this->account('Buruh Baru', 'buruh', [
            'wage'       => ['wage_type' => 'harian', 'amount' => 80000],
            'allowances' => $this->allowances(),
        ]))->assertCreated();

        $response->assertJsonCount(0, 'data.allowances');
        $this->assertSame(0, WorkerAllowance::where('user_id', $response->json('data.id'))->count());
    }

    public function test_mandor_tidak_bisa_mengatur_upah_saat_membuat_buruh(): void
    {
        Sanctum::actingAs($this->t['mandor']);

        $response = $this->postJson('/api/workers', $this->account('Buruh Baru', 'buruh', [
            'wage' => ['wage_type' => 'harian', 'amount' => 999999],
        ]))->assertCreated();

        $this->assertSame(0, WorkerWage::where('user_id', $response->json('data.id'))->count());
        $this->assertArrayNotHasKey('wage', $response->json('data'));
    }

    public function test_mandor_tidak_bisa_mengubah_upah_buruh(): void
    {
        Sanctum::actingAs($this->t['mandor']);

        $this->putJson('/api/workers/' . $this->t['buruh']->id, [
            'name'  => 'Buruh a',
            'email' => 'buruh-a@test.com',
            'wage'  => ['wage_type' => 'harian', 'amount' => 999999],
        ])->assertOk();

        $this->assertSame(0, WorkerWage::where('user_id', $this->t['buruh']->id)->count());
    }

    public function test_daftar_karyawan_menyembunyikan_upah_dari_mandor(): void
    {
        $this->t['buruh']->wage()->forceCreate([
            'company_id' => $this->t['company']->id,
            'wage_type'  => 'harian',
            'amount'     => 80000,
        ]);

        Sanctum::actingAs($this->t['mandor']);
        $row = $this->getJson('/api/workers')->assertOk()->json('data.0');
        $this->assertArrayNotHasKey('wage', $row);
        $this->assertArrayNotHasKey('allowances', $row);
        $this->assertSame('harian', $row['wage_type']);

        Sanctum::actingAs($this->t['owner']);
        $row = collect($this->getJson('/api/workers')->assertOk()->json('data'))
            ->firstWhere('id', $this->t['buruh']->id);
        $this->assertSame('harian', $row['wage']['wage_type']);
    }

    public function test_pemilik_mengubah_upah_tanpa_menggandakan_baris(): void
    {
        Sanctum::actingAs($this->t['owner']);

        $payload = [
            'name'  => 'Buruh a',
            'email' => 'buruh-a@test.com',
        ];

        $this->putJson('/api/workers/' . $this->t['buruh']->id, $payload + [
            'wage' => ['wage_type' => 'harian', 'amount' => 80000],
        ])->assertOk();

        $this->putJson('/api/workers/' . $this->t['buruh']->id, $payload + [
            'wage' => ['wage_type' => 'borongan', 'amount' => 120000],
        ])->assertOk()->assertJsonPath('data.wage.wage_type', 'borongan');

        $this->assertSame(1, WorkerWage::where('user_id', $this->t['buruh']->id)->count());
        $this->assertEquals(0, WorkerWage::where('user_id', $this->t['buruh']->id)->value('amount'));
    }

    public function test_ubah_data_tanpa_upah_tidak_menghapus_upah_dan_tunjangan(): void
    {
        Sanctum::actingAs($this->t['owner']);

        $id = $this->postJson('/api/workers', $this->account('Mandor Baru', 'mandor', [
            'wage'       => ['wage_type' => 'bulanan', 'amount' => 4500000],
            'allowances' => $this->allowances(),
        ]))->assertCreated()->json('data.id');

        $this->putJson('/api/workers/' . $id, [
            'name'  => 'Mandor Ganti Nama',
            'email' => 'mandor.baru@test.com',
        ])->assertOk();

        $this->assertSame(1, WorkerWage::where('user_id', $id)->count());
        $this->assertSame(2, WorkerAllowance::where('user_id', $id)->count());
    }

    public function test_ubah_tunjangan_mengganti_seluruh_daftar(): void
    {
        Sanctum::actingAs($this->t['owner']);

        $id = $this->postJson('/api/workers', $this->account('Mandor Baru', 'mandor', [
            'wage'       => ['wage_type' => 'bulanan', 'amount' => 4500000],
            'allowances' => $this->allowances(),
        ]))->assertCreated()->json('data.id');

        $this->putJson('/api/workers/' . $id, [
            'name'       => 'Mandor Baru',
            'email'      => 'mandor.baru@test.com',
            'allowances' => [['name' => 'Tunjangan pulsa', 'amount' => 100000]],
        ])->assertOk()->assertJsonCount(1, 'data.allowances');

        $this->putJson('/api/workers/' . $id, [
            'name'       => 'Mandor Baru',
            'email'      => 'mandor.baru@test.com',
            'allowances' => [],
        ])->assertOk();

        $this->assertSame(0, WorkerAllowance::where('user_id', $id)->count());
    }

    public function test_nominal_negatif_atau_tidak_valid_ditolak(): void
    {
        Sanctum::actingAs($this->t['owner']);

        $this->postJson('/api/workers', $this->account('Buruh Baru', 'buruh', [
            'wage' => ['wage_type' => 'harian', 'amount' => -1],
        ]))->assertUnprocessable()->assertJsonValidationErrors('wage.amount');

        $this->postJson('/api/workers', $this->account('Mandor Baru', 'mandor', [
            'wage'       => ['wage_type' => 'bulanan', 'amount' => 1000000],
            'allowances' => [['name' => 'Transport', 'amount' => 'abc']],
        ]))->assertUnprocessable()->assertJsonValidationErrors('allowances.0.amount');

        $this->postJson('/api/workers', $this->account('Buruh Lain', 'buruh', [
            'wage' => ['wage_type' => 'harian'],
        ]))->assertUnprocessable()->assertJsonValidationErrors('wage.amount');
    }

    public function test_pemilik_perusahaan_lain_tidak_bisa_mengubah_upah(): void
    {
        $b = $this->makeTenant('b');

        Sanctum::actingAs($b['owner']);
        $this->putJson('/api/workers/' . $this->t['buruh']->id, [
            'name'  => 'Buruh a',
            'email' => 'buruh-a@test.com',
            'wage'  => ['wage_type' => 'harian', 'amount' => 1],
        ])->assertNotFound();

        $this->assertSame(0, WorkerWage::withoutGlobalScopes()->where('user_id', $this->t['buruh']->id)->count());
    }

    public function test_profil_sendiri_memuat_upah_dan_tunjangan(): void
    {
        $this->t['mandor']->wage()->forceCreate([
            'company_id' => $this->t['company']->id,
            'wage_type'  => 'bulanan',
            'amount'     => 4500000,
        ]);
        $this->t['mandor']->allowances()->forceCreate([
            'company_id' => $this->t['company']->id,
            'name'       => 'Tunjangan transport',
            'amount'     => 300000,
        ]);

        Sanctum::actingAs($this->t['mandor']);
        $this->getJson('/api/worker/profile')
            ->assertOk()
            ->assertJsonPath('data.wage.wage_type', 'bulanan')
            ->assertJsonCount(1, 'data.allowances');

        Sanctum::actingAs($this->t['buruh']);
        $this->getJson('/api/worker/profile')
            ->assertOk()
            ->assertJsonPath('data.wage', null)
            ->assertJsonCount(0, 'data.allowances');
    }
}
