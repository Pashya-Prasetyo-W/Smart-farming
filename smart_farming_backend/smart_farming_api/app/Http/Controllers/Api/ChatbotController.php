<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\GeminiService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ChatbotController extends Controller
{
    public function __construct(
        protected GeminiService $geminiService
    ) {}

    public function ask(Request $request): JsonResponse
    {
        abort_if(
            $request->user()->role !== 'pemilik',
            403,
            'Akses ditolak. Fitur AI hanya untuk Pemilik.'
        );

        $validatedData = $request->validate([
            'question' => ['required', 'string', 'max:1000'],
        ]);

        $answer = $this->geminiService->ask($validatedData['question']);

        return response()->json([
            'message' => 'Jawaban AI berhasil didapatkan.',
            'data'    => [
                'answer' => $answer,
            ],
        ], 200);
    }
}