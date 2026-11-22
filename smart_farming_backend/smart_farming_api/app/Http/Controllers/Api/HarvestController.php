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

    public function index(Planting $planting): JsonResponse
    {
        $harvests = Harvest::where('planting_id', $planting->id)
            ->with('recorder:id,name')
            ->orderByDesc('harvest_date')
            ->orderByDesc('id')
            ->get();

        return response()->json([
            'message' => 'Catatan panen berhasil diambil.',
            'data'    => [
                'planting'     => [
                    'id'        => $planting->id,
                    'crop_name' => $planting->crop_name,
                    'status'    => $planting->status,
                ],
                'harvested_kg' => round((float) $harvests->sum('quantity_kg'), 2),
                'sold_kg'      => round((float) $harvests->sum('sold_kg'), 2),
                'harvests'     => $harvests,
            ],
        ]);
    }

    public function destroy(Request $request, Harvest $harvest): JsonResponse
    {
        $user = $request->user();

        abort_unless(
            $user->hasRole('pemilik') || $harvest->recorded_by === $user->id,
            403,
            'Mandor hanya dapat menghapus catatan panen yang ia input sendiri.'
        );

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
