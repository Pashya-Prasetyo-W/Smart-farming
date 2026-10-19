<?php

namespace App\Services;

use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

class WorkerService
{
    public function createWorker(array $data, User $pemilik): User
    {
        return DB::transaction(function () use ($data, $pemilik) {
            $worker = User::create([
                'name'       => $data['name'],
                'email'      => $data['email'],
                'password'   => $data['password'],
                'role'       => 'buruh',
                'company_id' => $pemilik->company_id,
            ]);

            $worker->schedule()->forceCreate([
                'company_id' => $pemilik->company_id,
                'start_time' => $data['schedule']['start_time'] ?? '08:00:00',
                'end_time'   => $data['schedule']['end_time'] ?? '16:00:00',
                'work_days'  => $data['schedule']['work_days'] ?? ['senin', 'selasa', 'rabu', 'kamis', 'jumat', 'sabtu', 'minggu'],
            ]);

            $worker->benefit()->forceCreate([
                'company_id'      => $pemilik->company_id,
                'health_insurance' => $data['benefit']['health_insurance'] ?? 0,
                'food_allowance'  => $data['benefit']['food_allowance'] ?? 0,
            ]);

            return $worker->load(['schedule', 'benefit']);
        });
    }
}