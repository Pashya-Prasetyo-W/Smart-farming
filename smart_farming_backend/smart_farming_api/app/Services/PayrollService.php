<?php

namespace App\Services;

use App\Enums\ReviewStatus;
use App\Enums\TaskStatus;
use App\Enums\UserRole;
use App\Models\Attendance;
use App\Models\Payroll;
use App\Models\PayrollItem;
use App\Models\TaskReport;
use App\Models\User;
use App\Models\WorkerWage;
use Carbon\Carbon;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class PayrollService
{
    private function fail(string $field, string $message): never
    {
        throw ValidationException::withMessages([$field => [$message]]);
    }

    private function zone(): string
    {
        return config('app.business_timezone');
    }

    private function endOfPeriod(Payroll $payroll): Carbon
    {
        return Carbon::parse($payroll->period_end->toDateString(), $this->zone())
            ->endOfDay()
            ->setTimezone(config('app.timezone'));
    }

    public function create(User $actor, array $data): Payroll
    {
        $start = Carbon::parse($data['period_start'], $this->zone())->startOfDay();
        $end = Carbon::parse($data['period_end'], $this->zone())->startOfDay();
        $today = now($this->zone())->startOfDay();

        if ($end->lt($start)) {
            $this->fail('period_end', 'Tanggal akhir tidak boleh sebelum tanggal awal.');
        }

        if ($start->format('Y-m') !== $end->format('Y-m')) {
            $this->fail('period_end', 'Periode harus berada dalam satu bulan kalender.');
        }

        if ($end->gt($today)) {
            $this->fail('period_end', 'Tanggal akhir periode tidak boleh di masa depan.');
        }

        $overlaps = Payroll::whereDate('period_start', '<=', $end->toDateString())
            ->whereDate('period_end', '>=', $start->toDateString())
            ->exists();

        if ($overlaps) {
            $this->fail('period_start', 'Periode ini bertabrakan dengan rekap upah yang sudah ada.');
        }

        return DB::transaction(function () use ($actor, $start, $end) {
            $payroll = new Payroll();
            $payroll->forceFill([
                'company_id'   => $actor->company_id,
                'period_start' => $start->toDateString(),
                'period_end'   => $end->toDateString(),
                'status'       => Payroll::STATUS_DRAF,
                'total_amount' => 0,
                'created_by'   => $actor->id,
            ])->save();

            $this->calculate($payroll);

            return $this->detail($payroll);
        });
    }

    public function calculate(Payroll $payroll): void
    {
        Attendance::where('payroll_id', $payroll->id)->update(['payroll_id' => null]);
        TaskReport::where('payroll_id', $payroll->id)->update(['payroll_id' => null]);
        PayrollItem::where('payroll_id', $payroll->id)->delete();

        $users = User::where('company_id', $payroll->company_id)
            ->whereIn('role', [UserRole::Buruh->value, UserRole::Mandor->value])
            ->with(['wage', 'allowances'])
            ->orderBy('role')
            ->orderBy('name')
            ->get();

        $total = 0;

        foreach ($users as $user) {
            $total += $this->buildItem($payroll, $user);
        }

        $payroll->forceFill(['total_amount' => round($total, 2)])->save();
    }

    private function eligibleAttendances(User $user, Payroll $payroll)
    {
        return Attendance::where('user_id', $user->id)
            ->where('status', ReviewStatus::Terverifikasi->value)
            ->whereNull('payroll_id')
            ->whereDate('work_date', '<=', $payroll->period_end->toDateString())
            ->orderBy('work_date')
            ->get(['id', 'work_date']);
    }

    private function eligibleReports(User $user, Payroll $payroll)
    {
        return TaskReport::with('task:id,title,wage_amount,assigned_to')
            ->whereNull('payroll_id')
            ->where('review_status', ReviewStatus::Terverifikasi->value)
            ->where('reported_at', '<=', $this->endOfPeriod($payroll))
            ->whereHas('task', fn ($q) => $q
                ->where('assigned_to', $user->id)
                ->where('status', TaskStatus::Selesai->value)
                ->whereNotNull('wage_amount'))
            ->orderBy('reported_at')
            ->get();
    }

    private function monthlyAlreadyPaid(User $user, Payroll $payroll): bool
    {
        $monthStart = $payroll->period_end->copy()->startOfMonth()->toDateString();
        $monthEnd = $payroll->period_end->copy()->endOfMonth()->toDateString();

        return PayrollItem::where('user_id', $user->id)
            ->where('wage_type', WorkerWage::TYPE_BULANAN)
            ->where('payroll_id', '!=', $payroll->id)
            ->whereHas('payroll', fn ($q) => $q
                ->whereDate('period_end', '>=', $monthStart)
                ->whereDate('period_end', '<=', $monthEnd))
            ->exists();
    }

    private function store(Payroll $payroll, User $user, array $attributes): float
    {
        $item = new PayrollItem();
        $item->forceFill(array_merge([
            'company_id' => $payroll->company_id,
            'payroll_id' => $payroll->id,
            'user_id'    => $user->id,
        ], $attributes))->save();

        return (float) $attributes['total_amount'];
    }

    private function buildItem(Payroll $payroll, User $user): float
    {
        $wage = $user->wage;

        if (! $wage) {
            $attendances = $this->eligibleAttendances($user, $payroll);
            $reports = $this->eligibleReports($user, $payroll);

            if ($attendances->isEmpty() && $reports->isEmpty()) {
                return 0;
            }

            return $this->store($payroll, $user, [
                'wage_type'    => null,
                'rate'         => 0,
                'units'        => $attendances->count() + $reports->count(),
                'base_amount'  => 0,
                'total_amount' => 0,
                'note'         => 'Upah belum diatur, pekerjaan terverifikasi dibawa ke periode berikutnya.',
            ]);
        }

        $rate = (float) $wage->amount;

        if ($wage->wage_type === WorkerWage::TYPE_HARIAN) {
            $attendances = $this->eligibleAttendances($user, $payroll);

            if ($attendances->isEmpty()) {
                return 0;
            }

            $base = round($attendances->count() * $rate, 2);

            Attendance::whereIn('id', $attendances->pluck('id'))->update(['payroll_id' => $payroll->id]);

            return $this->store($payroll, $user, [
                'wage_type'    => $wage->wage_type,
                'rate'         => $rate,
                'units'        => $attendances->count(),
                'base_amount'  => $base,
                'total_amount' => $base,
                'details'      => [
                    'dates' => $attendances->map(fn ($a) => $a->work_date->toDateString())->values()->all(),
                ],
            ]);
        }

        if ($wage->wage_type === WorkerWage::TYPE_BORONGAN) {
            $reports = $this->eligibleReports($user, $payroll);

            if ($reports->isEmpty()) {
                return 0;
            }

            $tasks = $reports->map(fn ($r) => [
                'task_id' => $r->task->id,
                'title'   => $r->task->title,
                'amount'  => (float) $r->task->wage_amount,
            ])->values();

            $base = round($tasks->sum('amount'), 2);

            TaskReport::whereIn('id', $reports->pluck('id'))->update(['payroll_id' => $payroll->id]);

            return $this->store($payroll, $user, [
                'wage_type'    => $wage->wage_type,
                'rate'         => 0,
                'units'        => $tasks->count(),
                'base_amount'  => $base,
                'total_amount' => $base,
                'details'      => ['tasks' => $tasks->all()],
            ]);
        }

        if (! $user->is_active) {
            return 0;
        }

        if ($this->monthlyAlreadyPaid($user, $payroll)) {
            return $this->store($payroll, $user, [
                'wage_type'    => $wage->wage_type,
                'rate'         => $rate,
                'units'        => 0,
                'base_amount'  => 0,
                'total_amount' => 0,
                'note'         => 'Gaji bulanan bulan ini sudah dibayarkan pada rekap lain.',
            ]);
        }

        $allowances = $user->allowances->map(fn ($a) => [
            'name'   => $a->name,
            'amount' => (float) $a->amount,
        ])->values();

        $allowancesTotal = round($allowances->sum('amount'), 2);

        return $this->store($payroll, $user, [
            'wage_type'        => $wage->wage_type,
            'rate'             => $rate,
            'units'            => 1,
            'base_amount'      => $rate,
            'allowances_total' => $allowancesTotal,
            'total_amount'     => round($rate + $allowancesTotal, 2),
            'details'          => ['allowances' => $allowances->all()],
        ]);
    }

    public function recalculate(Payroll $payroll): Payroll
    {
        $this->ensureDraft($payroll);

        DB::transaction(fn () => $this->calculate($payroll));

        return $this->detail($payroll);
    }

    private function ensureDraft(Payroll $payroll): void
    {
        if ($payroll->status !== Payroll::STATUS_DRAF) {
            $this->fail('status', 'Hanya rekap berstatus draf yang dapat diubah.');
        }
    }

    public function approve(User $actor, Payroll $payroll): Payroll
    {
        $this->ensureDraft($payroll);

        if (! $payroll->items()->exists()) {
            $this->fail('status', 'Rekap upah kosong dan tidak dapat disetujui.');
        }

        $payroll->forceFill([
            'status'      => Payroll::STATUS_DISETUJUI,
            'approved_by' => $actor->id,
            'approved_at' => now(),
        ])->save();

        return $this->detail($payroll);
    }

    public function markPaid(Payroll $payroll): Payroll
    {
        if ($payroll->status !== Payroll::STATUS_DISETUJUI) {
            $this->fail('status', 'Hanya rekap yang sudah disetujui yang dapat ditandai dibayar.');
        }

        $payroll->forceFill([
            'status'  => Payroll::STATUS_DIBAYAR,
            'paid_at' => now(),
        ])->save();

        return $this->detail($payroll);
    }

    public function delete(Payroll $payroll): void
    {
        $this->ensureDraft($payroll);

        DB::transaction(function () use ($payroll) {
            Attendance::where('payroll_id', $payroll->id)->update(['payroll_id' => null]);
            TaskReport::where('payroll_id', $payroll->id)->update(['payroll_id' => null]);

            $payroll->delete();
        });
    }

    public function list(): Collection
    {
        return Payroll::withCount('items')
            ->orderByDesc('period_start')
            ->orderByDesc('id')
            ->get();
    }

    public function detail(Payroll $payroll): Payroll
    {
        $payroll->load(['items.user:id,name,role', 'creator:id,name', 'approver:id,name']);

        $end = $payroll->period_end->toDateString();
        $pending = [ReviewStatus::Menunggu->value, ReviewStatus::Keberatan->value];

        $payroll->setAttribute('warnings', [
            'pending_attendances' => Attendance::whereIn('status', $pending)
                ->whereDate('work_date', '<=', $end)
                ->count(),
            'pending_reports'     => TaskReport::whereIn('review_status', $pending)
                ->where('reported_at', '<=', $this->endOfPeriod($payroll))
                ->count(),
        ]);

        return $payroll;
    }

    public function mine(User $user): Collection
    {
        return PayrollItem::with('payroll:id,period_start,period_end,status,paid_at')
            ->where('user_id', $user->id)
            ->whereHas('payroll', fn ($q) => $q->whereIn('status', [
                Payroll::STATUS_DISETUJUI,
                Payroll::STATUS_DIBAYAR,
            ]))
            ->orderByDesc('id')
            ->get();
    }
}
