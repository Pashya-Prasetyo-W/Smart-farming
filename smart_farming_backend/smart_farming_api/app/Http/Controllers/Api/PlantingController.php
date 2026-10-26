<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\PlantingService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PlantingController extends Controller
{
    public function __construct(
        protected PlantingService $plantingService
    ) {}

    public function index(Request $request): JsonResponse
    {
        $plantings = $this->plantingService->getPlantings($request->user());

        return response()->json([
            'message' => 'Daftar siklus tanam berhasil diambil.',
            'data'    => $plantings,
        ], 200);
    }

    public function store(Request $request): JsonResponse
    {
        $validatedData = $request->validate([
            'land_id'          => ['required', 'exists:lands,id'],
            'crop_name'        => ['required', 'string', 'max:255'],
            'plant_date'       => ['required', 'date'],
            'est_harvest_date' => ['required', 'date', 'after_or_equal:plant_date'],
        ]);

        $planting = $this->plantingService->createPlanting($validatedData, $request->user());

        return response()->json([
            'message' => 'Siklus tanam berhasil dibuat.',
            'data'    => $planting,
        ], 201);
    }

    public function harvest(Request $request, \App\Models\Planting $planting): JsonResponse
    {
        if ($planting->status !== 'berjalan') {
            return response()->json(['message' => 'Siklus ini sudah selesai atau dibatalkan.'], 400);
        }

        $request->validate([
            'harvest_kg' => 'required|numeric|min:0.1',
        ]);

        $planting->update(['status' => 'panen']);

        return response()->json([
            'message' => 'Siklus tanam berhasil diselesaikan (Panen).',
            'data'    => $planting
        ], 200);
    }

    public function cancelPlanting(Request $request, \App\Models\Planting $planting): JsonResponse
    {
        if ($planting->status !== 'berjalan') {
            return response()->json(['message' => 'Siklus ini sudah selesai atau dibatalkan.'], 400);
        }

        $planting->update(['status' => 'gagal']);

        return response()->json([
            'message' => 'Siklus tanam berhasil dibatalkan (Gagal).',
            'data'    => $planting
        ], 200);
    }
}