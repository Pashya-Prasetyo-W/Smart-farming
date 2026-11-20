<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Payroll;
use App\Services\PayrollService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PayrollController extends Controller
{
    public function __construct(
        protected PayrollService $payrollService
    ) {}

    public function index(): JsonResponse
    {
        return response()->json([
            'data' => $this->payrollService->list(),
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $validatedData = $request->validate([
            'period_start' => ['required', 'date_format:Y-m-d'],
            'period_end'   => ['required', 'date_format:Y-m-d'],
        ]);

        $payroll = $this->payrollService->create($request->user(), $validatedData);

        return response()->json([
            'message' => 'Rekap upah berhasil dibuat.',
            'data'    => $payroll,
        ], 201);
    }

    public function show(Payroll $payroll): JsonResponse
    {
        return response()->json([
            'data' => $this->payrollService->detail($payroll),
        ]);
    }

    public function recalculate(Payroll $payroll): JsonResponse
    {
        return response()->json([
            'message' => 'Rekap upah dihitung ulang.',
            'data'    => $this->payrollService->recalculate($payroll),
        ]);
    }

    public function approve(Request $request, Payroll $payroll): JsonResponse
    {
        return response()->json([
            'message' => 'Rekap upah disetujui.',
            'data'    => $this->payrollService->approve($request->user(), $payroll),
        ]);
    }

    public function pay(Payroll $payroll): JsonResponse
    {
        return response()->json([
            'message' => 'Rekap upah ditandai sudah dibayar.',
            'data'    => $this->payrollService->markPaid($payroll),
        ]);
    }

    public function destroy(Payroll $payroll): JsonResponse
    {
        $this->payrollService->delete($payroll);

        return response()->json(['message' => 'Rekap upah dihapus.']);
    }

    public function mine(Request $request): JsonResponse
    {
        return response()->json([
            'data' => $this->payrollService->mine($request->user()),
        ]);
    }
}
