<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\FailureLog;
use App\Services\CropRiskService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class FailureLogController extends Controller
{
    public function __construct(private CropRiskService $cropRiskService) {}

    public function index(Request $request): JsonResponse
    {
        $companyId = $request->user()->company_id;

        $logs = FailureLog::where('company_id', $companyId)
            ->with('planting.land')
            ->latest()
            ->get();

        return response()->json([
            'message' => 'Data berhasil diambil',
            'data'    => $logs,
            'status'  => $this->cropRiskService->status($companyId),
        ], 200);
    }
}
