<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\HarvestService;
use App\Services\PlantingService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PlantingController extends Controller
{
    public function __construct(
        protected PlantingService $plantingService,
        protected HarvestService $harvestService
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
            'land_id'          => [
                'required',
                \Illuminate\Validation\Rule::exists('lands', 'id')->where('company_id', $request->user()->company_id),
            ],
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
        $validatedData = $request->validate([
            'harvest_date' => ['nullable', 'date_format:Y-m-d'],
            'harvest_kg'   => ['nullable', 'numeric', 'min:0.1', 'max:100000000'],
            'sold_kg'      => ['nullable', 'numeric', 'min:0', 'max:100000000'],
            'price_per_kg' => ['nullable', 'numeric', 'min:0', 'max:1000000000'],
        ]);

        $finalEntry = isset($validatedData['harvest_kg'])
            ? array_merge($validatedData, ['quantity_kg' => $validatedData['harvest_kg']])
            : [];

        $result = $this->harvestService->close($request->user(), $planting, $finalEntry);

        return response()->json([
            'message' => 'Siklus tanam berhasil diselesaikan (Panen).',
            'data'    => $result,
        ], 200);
    }

    public function cancelPlanting(Request $request, \App\Models\Planting $planting): JsonResponse
    {
        $result = $this->harvestService->cancel($planting);

        return response()->json([
            'message' => 'Siklus tanam berhasil dibatalkan (Gagal).',
            'data'    => $result,
        ], 200);
    }
}