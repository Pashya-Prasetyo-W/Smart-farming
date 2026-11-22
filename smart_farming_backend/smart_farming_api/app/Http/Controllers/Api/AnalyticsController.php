<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\AnalyticsService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class AnalyticsController extends Controller
{
    public function __construct(
        protected AnalyticsService $analyticsService
    ) {}

    public function profit(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'land_id' => ['nullable', Rule::exists('lands', 'id')->where('company_id', $request->user()->company_id)],
            'status'  => ['nullable', Rule::in(['berjalan', 'panen', 'gagal'])],
        ]);

        return response()->json([
            'message' => 'Analitik laba berhasil diambil.',
            'data'    => $this->analyticsService->profit($validated),
        ]);
    }

    public function risk(): JsonResponse
    {
        return response()->json([
            'message' => 'Analitik risiko berhasil diambil.',
            'data'    => $this->analyticsService->risk(),
        ]);
    }
}
