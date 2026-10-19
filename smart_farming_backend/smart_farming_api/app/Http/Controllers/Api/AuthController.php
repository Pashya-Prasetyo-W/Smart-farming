<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\AuthService;
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
}