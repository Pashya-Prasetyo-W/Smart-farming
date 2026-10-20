<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\ResourceService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ResourceController extends Controller
{
    public function __construct(
        protected ResourceService $resourceService
    ) {}

    public function index(Request $request): JsonResponse
    {
        $resources = $this->resourceService->getResources($request->user());

        return response()->json([
            'message' => 'Daftar bahan/pupuk berhasil diambil.',
            'data'    => $resources,
        ], 200);
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

        return response()->json([
            'message' => 'Bahan/pupuk berhasil ditambahkan.',
            'data'    => $resource,
        ], 201);
    }
}
