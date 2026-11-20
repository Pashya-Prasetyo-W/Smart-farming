<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\AuthService;
use App\Services\PasswordResetService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AuthController extends Controller
{
    public function __construct(
        protected AuthService $authService
    ) {}

    public function register(Request $request): JsonResponse
    {
        $validatedData = $request->validate([
            'name'         => ['required', 'string', 'max:255'],
            'email'        => ['required', 'string', 'email', 'max:255', 'unique:users'],
            'password'     => ['required', 'string', 'min:8'],
            'company_name' => ['required', 'string', 'max:255'],
        ]);

        $result = $this->authService->register($validatedData);

        return response()->json([
            'message' => 'Registrasi berhasil.',
            'data'    => $result,
        ], 201);
    }

    public function login(Request $request): JsonResponse
    {
        $credentials = $request->validate([
            'email'    => ['required', 'string', 'email'],
            'password' => ['required', 'string'],
        ]);

        $result = $this->authService->login($credentials);

        return response()->json([
            'message' => 'Login berhasil.',
            'data'    => $result,
        ], 200);
    }

    public function logout(Request $request): JsonResponse
    {
        $this->authService->logout($request->user());

        return response()->json([
            'message' => 'Berhasil keluar (logout).',
        ], 200);
    }

    public function forgotPassword(Request $request, PasswordResetService $passwordResets): JsonResponse
    {
        $validatedData = $request->validate([
            'email' => ['required', 'string', 'email'],
        ]);

        $passwordResets->sendCode($validatedData['email']);

        return response()->json([
            'message' => 'Jika email terdaftar sebagai akun pemilik, kode pengaturan ulang password telah dikirim.',
        ], 200);
    }

    public function resetPassword(Request $request, PasswordResetService $passwordResets): JsonResponse
    {
        $validatedData = $request->validate([
            'email'    => ['required', 'string', 'email'],
            'code'     => ['required', 'digits:6'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
        ]);

        $passwordResets->reset(
            $validatedData['email'],
            $validatedData['code'],
            $validatedData['password']
        );

        return response()->json([
            'message' => 'Password berhasil diatur ulang. Silakan login.',
        ], 200);
    }

    public function changePassword(Request $request): JsonResponse
    {
        $validatedData = $request->validate([
            'current_password' => ['required', 'string'],
            'password'         => ['required', 'string', 'min:8', 'confirmed', 'different:current_password'],
        ]);

        $this->authService->changePassword(
            $request->user(),
            $validatedData['current_password'],
            $validatedData['password']
        );

        return response()->json([
            'message' => 'Password berhasil diganti.',
        ], 200);
    }
}