<?php

namespace App\Services;

use App\Enums\UserRole;
use App\Mail\PasswordResetCodeMail;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Illuminate\Validation\ValidationException;

class PasswordResetService
{
    private const EXPIRY_MINUTES = 15;
    private const MAX_ATTEMPTS = 5;

    public function sendCode(string $email): void
    {
        $user = User::where('email', $email)->first();

        if (! $user || ! $user->is_active || $user->role !== UserRole::Pemilik->value) {
            return;
        }

        $code = (string) random_int(100000, 999999);

        DB::table('password_reset_codes')->updateOrInsert(
            ['email' => $user->email],
            [
                'code_hash'  => Hash::make($code),
                'attempts'   => 0,
                'expires_at' => now()->addMinutes(self::EXPIRY_MINUTES),
                'created_at' => now(),
                'updated_at' => now(),
            ]
        );

        Mail::to($user->email)->send(
            new PasswordResetCodeMail($user->name, $code, self::EXPIRY_MINUTES)
        );
    }

    public function reset(string $email, string $code, string $password): void
    {
        $invalid = ValidationException::withMessages([
            'code' => ['Kode tidak valid atau sudah kedaluwarsa.'],
        ]);

        $record = DB::table('password_reset_codes')->where('email', $email)->first();

        if (! $record) {
            throw $invalid;
        }

        if (Carbon::parse($record->expires_at)->isPast() || $record->attempts >= self::MAX_ATTEMPTS) {
            DB::table('password_reset_codes')->where('email', $email)->delete();
            throw $invalid;
        }

        if (! Hash::check($code, $record->code_hash)) {
            DB::table('password_reset_codes')->where('email', $email)->increment('attempts');
            throw $invalid;
        }

        $user = User::where('email', $email)->first();

        if (! $user || ! $user->is_active || $user->role !== UserRole::Pemilik->value) {
            throw $invalid;
        }

        DB::transaction(function () use ($user, $password, $email) {
            $user->forceFill([
                'password'             => $password,
                'must_change_password' => false,
            ])->save();

            $user->tokens()->delete();

            DB::table('password_reset_codes')->where('email', $email)->delete();
        });
    }
}
