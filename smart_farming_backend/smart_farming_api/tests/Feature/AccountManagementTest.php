<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\Feature\Concerns\CreatesTenants;
use Tests\TestCase;

class AccountManagementTest extends TestCase
{
    use RefreshDatabase, CreatesTenants;

    private array $t;

    protected function setUp(): void
    {
        parent::setUp();

        $this->t = $this->makeTenant('a');
    }

    private function newAccount(string $name, ?string $role = null): array
    {
        return array_filter([
            'name'     => $name,
            'email'    => strtolower(str_replace(' ', '.', $name)) . '@test.com',
            'password' => 'password123',
            'role'     => $role,
        ]);
    }

    public function test_pemilik_membuat_mandor_dengan_wajib_ganti_password(): void
    {
        Sanctum::actingAs($this->t['owner']);

        $id = $this->postJson('/api/workers', $this->newAccount('Mandor Baru', 'mandor'))
            ->assertCreated()
            ->json('data.id');

        $mandor = User::find($id);

        $this->assertSame('mandor', $mandor->role);
        $this->assertSame($this->t['company']->id, $mandor->company_id);
        $this->assertSame($this->t['owner']->id, $mandor->created_by);
        $this->assertTrue($mandor->must_change_password);
        $this->assertTrue($mandor->is_active);
    }

    public function test_mandor_membuat_buruh_tetapi_tidak_bisa_membuat_mandor(): void
    {
        Sanctum::actingAs($this->t['mandor']);

        $id = $this->postJson('/api/workers', $this->newAccount('Buruh Baru'))
            ->assertCreated()
            ->json('data.id');

        $buruh = User::find($id);
        $this->assertSame('buruh', $buruh->role);
        $this->assertSame($this->t['mandor']->id, $buruh->created_by);
        $this->assertTrue($buruh->must_change_password);

        $this->postJson('/api/workers', $this->newAccount('Mandor Gelap', 'mandor'))->assertForbidden();
        $this->assertNull(User::where('email', 'mandor.gelap@test.com')->first());
    }

    public function test_mandor_hanya_melihat_dan_mengelola_buruh(): void
    {
        $mandor2 = User::create([
            'name'       => 'Mandor Dua',
            'email'      => 'mandor-dua@test.com',
            'password'   => 'password123',
            'role'       => 'mandor',
            'company_id' => $this->t['company']->id,
        ]);

        Sanctum::actingAs($this->t['mandor']);

        $roles = collect($this->getJson('/api/workers')->assertOk()->json('data'))
            ->pluck('role')
            ->unique()
            ->all();
        $this->assertSame(['buruh'], $roles);

        $payload = ['name' => 'Diubah', 'email' => 'diubah@test.com'];
        $this->putJson('/api/workers/' . $mandor2->id, $payload)->assertNotFound();
        $this->putJson('/api/workers/' . $this->t['owner']->id, $payload)->assertNotFound();
        $this->postJson('/api/workers/' . $mandor2->id . '/deactivate')->assertNotFound();
        $this->assertTrue(User::find($mandor2->id)->is_active);
    }

    public function test_pemilik_melihat_mandor_dan_buruh(): void
    {
        Sanctum::actingAs($this->t['owner']);

        $roles = collect($this->getJson('/api/workers')->assertOk()->json('data'))
            ->pluck('role')
            ->sort()
            ->values()
            ->all();

        $this->assertSame(['buruh', 'mandor'], $roles);
    }

    public function test_akun_wajib_ganti_password_hanya_bisa_mengganti_password(): void
    {
        $baru = User::create([
            'name'       => 'Akun Baru',
            'email'      => 'akun-baru@test.com',
            'password'   => 'password123',
            'role'       => 'buruh',
            'company_id' => $this->t['company']->id,
        ]);
        $baru->forceFill(['must_change_password' => true])->save();

        Sanctum::actingAs($baru);

        $this->getJson('/api/lands')
            ->assertForbidden()
            ->assertJsonPath('code', 'password_change_required');

        $this->postJson('/api/auth/change-password', [
            'current_password'      => 'password123',
            'password'              => 'rahasiaBaru1',
            'password_confirmation' => 'rahasiaBaru1',
        ])->assertOk();

        $this->assertFalse(User::find($baru->id)->must_change_password);
        $this->getJson('/api/lands')->assertOk();
    }

    public function test_ganti_password_menolak_password_lama_yang_salah_dan_password_yang_sama(): void
    {
        Sanctum::actingAs($this->t['buruh']);

        $this->postJson('/api/auth/change-password', [
            'current_password'      => 'salah-total',
            'password'              => 'rahasiaBaru1',
            'password_confirmation' => 'rahasiaBaru1',
        ])->assertUnprocessable()->assertJsonValidationErrors('current_password');

        $this->postJson('/api/auth/change-password', [
            'current_password'      => 'password123',
            'password'              => 'password123',
            'password_confirmation' => 'password123',
        ])->assertUnprocessable()->assertJsonValidationErrors('password');
    }

    public function test_menonaktifkan_akun_mencabut_token_dan_menolak_login(): void
    {
        $buruh = $this->t['buruh'];
        $buruh->createToken('perangkat-lama');
        $this->assertSame(1, $buruh->tokens()->count());

        Sanctum::actingAs($this->t['mandor']);
        $this->postJson('/api/workers/' . $buruh->id . '/deactivate')->assertOk();

        $this->assertFalse(User::find($buruh->id)->is_active);
        $this->assertSame(0, $buruh->tokens()->count());

        $this->postJson('/api/auth/login', [
            'email'    => $buruh->email,
            'password' => 'password123',
        ])->assertUnprocessable()->assertJsonValidationErrors('email');
    }

    public function test_akun_nonaktif_ditolak_walau_masih_membawa_sesi(): void
    {
        $buruh = $this->t['buruh'];
        $buruh->forceFill(['is_active' => false])->save();

        Sanctum::actingAs($buruh);

        $this->getJson('/api/user')
            ->assertForbidden()
            ->assertJsonPath('code', 'account_inactive');
    }

    public function test_akun_bisa_diaktifkan_kembali(): void
    {
        $buruh = $this->t['buruh'];
        $buruh->forceFill(['is_active' => false])->save();

        Sanctum::actingAs($this->t['mandor']);
        $this->postJson('/api/workers/' . $buruh->id . '/activate')->assertOk();

        $this->assertTrue(User::find($buruh->id)->is_active);
    }

    public function test_reset_password_oleh_atasan_mewajibkan_ganti_dan_mencabut_sesi(): void
    {
        $buruh = $this->t['buruh'];
        $buruh->createToken('perangkat-lama');

        Sanctum::actingAs($this->t['mandor']);
        $this->putJson('/api/workers/' . $buruh->id, [
            'name'     => $buruh->name,
            'email'    => $buruh->email,
            'password' => 'sementara123',
        ])->assertOk();

        $fresh = User::find($buruh->id);
        $this->assertTrue($fresh->must_change_password);
        $this->assertSame(0, $buruh->tokens()->count());
    }

    public function test_akun_dengan_riwayat_tidak_bisa_dihapus_tetapi_akun_kosong_bisa(): void
    {
        Sanctum::actingAs($this->t['owner']);
        $this->postJson('/api/tasks', $this->taskPayload($this->t))->assertCreated();

        $this->deleteJson('/api/workers/' . $this->t['buruh']->id)->assertUnprocessable();
        $this->assertNotNull(User::find($this->t['buruh']->id));

        $id = $this->postJson('/api/workers', $this->newAccount('Buruh Sementara'))
            ->assertCreated()
            ->json('data.id');

        $this->deleteJson('/api/workers/' . $id)->assertOk();
        $this->assertNull(User::find($id));
    }
}
