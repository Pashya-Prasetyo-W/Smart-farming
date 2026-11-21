<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Finance;
use App\Models\Harvest;
use App\Models\Planting;
use App\Services\FinanceService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

class FinanceController extends Controller
{
    public function __construct(
        protected FinanceService $financeService
    ) {}

    public function index(Request $request): JsonResponse
    {
        $month = $request->query('month');
        $year  = $request->query('year');

        $plantingId = $request->query('planting_id');
        $category = $request->query('category');

        $finances = $this->financeService->getFinances(
            $request->user(),
            $month ? (int) $month : null,
            $year ? (int) $year : null,
            $plantingId ? (int) $plantingId : null,
            $category ?: null
        );

        return response()->json([
            'message' => 'Daftar transaksi keuangan berhasil diambil.',
            'data'    => $finances,
        ], 200);
    }

    public function store(Request $request): JsonResponse
    {
        $validatedData = $request->validate([
            'type'        => ['required', 'in:pemasukan,pengeluaran'],
            'category'    => ['nullable', 'in:bahan,upah,lainnya'],
            'amount'      => ['required', 'numeric', 'min:0'],
            'description' => ['required', 'string', 'max:255'],
            'planting_id' => [
                'nullable',
                \Illuminate\Validation\Rule::exists('plantings', 'id')->where('company_id', $request->user()->company_id),
            ],
            'record_date' => ['nullable', 'date'],
        ]);

        $finance = $this->financeService->createFinance($validatedData, $request->user());

        return response()->json([
            'message' => 'Transaksi keuangan berhasil dicatat.',
            'data'    => $finance,
        ], 201);
    }

    public function calculateHPP(Request $request, Planting $planting): JsonResponse
    {
        $validatedData = $request->validate([
            'harvest_kg' => ['nullable', 'numeric', 'min:0.01'],
        ]);

        $totalCost = (float) Finance::where('planting_id', $planting->id)
            ->where('type', 'pengeluaran')
            ->sum('amount');

        $harvestKg = isset($validatedData['harvest_kg'])
            ? (float) $validatedData['harvest_kg']
            : (float) Harvest::where('planting_id', $planting->id)->sum('quantity_kg');

        if ($harvestKg <= 0) {
            throw ValidationException::withMessages([
                'harvest_kg' => ['Belum ada hasil panen tercatat. Isi jumlah panen untuk menghitung HPP.'],
            ]);
        }

        return response()->json([
            'message' => 'Perhitungan HPP berhasil dilakukan.',
            'data'    => [
                'hpp_per_kg' => round($totalCost / $harvestKg, 2),
                'total_cost' => $totalCost,
                'harvest_kg' => $harvestKg,
            ],
        ], 200);
    }
}
