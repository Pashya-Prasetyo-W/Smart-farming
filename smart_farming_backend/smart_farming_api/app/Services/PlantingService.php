<?php

namespace App\Services;

use App\Models\Land;
use App\Models\Planting;
use App\Models\User;
use Exception;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class PlantingService
{
    public function createPlanting(array $data, User $pemilik): Planting
    {
        return DB::transaction(function () use ($data, $pemilik) {
            $land = Land::where('id', $data['land_id'])
                ->where('company_id', $pemilik->company_id)
                ->lockForUpdate()
                ->firstOrFail();

            $hasActivePlanting = Planting::where('land_id', $land->id)
                ->where('status', 'berjalan')
                ->exists();

            if ($hasActivePlanting) {
                throw ValidationException::withMessages([
                'land_id' => ['Gagal: Lahan ini masih memiliki siklus tanam yang sedang berjalan.'],
                ]);
            }

            $planting = new Planting();
            $planting->forceFill([
                'company_id'       => $pemilik->company_id,
                'land_id'          => $land->id,
                'crop_name'        => $data['crop_name'],
                'plant_date'       => $data['plant_date'],
                'est_harvest_date' => $data['est_harvest_date'],
                'status'           => 'berjalan',
                'total_cost'       => 0,
            ]);

            $planting->save();

            return $planting->load('land');
        });
    }

    public function getPlantings(User $pemilik): Collection
    {
        return Planting::where('company_id', $pemilik->company_id)
            ->with('land')
            ->latest()
            ->get();
    }
}