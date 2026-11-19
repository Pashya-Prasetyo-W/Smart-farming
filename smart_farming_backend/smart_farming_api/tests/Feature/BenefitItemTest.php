<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\WorkerBenefitItem;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\Feature\Concerns\CreatesTenants;
use Tests\TestCase;

class BenefitItemTest extends TestCase
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

    private function benefits(): array
    {
        return [
            ['type' => 'kesehatan', 'name' => 'BPJS Kesehatan'],
            ['type' => 'kesehatan', 'name' => 'Asuransi Swasta', 'description' => 'Rawat jalan'],
            ['type' => 'makan', 'name' => 'Uang makan', 'description' => 'Rp 25.000 per hari'],
        ];
    }

    public function test_mandor_bisa_punya_lebih_dari_satu_jaminan(): void
    {
        Sanctum::actingAs($this->t['owner']);

        $response = $this->postJson('/api/workers', $this->account('Mandor Baru', 'mandor', [
            'benefits' => $this->benefits(),
        ]))->assertCreated();

        $response->assertJsonCount(3, 'data.benefits');

        $this->assertSame(3, WorkerBenefitItem::where('user_id', $response->json('data.id'))->count());
        $this->assertSame(
            2,
            WorkerBenefitItem::where('user_id', $response->json('data.id'))->where('type', 'kesehatan')->count()
        );
    }

    public function test_buruh_tidak_mendapat_jaminan_walau_dikirim(): void
    {
        Sanctum::actingAs($this->t['mandor']);

        $response = $this->postJson('/api/workers', $this->account('Buruh Baru', 'buruh', [
            'benefits' => $this->benefits(),
        ]))->assertCreated();

        $response->assertJsonCount(0, 'data.benefits');
        $this->assertSame(0, WorkerBenefitItem::where('user_id', $response->json('data.id'))->count());
    }

    public function test_ubah_jaminan_mandor_mengganti_seluruh_daftar(): void
    {
        Sanctum::actingAs($this->t['owner']);

        $id = $this->postJson('/api/workers', $this->account('Mandor Baru', 'mandor', [
            'benefits' => $this->benefits(),
        ]))->assertCreated()->json('data.id');

        $this->putJson('/api/workers/' . $id, [
            'name'     => 'Mandor Baru',
            'email'    => 'mandor.baru@test.com',
            'benefits' => [['type' => 'makan', 'name' => 'Nasi bungkus']],
        ])->assertOk()->assertJsonCount(1, 'data.benefits');

        $this->assertSame(1, WorkerBenefitItem::where('user_id', $id)->count());

        $this->putJson('/api/workers/' . $id, [
            'name'     => 'Mandor Baru',
            'email'    => 'mandor.baru@test.com',
            'benefits' => [],
        ])->assertOk();

        $this->assertSame(0, WorkerBenefitItem::where('user_id', $id)->count());
    }

    public function test_ubah_data_tanpa_mengirim_jaminan_tidak_menghapus_jaminan(): void
    {
        Sanctum::actingAs($this->t['owner']);

        $id = $this->postJson('/api/workers', $this->account('Mandor Baru', 'mandor', [
            'benefits' => $this->benefits(),
        ]))->assertCreated()->json('data.id');

        $this->putJson('/api/workers/' . $id, [
            'name'  => 'Mandor Ganti Nama',
            'email' => 'mandor.baru@test.com',
        ])->assertOk();

        $this->assertSame(3, WorkerBenefitItem::where('user_id', $id)->count());
    }

    public function test_ubah_data_buruh_tidak_membuat_jaminan(): void
    {
        Sanctum::actingAs($this->t['mandor']);

        $this->putJson('/api/workers/' . $this->t['buruh']->id, [
            'name'     => 'Buruh a',
            'email'    => 'buruh-a@test.com',
            'benefits' => $this->benefits(),
        ])->assertOk()->assertJsonCount(0, 'data.benefits');

        $this->assertSame(0, WorkerBenefitItem::where('user_id', $this->t['buruh']->id)->count());
    }

    public function test_jenis_jaminan_harus_valid(): void
    {
        Sanctum::actingAs($this->t['owner']);

        $this->postJson('/api/workers', $this->account('Mandor Baru', 'mandor', [
            'benefits' => [['type' => 'lainnya', 'name' => 'X']],
        ]))->assertUnprocessable()->assertJsonValidationErrors('benefits.0.type');

        $this->postJson('/api/workers', $this->account('Mandor Baru', 'mandor', [
            'benefits' => [['type' => 'makan']],
        ]))->assertUnprocessable()->assertJsonValidationErrors('benefits.0.name');
    }

    public function test_pemilik_perusahaan_lain_tidak_melihat_jaminan_mandor(): void
    {
        $b = $this->makeTenant('b');

        Sanctum::actingAs($this->t['owner']);
        $this->postJson('/api/workers', $this->account('Mandor Baru', 'mandor', [
            'benefits' => $this->benefits(),
        ]))->assertCreated();

        Sanctum::actingAs($b['owner']);
        $this->assertSame(0, WorkerBenefitItem::count());
    }

    public function test_profil_mandor_memuat_daftar_jaminan(): void
    {
        $this->t['mandor']->benefits()->forceCreate([
            'company_id' => $this->t['company']->id,
            'type'       => 'makan',
            'name'       => 'Uang makan',
        ]);

        Sanctum::actingAs($this->t['mandor']);
        $this->getJson('/api/worker/profile')->assertOk()->assertJsonCount(1, 'data.benefits');

        Sanctum::actingAs(User::find($this->t['buruh']->id));
        $this->getJson('/api/worker/profile')->assertOk()->assertJsonCount(0, 'data.benefits');
    }
}
