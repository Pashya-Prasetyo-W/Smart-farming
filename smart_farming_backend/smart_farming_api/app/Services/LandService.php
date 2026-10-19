<?php

namespace App\Services;

use App\Models\Land;
use App\Models\User;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\DB;

class LandService
{
    public function createLand(array $data, User $pemilik): Land
    {
        return DB::transaction(function () use ($data, $pemilik) {
            $land = new Land();
            $land->forceFill([
                'company_id'    => $pemilik->company_id,
                'name'          => $data['name'],
                'area_sqm'      => $data['area_sqm'],
                'location_lat'  => $data['location_lat'],
                'location_long' => $data['location_long'],
            ]);
            
            $land->save();

            return $land;
        });
    }

    public function getLands(User $pemilik): Collection
    {
        return Land::where('company_id', $pemilik->company_id)
            ->latest()
            ->get();
    }
}