<?php

namespace App\Services;

use App\Models\Finance;
use App\Models\Planting;
use App\Models\User;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class FinanceService
{
    public function createFinance(array $data, User $pemilik): Finance
    {
        return DB::transaction(function () use ($data, $pemilik) {
            $finance = new Finance();
            $finance->forceFill([
                'company_id'  => $pemilik->company_id,
                'planting_id' => $data['planting_id'] ?? null,
                'type'        => $data['type'],
                'amount'      => $data['amount'],
                'description' => $data['description'],
                'record_date' => $data['record_date'] ?? now(),
            ]);

            $finance->save();

            return $finance->load(['planting', 'company']);
        });
    }

    public function calculateHPP(Planting $planting, float $harvestKg): float
    {
        if ($harvestKg <= 0) {
            throw ValidationException::withMessages([
                'harvest_kg' => ['Jumlah hasil panen (kg) harus lebih besar dari 0 untuk menghitung HPP.'],
            ]);
        }

        return (float) ($planting->total_cost / $harvestKg);
    }

    public function getFinances(User $pemilik, ?int $month = null, ?int $year = null): Collection
    {
        return Finance::where('company_id', $pemilik->company_id)
            ->with('planting')
            ->when($month, function ($query, $month) {
                return $query->whereMonth('record_date', $month);
            })
            ->when($year, function ($query, $year) {
                return $query->whereYear('record_date', $year);
            })
            ->latest('id')
            ->get();
    }
}