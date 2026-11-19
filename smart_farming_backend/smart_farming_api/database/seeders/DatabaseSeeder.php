<?php

namespace Database\Seeders;

use App\Models\User;
use App\Models\Company;
use App\Models\Land;
use App\Models\Planting;
use App\Models\Tool;
use App\Models\Resource;
use App\Models\WorkerSchedule;
use App\Models\WorkerAllowance;
use App\Models\WorkerBenefitItem;
use App\Models\WorkerWage;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Carbon\Carbon;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        DB::transaction(function () {
            
            $owner = User::create([
                'name'     => 'Budi Pemilik',
                'email'    => 'budi@test.com',
                'password' => 'password123', 
                'role'     => 'pemilik',
            ]);

            $company = Company::create([
                'owner_id' => $owner->id,
                'name'     => 'Tani Makmur',
            ]);

            $owner->update(['company_id' => $company->id]);

            $mandor = User::create([
                'name'       => 'Slamet Mandor',
                'email'      => 'slamet@test.com',
                'password'   => 'password123',
                'role'       => 'mandor',
                'company_id' => $company->id,
            ]);

            WorkerSchedule::forceCreate([
                'company_id' => $company->id,
                'user_id'    => $mandor->id,
                'start_time' => '07:00:00',
                'end_time'   => '16:00:00',
                'work_days'  => ['senin', 'selasa', 'rabu', 'kamis', 'jumat', 'sabtu'],
            ]);

            WorkerBenefitItem::forceCreate([
                'company_id'  => $company->id,
                'user_id'     => $mandor->id,
                'type'        => 'kesehatan',
                'name'        => 'BPJS Ketenagakerjaan',
                'description' => null,
            ]);

            WorkerBenefitItem::forceCreate([
                'company_id'  => $company->id,
                'user_id'     => $mandor->id,
                'type'        => 'makan',
                'name'        => 'Uang makan',
                'description' => 'Rp 25.000 per hari',
            ]);

            WorkerWage::forceCreate([
                'company_id' => $company->id,
                'user_id'    => $mandor->id,
                'wage_type'  => 'bulanan',
                'amount'     => 4500000,
            ]);

            WorkerAllowance::forceCreate([
                'company_id' => $company->id,
                'user_id'    => $mandor->id,
                'name'       => 'Tunjangan transport',
                'amount'     => 300000,
            ]);

            $worker = User::create([
                'name'       => 'Andi Buruh',
                'email'      => 'andi@test.com',
                'password'   => 'password123',
                'role'       => 'buruh',
                'company_id' => $company->id,
            ]);

            WorkerSchedule::forceCreate([
                'company_id' => $company->id,
                'user_id'    => $worker->id,
                'start_time' => '08:00:00',
                'end_time'   => '16:00:00',
                'work_days'  => ['senin', 'selasa', 'rabu', 'kamis', 'jumat'],
            ]);

            WorkerWage::forceCreate([
                'company_id' => $company->id,
                'user_id'    => $worker->id,
                'wage_type'  => 'harian',
                'amount'     => 80000,
            ]);

            $land = Land::create([
                'company_id'    => $company->id,
                'name'          => 'Lahan Cabai A',
                'area_sqm'      => 1500.5,
                'location_lat'  => -6.200000,
                'location_long' => 106.816666,
            ]);

            Planting::create([
                'company_id'       => $company->id,
                'land_id'          => $land->id,
                'crop_name'        => 'Cabai Rawit',
                'plant_date'       => Carbon::now()->subDays(30), 
                'est_harvest_date' => Carbon::now()->addDays(60),  
                'status'           => 'berjalan',
                'total_cost'       => 0,
            ]);
            
            Tool::create([
                'company_id'    => $company->id,
                'name'          => 'Cangkul',
                'unit_label'    => 'buah',
                'total_qty'     => 3,
                'available_qty' => 3,
            ]);

            Resource::create([
                'company_id' => $company->id,
                'name'       => 'Pupuk NPK',
                'unit'       => 'kg',
                'stock_qty'  => 50.0,
                'unit_price' => 12000.0,
            ]);
        });
    }
}