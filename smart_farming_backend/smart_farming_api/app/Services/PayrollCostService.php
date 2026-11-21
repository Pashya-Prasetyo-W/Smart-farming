<?php

namespace App\Services;

use App\Enums\TaskStatus;
use App\Models\Finance;
use App\Models\Payroll;
use App\Models\PayrollItem;
use App\Models\Planting;
use App\Models\Task;
use App\Models\WorkerWage;
use Carbon\Carbon;

class PayrollCostService
{
    public function record(Payroll $payroll): void
    {
        $label = $payroll->period_start->format('d/m/Y') . ' - ' . $payroll->period_end->format('d/m/Y');

        $items = $payroll->items()
            ->where('total_amount', '>', 0)
            ->with('user:id,name')
            ->get();

        foreach ($items as $item) {
            foreach ($this->allocate($payroll, $item) as $plantingId => $amount) {
                if ($amount <= 0) {
                    continue;
                }

                Finance::forceCreate([
                    'company_id'  => $payroll->company_id,
                    'planting_id' => $plantingId ?: null,
                    'payroll_id'  => $payroll->id,
                    'type'        => 'pengeluaran',
                    'category'    => Finance::CATEGORY_UPAH,
                    'amount'      => $amount,
                    'description' => "Upah {$item->user->name} ({$label})",
                    'record_date' => $payroll->period_end->toDateString(),
                ]);
            }
        }
    }

    private function allocate(Payroll $payroll, PayrollItem $item): array
    {
        $total = round((float) $item->total_amount, 2);

        if ($item->wage_type === WorkerWage::TYPE_BORONGAN) {
            return $this->allocateTasks($item, $total);
        }

        return $this->split($total, $this->weights($payroll, $item));
    }

    private function allocateTasks(PayrollItem $item, float $total): array
    {
        $tasks = $item->details['tasks'] ?? [];

        if (empty($tasks)) {
            return [0 => $total];
        }

        $plantings = Task::whereIn('id', array_column($tasks, 'task_id'))->pluck('planting_id', 'id');

        $result = [];

        foreach ($tasks as $task) {
            $key = (int) ($plantings[$task['task_id']] ?? 0);
            $result[$key] = round(($result[$key] ?? 0) + (float) $task['amount'], 2);
        }

        return $result;
    }

    private function weights(Payroll $payroll, PayrollItem $item): array
    {
        $zone = config('app.business_timezone');
        $appZone = config('app.timezone');
        $start = Carbon::parse($payroll->period_start->toDateString(), $zone)->startOfDay()->setTimezone($appZone);
        $end = Carbon::parse($payroll->period_end->toDateString(), $zone)->endOfDay()->setTimezone($appZone);

        $byTasks = Task::where('assigned_to', $item->user_id)
            ->where('status', TaskStatus::Selesai->value)
            ->whereHas('report', fn ($q) => $q
                ->where('reported_at', '>=', $start)
                ->where('reported_at', '<=', $end))
            ->get(['id', 'planting_id'])
            ->groupBy('planting_id')
            ->map->count()
            ->all();

        if (! empty($byTasks)) {
            return $byTasks;
        }

        $running = Planting::whereDate('plant_date', '<=', $payroll->period_end->toDateString())
            ->where(fn ($q) => $q
                ->whereNull('closed_at')
                ->orWhereDate('closed_at', '>=', $payroll->period_start->toDateString()))
            ->pluck('id');

        if ($running->isNotEmpty()) {
            return $running->mapWithKeys(fn ($id) => [$id => 1])->all();
        }

        return [0 => 1];
    }

    private function split(float $total, array $weights): array
    {
        $sum = array_sum($weights);
        $result = [];
        $assigned = 0.0;
        $keys = array_keys($weights);
        $last = end($keys);

        foreach ($weights as $key => $weight) {
            if ($key === $last) {
                $result[$key] = round($total - $assigned, 2);
                continue;
            }

            $part = floor(($total * $weight / $sum) * 100) / 100;
            $result[$key] = $part;
            $assigned += $part;
        }

        return $result;
    }
}
