<?php

namespace Tests\Feature\Concerns;

use App\Models\Company;
use App\Models\Land;
use App\Models\Planting;
use App\Models\Resource;
use App\Models\Tool;
use App\Models\User;

trait CreatesTenants
{
    protected function makeTenant(string $key): array
    {
        $owner = User::create([
            'name'     => "Pemilik {$key}",
            'email'    => "pemilik-{$key}@test.com",
            'password' => 'password123',
            'role'     => 'pemilik',
        ]);

        $company = Company::create([
            'owner_id' => $owner->id,
            'name'     => "Kebun {$key}",
        ]);

        $owner->update(['company_id' => $company->id]);

        $mandor = User::create([
            'name'       => "Mandor {$key}",
            'email'      => "mandor-{$key}@test.com",
            'password'   => 'password123',
            'role'       => 'mandor',
            'company_id' => $company->id,
        ]);

        $buruh = User::create([
            'name'       => "Buruh {$key}",
            'email'      => "buruh-{$key}@test.com",
            'password'   => 'password123',
            'role'       => 'buruh',
            'company_id' => $company->id,
        ]);

        $land = Land::create([
            'company_id'    => $company->id,
            'name'          => "Lahan {$key}",
            'area_sqm'      => 1000,
            'location_lat'  => -6.2,
            'location_long' => 106.8,
        ]);

        $planting = new Planting();
        $planting->forceFill([
            'company_id'       => $company->id,
            'land_id'          => $land->id,
            'crop_name'        => 'Cabai',
            'plant_date'       => now()->subDays(10)->toDateString(),
            'est_harvest_date' => now()->addDays(80)->toDateString(),
            'status'           => 'berjalan',
            'total_cost'       => 0,
        ])->save();

        $resource = new Resource();
        $resource->forceFill([
            'company_id' => $company->id,
            'name'       => "Pupuk {$key}",
            'unit'       => 'kg',
            'stock_qty'  => 100,
            'unit_price' => 10000,
        ])->save();

        $tool = new Tool();
        $tool->forceFill([
            'company_id'    => $company->id,
            'name'          => "Cangkul {$key}",
            'unit_label'    => 'buah',
            'total_qty'     => 2,
            'available_qty' => 2,
        ])->save();

        return compact('owner', 'mandor', 'buruh', 'company', 'land', 'planting', 'resource', 'tool');
    }

    protected function taskPayload(array $tenant, array $overrides = []): array
    {
        return array_merge([
            'planting_id' => $tenant['planting']->id,
            'assigned_to' => $tenant['buruh']->id,
            'title'       => 'Pemupukan',
            'task_date'   => now()->toDateString(),
            'due_date'    => now()->addDay()->toDateString(),
        ], $overrides);
    }
}
