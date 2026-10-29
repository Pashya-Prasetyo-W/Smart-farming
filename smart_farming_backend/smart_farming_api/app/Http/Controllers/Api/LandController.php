<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\LandService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class LandController extends Controller
{
    public function __construct(
        protected LandService $landService
    ) {}

    public function index(Request $request): JsonResponse
    {
        $lands = \App\Models\Land::where('company_id', $request->user()->company_id)
            ->with(['activePlanting'])
            ->latest()
            ->get();

        return response()->json(['message' => 'Daftar lahan berhasil diambil.', 'data' => $lands], 200);
    }

    public function store(Request $request): JsonResponse
    {
        $validatedData = $request->validate([
            'name'          => ['required', 'string', 'max:255'],
            'area_sqm'      => ['required', 'numeric', 'min:0'],
            'location_lat'  => ['required', 'numeric', 'between:-90,90'],
            'location_long' => ['required', 'numeric', 'between:-180,180'],
        ]);

        $land = $this->landService->createLand($validatedData, $request->user());

        return response()->json([
            'message' => 'Lahan berhasil dibuat.',
            'data'    => $land,
        ], 201);
    }

    public function update(Request $request, \App\Models\Land $land): JsonResponse
    {
        $validatedData = $request->validate([
            'name'          => ['required', 'string', 'max:255'],
            'area_sqm'      => ['required', 'numeric', 'min:0'],
            'location_lat'  => ['required', 'numeric', 'between:-90,90'],
            'location_long' => ['required', 'numeric', 'between:-180,180'],
        ]);

        $land->update($validatedData);

        return response()->json(['message' => 'Lahan berhasil diperbarui.', 'data' => $land], 200);
    }
}