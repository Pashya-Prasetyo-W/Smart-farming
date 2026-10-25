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

    public function weather(Request $request, \App\Services\WeatherService $weatherService): JsonResponse
    {
        $landId = $request->query('land_id');
        
        $query = \App\Models\Land::where('company_id', $request->user()->company_id);
        
        if ($landId) {
            $land = $query->find($landId);
        } else {
            $land = $query->first();
        }

        if (!$land) {
            return response()->json(['message' => 'Tidak ada lahan terdaftar.'], 404);
        }

        try {
            $weatherData = $weatherService->getForecast((float) $land->location_lat, (float) $land->location_long);
            $current = $weatherData['list'][0] ?? null;
            
            if ($current) {
                return response()->json([
                    'message' => 'Data cuaca berhasil diambil.',
                    'data' => [
                        'land_id'     => $land->id,
                        'land_name'   => $land->name,
                        'temperature' => $current['main']['temp'],
                        'humidity'    => $current['main']['humidity'],
                        'condition'   => $current['weather'][0]['main'],
                        'description' => $current['weather'][0]['description'],
                    ]
                ], 200);
            }
        } catch (\Exception $e) {
            return response()->json(['message' => 'Gagal mengambil data cuaca.'], 500);
        }

        return response()->json(['message' => 'Data cuaca tidak tersedia.'], 404);
    }
}