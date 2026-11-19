<?php

namespace App\Services;

use App\Enums\TaskStatus;
use App\Models\Finance;
use App\Models\Land;
use App\Models\Task;
use App\Models\User;
use Carbon\Carbon;

class DashboardService
{
    public function getOwnerStats(User $pemilik): array
    {
        $companyId = $pemilik->company_id;

        $totalIncome = Finance::where('company_id', $companyId)
            ->where('type', 'pemasukan')
            ->sum('amount');

        $totalExpense = Finance::where('company_id', $companyId)
            ->where('type', 'pengeluaran')
            ->sum('amount');

        $totalLands = Land::where('company_id', $companyId)->count();

        $activeTasks = Task::where('company_id', $companyId)
            ->whereIn('status', [TaskStatus::Menunggu, TaskStatus::Dikerjakan])
            ->count();

        return [
            'total_income'  => (float) $totalIncome,
            'total_expense' => (float) $totalExpense,
            'net_profit'    => (float) ($totalIncome - $totalExpense),
            'total_lands'   => $totalLands,
            'active_tasks'  => $activeTasks,
        ];
    }

    public function getMandorStats(User $mandor): array
    {
        $companyId = $mandor->company_id;

        $totalLands = Land::where('company_id', $companyId)->count();

        $activeTasks = Task::where('company_id', $companyId)
            ->whereIn('status', [TaskStatus::Menunggu, TaskStatus::Dikerjakan])
            ->count();

        $activeWorkers = User::where('company_id', $companyId)
            ->where('role', 'buruh')
            ->where('is_active', true)
            ->count();

        return [
            'total_lands'    => $totalLands,
            'active_tasks'   => $activeTasks,
            'active_workers' => $activeWorkers,
        ];
    }

    public function getWorkerStats(User $buruh): array
    {
        $today = Carbon::today();

        $todaysTasks = Task::where('assigned_to', $buruh->id)
            ->whereDate('task_date', $today)
            ->whereIn('status', [TaskStatus::Menunggu, TaskStatus::Dikerjakan])
            ->count();

        $completedThisMonth = Task::where('assigned_to', $buruh->id)
            ->where('status', TaskStatus::Selesai)
            ->whereMonth('updated_at', Carbon::now()->month)
            ->whereYear('updated_at', Carbon::now()->year)
            ->count();

        return [
            'todays_tasks_count'     => $todaysTasks,
            'completed_this_month'   => $completedThisMonth,
        ];
    }
}