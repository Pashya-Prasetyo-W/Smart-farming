<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\IncidentReportService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class IncidentReportController extends Controller
{
    public function __construct(
        protected IncidentReportService $incidentService
    ) {}

    public function index(Request $request): JsonResponse
    {
        $incidents = $this->incidentService->getIncidents($request->user());

        return response()->json([
            'message' => 'Daftar laporan insiden berhasil diambil.',
            'data'    => $incidents,
        ], 200);
    }

    public function store(Request $request): JsonResponse
    {
        $validatedData = $request->validate([
            'land_id'          => ['required', 'exists:lands,id'],
            'type'             => ['required', 'in:hama,penyakit_tanaman,kerusakan_lahan,cuaca_ekstrem,lainnya'],
            'description'      => ['required', 'string'],
            'media_urls'       => ['nullable', 'array'],
            'media_urls.*'     => ['string'],
            'reported_at'      => ['nullable', 'date'],
        ]);

        $incident = $this->incidentService->createIncident($validatedData, $request->user());

        return response()->json([
            'message' => 'Laporan insiden berhasil dikirim.',
            'data'    => $incident,
        ], 201);
    }
}