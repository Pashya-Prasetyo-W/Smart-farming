<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Harvest;
use App\Models\Planting;
use App\Services\HarvestService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class HarvestController extends Controller
{
    public function __construct(
        protected HarvestService $harvestService
    ) {}

    public static function entryRules(bool $required): array
    {
        return [
            'harvest_date'  => ['nullable', 'date_format:Y-m-d'],
            'quantity_kg'   => [$required ? 'required' : 'nullable', 'numeric', 'min:0.01', 'max:100000000'],
            'sold_kg'       => ['nullable', 'numeric', 'min:0', 'max:100000000'],
            'price_per_kg'  => ['nullable', 'numeric', 'min:0', 'max:1000000000'],
        ];
    }

    public function store(Request $request, Planting $planting): JsonResponse
    {
        $validatedData = $request->validate(self::entryRules(true));

        $harvest = $this->harvestService->record($request->user(), $planting, $validatedData);

        return response()->json([
            'message' => 'Hasil panen berhasil dicatat.',
            'data'    => $harvest,
        ], 201);
    }

    public function destroy(Harvest $harvest): JsonResponse
    {
        $this->harvestService->delete($harvest);

        return response()->json(['message' => 'Catatan panen berhasil dihapus.']);
    }

    public function summary(Planting $planting): JsonResponse
    {
        return response()->json([
            'message' => 'Ringkasan siklus tanam berhasil diambil.',
            'data'    => $this->harvestService->summary($planting),
        ]);
    }
}
