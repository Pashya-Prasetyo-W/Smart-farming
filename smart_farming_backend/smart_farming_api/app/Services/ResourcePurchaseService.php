<?php

namespace App\Services;

use App\Enums\UserRole;
use App\Models\Finance;
use App\Models\Resource;
use App\Models\ResourcePurchase;
use App\Models\User;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class ResourcePurchaseService
{
    private const RELATIONS = [
        'resource:id,name,unit',
        'requester:id,name,role',
        'decider:id,name',
    ];

    private function fail(string $field, string $message): never
    {
        throw ValidationException::withMessages([$field => [$message]]);
    }

    public function threshold(): float
    {
        return (float) config('inventory.purchase_approval_threshold');
    }

    public function list(?string $status = null): Collection
    {
        return ResourcePurchase::with(self::RELATIONS)
            ->when($status, fn ($query, $value) => $query->where('status', $value))
            ->orderByRaw("CASE WHEN status = 'menunggu' THEN 0 ELSE 1 END")
            ->latest('id')
            ->limit(200)
            ->get();
    }

    public function request(User $actor, array $data): ResourcePurchase
    {
        return DB::transaction(function () use ($actor, $data) {
            $resource = Resource::where('company_id', $actor->company_id)
                ->where('id', $data['resource_id'])
                ->lockForUpdate()
                ->firstOrFail();

            $qty = round((float) $data['qty'], 2);
            $price = round((float) $data['unit_price'], 2);
            $total = round($qty * $price, 2);

            if ($qty <= 0) {
                $this->fail('qty', 'Jumlah pembelian harus lebih besar dari 0.');
            }

            $needsApproval = $actor->role === UserRole::Mandor->value && $total >= $this->threshold();

            $purchase = new ResourcePurchase();
            $purchase->forceFill([
                'company_id'    => $actor->company_id,
                'resource_id'   => $resource->id,
                'resource_name' => $resource->name,
                'resource_unit' => $resource->unit,
                'qty'           => $qty,
                'unit_price'    => $price,
                'total_cost'    => $total,
                'supplier'      => $data['supplier'] ?? null,
                'notes'         => $data['notes'] ?? null,
                'purchased_at'  => $data['purchased_at'] ?? $this->today(),
                'status'        => $needsApproval ? ResourcePurchase::STATUS_MENUNGGU : ResourcePurchase::STATUS_DISETUJUI,
                'requested_by'  => $actor->id,
            ]);

            if (! $needsApproval) {
                $purchase->forceFill([
                    'decided_by' => $actor->role === UserRole::Pemilik->value ? $actor->id : null,
                    'decided_at' => now(),
                ]);
            }

            $purchase->save();

            if (! $needsApproval) {
                $this->apply($purchase, $resource);
            }

            return $purchase->load(self::RELATIONS);
        });
    }

    public function approve(User $pemilik, ResourcePurchase $purchase): ResourcePurchase
    {
        return DB::transaction(function () use ($pemilik, $purchase) {
            $purchase = ResourcePurchase::whereKey($purchase->id)->lockForUpdate()->firstOrFail();

            $this->ensurePending($purchase);

            $resource = $purchase->resource_id
                ? Resource::where('id', $purchase->resource_id)->lockForUpdate()->first()
                : null;

            if (! $resource) {
                $this->fail('purchase', 'Bahan untuk pembelian ini sudah tidak ada.');
            }

            $purchase->forceFill([
                'status'     => ResourcePurchase::STATUS_DISETUJUI,
                'decided_by' => $pemilik->id,
                'decided_at' => now(),
            ])->save();

            $this->apply($purchase, $resource);

            return $purchase->load(self::RELATIONS);
        });
    }

    public function reject(User $pemilik, ResourcePurchase $purchase, string $reason): ResourcePurchase
    {
        return DB::transaction(function () use ($pemilik, $purchase, $reason) {
            $purchase = ResourcePurchase::whereKey($purchase->id)->lockForUpdate()->firstOrFail();

            $this->ensurePending($purchase);

            $purchase->forceFill([
                'status'        => ResourcePurchase::STATUS_DITOLAK,
                'decided_by'    => $pemilik->id,
                'decided_at'    => now(),
                'reject_reason' => $reason,
            ])->save();

            return $purchase->load(self::RELATIONS);
        });
    }

    public function cancel(User $actor, ResourcePurchase $purchase): ResourcePurchase
    {
        if ((int) $purchase->requested_by !== (int) $actor->id) {
            abort(403, 'Anda hanya dapat membatalkan pengajuan pembelian Anda sendiri.');
        }

        return DB::transaction(function () use ($purchase) {
            $purchase = ResourcePurchase::whereKey($purchase->id)->lockForUpdate()->firstOrFail();

            $this->ensurePending($purchase);

            $purchase->forceFill([
                'status'     => ResourcePurchase::STATUS_DIBATALKAN,
                'decided_at' => now(),
            ])->save();

            return $purchase->load(self::RELATIONS);
        });
    }

    private function ensurePending(ResourcePurchase $purchase): void
    {
        if ($purchase->status !== ResourcePurchase::STATUS_MENUNGGU) {
            $this->fail('purchase', 'Pengajuan pembelian ini sudah diproses.');
        }
    }

    private function apply(ResourcePurchase $purchase, Resource $resource): void
    {
        $stock = (float) $resource->stock_qty;
        $qty = (float) $purchase->qty;
        $newStock = $stock + $qty;

        $newPrice = $newStock > 0
            ? round(($stock * (float) $resource->unit_price + $qty * (float) $purchase->unit_price) / $newStock, 2)
            : (float) $purchase->unit_price;

        $resource->forceFill([
            'stock_qty'  => $newStock,
            'unit_price' => $newPrice,
        ])->save();

        $description = "Pembelian {$purchase->resource_name} {$this->plain($qty)} {$purchase->resource_unit}";

        if ($purchase->supplier) {
            $description .= " dari {$purchase->supplier}";
        }

        Finance::forceCreate([
            'company_id'           => $purchase->company_id,
            'planting_id'          => null,
            'resource_purchase_id' => $purchase->id,
            'type'                 => 'pengeluaran',
            'category'             => Finance::CATEGORY_PEMBELIAN,
            'amount'               => $purchase->total_cost,
            'description'          => mb_substr($description, 0, 255),
            'record_date'          => $purchase->purchased_at->toDateString(),
        ]);
    }

    private function plain(float $value): string
    {
        return rtrim(rtrim(number_format($value, 2, '.', ''), '0'), '.');
    }

    private function today(): string
    {
        return now()->setTimezone(config('app.business_timezone'))->toDateString();
    }
}
