<?php

namespace Tests\Feature;

use App\Mail\PasswordResetCodeMail;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Mail;
use Tests\Feature\Concerns\CreatesTenants;
use Tests\TestCase;

class PasswordResetTest extends TestCase
{
    use RefreshDatabase, CreatesTenants;

    private array $t;

    protected function setUp(): void
    {
        parent::setUp();

        Mail::fake();

        $this->t = $this->makeTenant('a');
    }

    private function requestCode(string $email = 'pemilik-a@test.com'): string
    {
        $this->postJson('/api/auth/forgot-password', ['email' => $email])->assertOk();

        return Mail::sent(PasswordResetCodeMail::class)->last()->code;
    }

    private function reset(string $code, string $password = 'passwordbaru1'): \Illuminate\Testing\TestResponse
    {
        return $this->postJson('/api/auth/reset-password', [
            'email'                 => 'pemilik-a@test.com',
            'code'                  => $code,
            'password'              => $password,
            'password_confirmation' => $password,
        ]);
    }

    public function test_pemilik_menerima_kode_lewat_email(): void
    {
        $this->postJson('/api/auth/forgot-password', ['email' => 'pemilik-a@test.com'])
            ->assertOk();

        Mail::assertSent(PasswordResetCodeMail::class, function ($mail) {
            return $mail->hasTo('pemilik-a@test.com') && preg_match('/^\d{6}$/', $mail->code) === 1;
        });
    }

    public function test_respons_sama_untuk_email_tidak_dikenal_agar_tidak_bisa_ditebak(): void
    {
        $known = $this->postJson('/api/auth/forgot-password', ['email' => 'pemilik-a@test.com'])->json('message');
        $unknown = $this->postJson('/api/auth/forgot-password', ['email' => 'tidak-ada@test.com'])->json('message');

        $this->assertSame($known, $unknown);
        Mail::assertSent(PasswordResetCodeMail::class, 1);
    }

    public function test_mandor_dan_buruh_tidak_menerima_kode(): void
    {
        $this->postJson('/api/auth/forgot-password', ['email' => 'mandor-a@test.com'])->assertOk();
        $this->postJson('/api/auth/forgot-password', ['email' => 'buruh-a@test.com'])->assertOk();

        Mail::assertNothingSent();
    }

    public function test_pemilik_nonaktif_tidak_menerima_kode(): void
    {
        $this->t['owner']->forceFill(['is_active' => false])->save();

        $this->postJson('/api/auth/forgot-password', ['email' => 'pemilik-a@test.com'])->assertOk();

        Mail::assertNothingSent();
    }

    public function test_kode_benar_mengganti_password_dan_mencabut_semua_sesi(): void
    {
        $this->t['owner']->createToken('perangkat-lama');
        $this->t['owner']->createToken('perangkat-lain');

        $code = $this->requestCode();

        $this->reset($code)->assertOk();

        $this->assertSame(0, $this->t['owner']->tokens()->count());

        $this->postJson('/api/auth/login', [
            'email'    => 'pemilik-a@test.com',
            'password' => 'passwordbaru1',
        ])->assertOk();

        $this->postJson('/api/auth/login', [
            'email'    => 'pemilik-a@test.com',
            'password' => 'password123',
        ])->assertUnprocessable();
    }

    public function test_kode_hanya_bisa_dipakai_sekali(): void
    {
        $code = $this->requestCode();

        $this->reset($code)->assertOk();
        $this->reset($code, 'passwordlain2')->assertUnprocessable()->assertJsonValidationErrors('code');
    }

    public function test_kode_salah_ditolak(): void
    {
        $this->requestCode();

        $this->reset('000000')->assertUnprocessable()->assertJsonValidationErrors('code');

        $this->postJson('/api/auth/login', [
            'email'    => 'pemilik-a@test.com',
            'password' => 'password123',
        ])->assertOk();
    }

    public function test_kode_hangus_setelah_lima_kali_salah(): void
    {
        $code = $this->requestCode();

        for ($i = 0; $i < 5; $i++) {
            $this->reset('000000')->assertUnprocessable();
        }

        $this->reset($code)->assertUnprocessable()->assertJsonValidationErrors('code');
    }

    public function test_kode_kedaluwarsa_setelah_lima_belas_menit(): void
    {
        $code = $this->requestCode();

        $this->travel(16)->minutes();

        $this->reset($code)->assertUnprocessable()->assertJsonValidationErrors('code');
        $this->assertSame(0, DB::table('password_reset_codes')->count());
    }

    public function test_permintaan_kode_baru_mengganti_kode_lama(): void
    {
        $lama = $this->requestCode();
        $baru = $this->requestCode();

        if ($lama !== $baru) {
            $this->reset($lama)->assertUnprocessable();
        }

        $this->reset($baru)->assertOk();
        $this->assertSame(0, DB::table('password_reset_codes')->count());
    }

    public function test_password_baru_harus_valid(): void
    {
        $code = $this->requestCode();

        $this->postJson('/api/auth/reset-password', [
            'email'                 => 'pemilik-a@test.com',
            'code'                  => $code,
            'password'              => 'pendek',
            'password_confirmation' => 'pendek',
        ])->assertUnprocessable()->assertJsonValidationErrors('password');

        $this->postJson('/api/auth/reset-password', [
            'email'                 => 'pemilik-a@test.com',
            'code'                  => $code,
            'password'              => 'passwordbaru1',
            'password_confirmation' => 'beda-sekali1',
        ])->assertUnprocessable()->assertJsonValidationErrors('password');
    }

    public function test_reset_tanpa_meminta_kode_ditolak(): void
    {
        $this->reset('123456')->assertUnprocessable()->assertJsonValidationErrors('code');
    }
}
