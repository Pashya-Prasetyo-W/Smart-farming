<?php

namespace App\Services;

use App\Models\Resource;
use App\Models\User;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\DB;

class ResourceService
{
    public function createResource(array $data, User $pemilik): Resource
    {
        return DB::transaction(function () use ($data, $pemilik) {
            $resource = new Resource();
            $resource->forceFill([
                'company_id' => $pemilik->company_id,
                'name'       => $data['name'],
                'unit'       => $data['unit'],
                'stock_qty'  => $data['stock_qty'] ?? 0,
                'unit_price' => $data['unit_price'] ?? 0,
            ]);
            
            $resource->save();

            return $resource;
        });
    }

    public function getResources(User $pemilik): Collection
    {
        return Resource::where('company_id', $pemilik->company_id)
            ->latest()
            ->get();
    }
}