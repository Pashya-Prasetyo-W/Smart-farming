<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ToolIncident;
use App\Services\ToolIncidentService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class ToolIncidentController extends Controller
{
    public function __construct(
        protected ToolIncidentService $incidentService
    ) {}

    public function index(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'status' => ['nullable', Rule::in([ToolIncident::STATUS_TERBUKA, ToolIncident::STATUS_SELESAI])],
        ]);

        return response()->json([
            'message' => 'Daftar kerusakan dan kehilangan alat berhasil diambil.',
            'data'    => $this->incidentService->list($validated['status'] ?? null),
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'tool_id' => ['required', Rule::exists('tools', 'id')->where('company_id', $request->user()->company_id)],
            'kind'    => ['required', Rule::in([ToolIncident::KIND_HILANG, ToolIncident::KIND_RUSAK])],
            'qty'     => ['nullable', 'integer', 'min:1', 'max:1000'],
            'notes'   => ['nullable', 'string', 'max:1000'],
        ]);

        return response()->json([
            'message' => 'Kejadian alat berhasil dicatat.',
            'data'    => $this->incidentService->record($request->user(), $validated),
        ], 201);
    }

    public function resolve(Request $request, ToolIncident $incident): JsonResponse
    {
        $validated = $request->validate([
            'resolution' => ['required', Rule::in([
                ToolIncident::RESOLUTION_DIPERBAIKI,
                ToolIncident::RESOLUTION_DITEMUKAN,
                ToolIncident::RESOLUTION_DIGANTI,
                ToolIncident::RESOLUTION_DIHAPUSKAN,
            ])],
            'cost'       => ['nullable', 'numeric', 'min:0', 'max:1000000000'],
            'notes'      => ['nullable', 'string', 'max:1000'],
        ]);

        return response()->json([
            'message' => 'Kejadian alat berhasil diselesaikan.',
            'data'    => $this->incidentService->resolve($request->user(), $incident, $validated),
        ]);
    }
}
