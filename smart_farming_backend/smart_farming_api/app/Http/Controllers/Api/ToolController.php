<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\ToolService;
use App\Models\Tool;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class ToolController extends Controller
{
    public function __construct(
        protected ToolService $toolService
    ) {}

    public function index(Request $request): JsonResponse
    {
        $tools = $this->toolService->getTools($request->user());
        return response()->json(['message' => 'Daftar alat berhasil diambil.', 'data' => $tools], 200);
    }

    public function store(Request $request): JsonResponse
    {
        $validatedData = $request->validate([
            'name'       => ['required', 'string', 'max:255'],
            'unit_label' => ['nullable', 'string', 'max:50'],
            'total_qty'  => ['required', 'integer', 'min:1'],
        ]);

        $tool = $this->toolService->createTool($validatedData, $request->user());
        return response()->json(['message' => 'Alat berhasil ditambahkan.', 'data' => $tool], 201);
    }

    public function update(Request $request, Tool $tool, ToolService $toolService): JsonResponse
    {
        $validatedData = $request->validate([
            'name'       => ['required', 'string', 'max:255'],
            'unit_label' => ['nullable', 'string', 'max:50'],
            'total_qty'  => ['required', 'integer', 'min:1'],
        ]);

        $updatedTool = $toolService->updateTool($tool, $validatedData);
        return response()->json(['message' => 'Alat berhasil diperbarui.', 'data' => $updatedTool], 200);
    }

    public function destroy(Tool $tool): JsonResponse
    {
        $isBorrowed = \App\Models\TaskTool::where('tool_id', $tool->id)
            ->whereHas('task', function($q) {
                $q->whereIn('status', ['menunggu', 'dikerjakan']);
            })->exists();

        if ($isBorrowed) {
            return response()->json(['message' => 'Gagal menghapus! Alat sedang digunakan di tugas aktif.'], 400);
        }

        $tool->delete();
        return response()->json(['message' => 'Alat berhasil dihapus.'], 200);
    }
}