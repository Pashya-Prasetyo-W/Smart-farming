<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\ToolService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ToolController extends Controller
{
    public function __construct(
        protected ToolService $toolService
    ) {}
    
    public function index(Request $request): JsonResponse
    {
        $tools = $this->toolService->getTools($request->user());

        return response()->json([
            'message' => 'Daftar alat berhasil diambil.',
            'data'    => $tools,
        ], 200);
    }

    public function store(Request $request):JsonResponse
    {
        $validateData = $request->validate([
            'name'       => ['required', 'string', 'max:255'],
            'unit_label' => ['nullable', 'string', 'max:50'],
            'total_qty'  => ['required', 'integer', 'min:1'],
        ]);

        $tool = $this->toolService->createTool($validateData, $request->user());

        return response()->json([
            'message' => 'Alat berhasil ditambahkan.',
            'data'    => $tool,
        ], 201);
    }
}
