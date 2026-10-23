<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\ResourceService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use App\Models\Resource;

class ResourceController extends Controller
{
    public function __construct(
        protected ResourceService $resourceService
    ) {}

    public function index(Request $request): JsonResponse
    {
        $resources = $this->resourceService->getResources($request->user());
        return response()->json(['message' => 'Daftar bahan berhasil diambil.', 'data' => $resources], 200);
    }

    public function store(Request $request)
    {
        $validatedData = $request->validate([
            'name'       => ['required', 'string', 'max:255'],
            'unit'       => ['required', 'string', 'max:50'],
            'stock_qty'  => ['required', 'numeric', 'min:0'],
            'unit_price' => ['required', 'numeric', 'min:0'],
        ]);

        $resource = $this->resourceService->createResource($validatedData, $request->user());
        return response()->json(['message' => 'Bahan berhasil ditambahkan.', 'data' => $resource], 201);
    }

    public function update(Request $request, Resource $resource): JsonResponse
    {
        $validatedData = $request->validate([
            'name'       => ['required', 'string', 'max:255'],
            'unit'       => ['required', 'string', 'max:50'],
            'stock_qty'  => ['required', 'numeric', 'min:0'],
            'unit_price' => ['required', 'numeric', 'min:0'],
        ]);

        $resource->update($validatedData);
        return response()->json(['message' => 'Bahan berhasil diperbarui.', 'data' => $resource], 200);
    }

    public function destroy(Resource $resource): JsonResponse
    {
        try {
            $isActive = \App\Models\TaskResource::where('resource_id', $resource->id)
                ->whereHas('task', function($q) {
                    $q->whereIn('status', ['menunggu', 'dikerjakan']);
                })->exists();

            if ($isActive) {
                return response()->json(['message' => 'Gagal! Bahan sedang dipakai di tugas aktif.'], 400);
            }

            \App\Models\TaskResource::where('resource_id', $resource->id)->delete();

            $resource->delete();
            return response()->json(['message' => 'Bahan berhasil dihapus.'], 200);
        } catch (\Exception $e) {
            return response()->json(['message' => 'Gagal menghapus: ' . $e->getMessage()], 500);
        }
    }
}