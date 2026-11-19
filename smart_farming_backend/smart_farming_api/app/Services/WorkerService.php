<?php

namespace App\Services;

use App\Enums\UserRole;
use App\Models\User;
use App\Models\WorkerAllowance;
use App\Models\WorkerBenefitItem;
use App\Models\WorkerWage;
use Illuminate\Support\Facades\DB;

class WorkerService
{
    public function createWorker(array $data, User $creator): User
    {
        return DB::transaction(function () use ($data, $creator) {
            $worker = new User();
            $worker->forceFill([
                'name'                 => $data['name'],
                'email'                => $data['email'],
                'password'             => $data['password'],
                'role'                 => $data['role'] ?? UserRole::Buruh->value,
                'company_id'           => $creator->company_id,
                'is_active'            => true,
                'must_change_password' => true,
                'created_by'           => $creator->id,
            ]);
            $worker->save();

            $worker->schedule()->forceCreate([
                'company_id' => $creator->company_id,
                'start_time' => $data['schedule']['start_time'] ?? '08:00:00',
                'end_time'   => $data['schedule']['end_time'] ?? '16:00:00',
                'work_days'  => $data['schedule']['work_days'] ?? ['senin', 'selasa', 'rabu', 'kamis', 'jumat', 'sabtu', 'minggu'],
            ]);

            $this->syncBenefits($worker, $data['benefits'] ?? []);

            if ($creator->role === UserRole::Pemilik->value) {
                $this->syncWage($worker, $data['wage'] ?? null);
                $this->syncAllowances($worker, $data['allowances'] ?? null);
            }

            return $worker->load(['schedule', 'benefits']);
        });
    }

    public function syncWage(User $worker, ?array $wage): void
    {
        if (empty($wage)) {
            return;
        }

        $record = WorkerWage::firstOrNew(['user_id' => $worker->id]);
        $record->forceFill([
            'company_id' => $worker->company_id,
            'user_id'    => $worker->id,
            'wage_type'  => $wage['wage_type'],
            'amount'     => $wage['wage_type'] === WorkerWage::TYPE_BORONGAN ? 0 : $wage['amount'],
        ])->save();
    }

    public function syncAllowances(User $worker, ?array $items): void
    {
        if ($items === null) {
            return;
        }

        WorkerAllowance::where('user_id', $worker->id)->delete();

        if ($worker->role !== UserRole::Mandor->value) {
            return;
        }

        foreach ($items as $item) {
            $worker->allowances()->forceCreate([
                'company_id' => $worker->company_id,
                'name'       => $item['name'],
                'amount'     => $item['amount'],
            ]);
        }
    }

    public function syncBenefits(User $worker, array $items): void
    {
        WorkerBenefitItem::where('user_id', $worker->id)->delete();

        if ($worker->role !== UserRole::Mandor->value) {
            return;
        }

        foreach ($items as $item) {
            $worker->benefits()->forceCreate([
                'company_id'  => $worker->company_id,
                'type'        => $item['type'],
                'name'        => $item['name'],
                'description' => $item['description'] ?? null,
            ]);
        }
    }
}
