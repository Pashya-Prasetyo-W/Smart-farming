<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Exception;

class GeminiService
{
    public function ask(string $question): string
    {
        $apiKey = config('services.gemini.key');

        $systemPrompt = "Anda adalah asisten ahli pertanian (agronomi) yang ramah dan membantu. Jawab pertanyaan pengguna dengan singkat, padat, dan solutif terkait masalah tanaman, hama, atau pertanian.";

        $promptGabungan = "{$systemPrompt}\n\nPertanyaan Pengguna: {$question}";

        $response = Http::post("https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent?key={$apiKey}", [
        'contents' => [
            [
                    'parts' => [
                        ['text' => $promptGabungan]
                    ]
                ]
            ]
        ]);

        if ($response->failed()) {
            Log::error('Gagal mengambil respons dari Gemini API: ' . $response->body());
            throw new Exception('Layanan AI sedang tidak tersedia. Silakan coba beberapa saat lagi.');
        }

        $answer = $response->json('candidates.0.content.parts.0.text');

        if (!$answer) {
            throw new Exception('Format respons dari AI tidak valid.');
        }

        return $answer;
    }
}