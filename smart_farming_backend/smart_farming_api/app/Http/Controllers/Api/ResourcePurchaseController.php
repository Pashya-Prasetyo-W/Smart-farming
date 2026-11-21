<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ResourcePurchase;
use App\Services\ResourcePurchaseService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class ResourcePurchaseController extends Controller
{
    public function __construct(
        protected ResourcePurchaseService $purchaseService
    ) {}

    public function index(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'status' => ['nullable', Rule::in([
                ResourcePurchase::STATUS_MENUNGGU,
                ResourcePurchase::STATUS_DISETUJUI,
                ResourcePurchase::STATUS_DITOLAK,
                ResourcePurchase::STATUS_DIBATALKAN,
            ])],
        ]);

        return response()->json([
            'message'   => 'Daftar pembelian bahan berhasil diambil.',
            'data'      => $this->purchaseService->list($validated['status'] ?? null),
            'threshold' => $this->purchaseService->threshold(),
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'resource_id'  => ['required', Rule::exists('resources', 'id')->where('company_id', $request->user()->company_id)],
            'qty'          => ['required', 'numeric', 'min:0.01', 'max:100000000'],
            'unit_price'   => ['required', 'numeric', 'min:0', 'max:99999999'],
            'supplier'     => ['nullable', 'string', 'max:255'],
            'notes'        => ['nullable', 'string', 'max:1000'],
            'purchased_at' => ['nullable', 'date_format:Y-m-d', 'before_or_equal:today'],
        ]);

        $purchase = $this->purchaseService->request($request->user(), $validated);

        $message = $purchase->status === ResourcePurchase::STATUS_MENUNGGU
            ? 'Pembelian diajukan dan menunggu persetujuan pemilik.'
            : 'Pembelian dicatat dan stok bertambah.';

        return response()->json(['message' => $message, 'data' => $purchase], 201);
    }

    public function approve(Request $request, ResourcePurchase $purchase): JsonResponse
    {
        return response()->json([
            'message' => 'Pembelian disetujui dan stok bertambah.',
            'data'    => $this->purchaseService->approve($request->user(), $purchase),
        ]);
    }

    public function reject(Request $request, ResourcePurchase $purchase): JsonResponse
    {
        $validated = $request->validate([
            'reason' => ['required', 'string', 'max:500'],
        ]);

        return response()->json([
            'message' => 'Pembelian ditolak.',
            'data'    => $this->purchaseService->reject($request->user(), $purchase, $validated['reason']),
        ]);
    }

    public function cancel(Request $request, ResourcePurchase $purchase): JsonResponse
    {
        return response()->json([
            'message' => 'Pengajuan pembelian dibatalkan.',
            'data'    => $this->purchaseService->cancel($request->user(), $purchase),
        ]);
    }
}
