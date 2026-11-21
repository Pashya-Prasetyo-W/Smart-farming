<?php

namespace App\Services;

use App\Enums\TaskStatus;
use App\Models\Finance;
use App\Models\Harvest;
use App\Models\Planting;
use App\Models\Task;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class HarvestService
{
    private function fail(string $field, string $message): never
    {
        throw ValidationException::withMessages([$field => [$message]]);
    }

    private function today(): Carbon
    {
        return now(config('app.business_timezone'))->startOfDay();
    }

    private function ensureRunning(Planting $planting): void
    {
        if ($planting->status !== 'berjalan') {
            $this->fail('planting', 'Siklus ini sudah selesai atau dibatalkan.');
        }
    }

    public function record(User $actor, Planting $planting, array $data): Harvest
    {
        $this->ensureRunning($planting);

        $quantity = (float) $data['quantity_kg'];
        $sold = (float) ($data['sold_kg'] ?? 0);
        $price = isset($data['price_per_kg']) ? (float) $data['price_per_kg'] : null;
        $date = isset($data['harvest_date'])
            ? Carbon::parse($data['harvest_date'], config('app.business_timezone'))->startOfDay()
            : $this->today();

        if ($sold > $quantity) {
            $this->fail('sold_kg', 'Jumlah terjual tidak boleh melebihi jumlah panen.');
        }

        if ($sold > 0 && ($price === null || $price <= 0)) {
            $this->fail('price_per_kg', 'Harga jual per kg wajib diisi jika ada hasil panen yang terjual.');
        }

        if ($date->gt($this->today())) {
            $this->fail('harvest_date', 'Tanggal panen tidak boleh di masa depan.');
        }

        if ($date->lt(Carbon::parse($planting->plant_date->toDateString(), config('app.business_timezone')))) {
            $this->fail('harvest_date', 'Tanggal panen tidak boleh sebelum tanggal tanam.');
        }

        return DB::transaction(function () use ($actor, $planting, $quantity, $sold, $price, $date) {
            $harvest = new Harvest();
            $harvest->forceFill([
                'company_id'   => $planting->company_id,
                'planting_id'  => $planting->id,
                'harvest_date' => $date->toDateString(),
                'quantity_kg'  => $quantity,
                'sold_kg'      => $sold,
                'price_per_kg' => $sold > 0 ? $price : null,
                'recorded_by'  => $actor->id,
            ])->save();

            if ($sold > 0) {
                Finance::forceCreate([
                    'company_id'  => $planting->company_id,
                    'planting_id' => $planting->id,
                    'harvest_id'  => $harvest->id,
                    'type'        => 'pemasukan',
                    'category'    => Finance::CATEGORY_PENJUALAN,
                    'amount'      => round($sold * $price, 2),
                    'description' => "Penjualan panen {$planting->crop_name} ({$sold} kg)",
                    'record_date' => $date->toDateString(),
                ]);
            }

            return $harvest;
        });
    }

    public function delete(Harvest $harvest): void
    {
        $planting = $harvest->planting;

        $this->ensureRunning($planting);

        DB::transaction(function () use ($harvest) {
            Finance::where('harvest_id', $harvest->id)->get()->each->delete();

            $harvest->delete();
        });
    }

    public function close(User $actor, Planting $planting, array $finalEntry = []): Planting
    {
        $this->ensureRunning($planting);

        $open = Task::where('planting_id', $planting->id)
            ->whereIn('status', [
                TaskStatus::Menunggu->value,
                TaskStatus::Dikerjakan->value,
                TaskStatus::MenungguVerifikasi->value,
            ])
            ->count();

        if ($open > 0) {
            $this->fail('planting', "Masih ada {$open} tugas yang belum selesai pada siklus ini. Selesaikan, verifikasi, atau batalkan terlebih dahulu.");
        }

        return DB::transaction(function () use ($actor, $planting, $finalEntry) {
            if (! empty($finalEntry['quantity_kg'])) {
                $this->record($actor, $planting, $finalEntry);
            }

            if (! Harvest::where('planting_id', $planting->id)->exists()) {
                $this->fail('harvest_kg', 'Catat minimal satu hasil panen sebelum menyelesaikan siklus.');
            }

            $planting->forceFill([
                'status'    => 'panen',
                'closed_at' => $this->today()->toDateString(),
            ])->save();

            return $planting;
        });
    }

    public function cancel(Planting $planting): Planting
    {
        $this->ensureRunning($planting);

        $planting->forceFill([
            'status'    => 'gagal',
            'closed_at' => $this->today()->toDateString(),
        ])->save();

        return $planting;
    }

    public function summary(Planting $planting): array
    {
        $planting->loadMissing('land:id,name');

        $costs = Finance::where('planting_id', $planting->id)
            ->where('type', 'pengeluaran')
            ->selectRaw('category, SUM(amount) as total')
            ->groupBy('category')
            ->pluck('total', 'category');

        $totalCost = round((float) $costs->sum(), 2);

        $income = round((float) Finance::where('planting_id', $planting->id)
            ->where('type', 'pemasukan')
            ->sum('amount'), 2);

        $harvests = Harvest::where('planting_id', $planting->id)
            ->orderByDesc('harvest_date')
            ->orderByDesc('id')
            ->get();

        $harvestedKg = round((float) $harvests->sum('quantity_kg'), 2);
        $soldKg = round((float) $harvests->sum('sold_kg'), 2);
        $salesRevenue = round((float) $harvests->sum(fn ($h) => (float) $h->sold_kg * (float) $h->price_per_kg), 2);

        return [
            'planting'       => [
                'id'               => $planting->id,
                'crop_name'        => $planting->crop_name,
                'status'           => $planting->status,
                'plant_date'       => $planting->plant_date->toDateString(),
                'est_harvest_date' => $planting->est_harvest_date->toDateString(),
                'closed_at'        => $planting->closed_at?->toDateString(),
                'land'             => $planting->land?->name,
            ],
            'costs'          => $costs->map(fn ($v, $k) => ['category' => $k, 'amount' => round((float) $v, 2)])->values()->all(),
            'total_cost'     => $totalCost,
            'income'         => $income,
            'profit'         => round($income - $totalCost, 2),
            'harvested_kg'   => $harvestedKg,
            'sold_kg'        => $soldKg,
            'avg_price_per_kg' => $soldKg > 0 ? round($salesRevenue / $soldKg, 2) : null,
            'hpp_per_kg'     => $harvestedKg > 0 ? round($totalCost / $harvestedKg, 2) : null,
            'harvests'       => $harvests,
        ];
    }
}
