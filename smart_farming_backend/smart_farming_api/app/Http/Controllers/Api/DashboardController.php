<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\DashboardService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DashboardController extends Controller
{
    public function __construct(
        protected DashboardService $dashboardService
    ) {}

    public function owner(Request $request): JsonResponse
    {
        abort_if(
            $request->user()->role !== 'pemilik',
            403,
            'Akses ditolak. Hanya pemilik yang dapat melihat statistik dasbor ini.'
        );

        $stats = $this->dashboardService->getOwnerStats($request->user());

        return response()->json([
            'message' => 'Statistik dasbor pemilik berhasil diambil.',
            'data'    => $stats,
        ], 200);
    }

    public function worker(Request $request): JsonResponse
    {
        abort_if(
            $request->user()->role !== 'buruh',
            403,
            'Akses ditolak. Hanya buruh yang dapat melihat statistik dasbor ini.'
        );

        $stats = $this->dashboardService->getWorkerStats($request->user());

        return response()->json([
            'message' => 'Statistik dasbor buruh berhasil diambil.',
            'data'    => $stats,
        ], 200);
    }
}