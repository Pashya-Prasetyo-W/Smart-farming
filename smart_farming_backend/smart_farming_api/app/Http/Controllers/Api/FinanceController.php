<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Planting;
use App\Services\FinanceService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class FinanceController extends Controller
{
    public function __construct(
        protected FinanceService $financeService
    ) {}

    public function index(Request $request): JsonResponse
    {
        $month = $request->query('month');
        $year  = $request->query('year');

        $finances = $this->financeService->getFinances(
            $request->user(),
            $month ? (int) $month : null,
            $year ? (int) $year : null
        );

        return response()->json([
            'message' => 'Daftar transaksi keuangan berhasil diambil.',
            'data'    => $finances,
        ], 200);
    }

    public function store(Request $request): JsonResponse
    {
        // 1. Validasi input request
        $validatedData = $request->validate([
            'type'        => ['required', 'in:pemasukan,pengeluaran'],
            'amount'      => ['required', 'numeric', 'min:0'],
            'description' => ['required', 'string', 'max:255'],
            'planting_id' => ['nullable', 'exists:plantings,id'],
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
            'harvest_kg' => ['required', 'numeric', 'min:0.01'],
        ]);

        $hppPerKg = $this->financeService->calculateHPP($planting, (float) $validatedData['harvest_kg']);

        return response()->json([
            'message' => 'Perhitungan HPP berhasil dilakukan.',
            'data'    => [
                'hpp_per_kg' => $hppPerKg,
                'total_cost' => (float) $planting->total_cost,
                'harvest_kg' => (float) $validatedData['harvest_kg'],
            ],
        ], 200);
    }
}