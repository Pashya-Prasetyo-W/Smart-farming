<?php

namespace App\Services;

use App\Enums\ReviewStatus;
use App\Enums\TaskStatus;
use App\Enums\UserRole;
use App\Models\TaskReport;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class ReportVerificationService
{
    public const ESCALATE_AFTER_HOURS = 24;
    public const MAX_OBJECTIONS = 2;

    private const RELATIONS = [
        'task:id,title,planting_id,assigned_to,status,wage_amount,task_date',
        'task.assignee:id,name,role',
        'task.resources',
        'task.tools',
        'reviewer:id,name',
    ];

    private function fail(string $field, string $message): never
    {
        throw ValidationException::withMessages([$field => [$message]]);
    }

    private function pendingStatuses(): array
    {
        return [ReviewStatus::Menunggu->value, ReviewStatus::Keberatan->value];
    }

    private function onlyBuruhSubjects($query): void
    {
        $query->whereHas('task.assignee', fn ($q) => $q->where('role', UserRole::Buruh->value));
    }

    public function escalateOverdue(): int
    {
        return TaskReport::where('reviewer_role', UserRole::Mandor->value)
            ->whereIn('review_status', $this->pendingStatuses())
            ->where('reviewer_assigned_at', '<=', now()->subHours(self::ESCALATE_AFTER_HOURS))
            ->update([
                'reviewer_role'        => UserRole::Pemilik->value,
                'reviewer_assigned_at' => now(),
                'escalated_at'         => now(),
            ]);
    }

    public function queue(User $actor): Collection
    {
        $this->escalateOverdue();

        $query = TaskReport::with(self::RELATIONS)
            ->whereIn('review_status', $this->pendingStatuses());

        if ($actor->role === UserRole::Mandor->value) {
            $query->where('reviewer_role', UserRole::Mandor->value);
            $this->onlyBuruhSubjects($query);
        }

        return $query->orderBy('reported_at')->orderBy('id')->get();
    }

    public function history(User $actor, array $filters): Collection
    {
        $this->escalateOverdue();

        $query = TaskReport::with(self::RELATIONS);

        if ($actor->role === UserRole::Mandor->value) {
            $this->onlyBuruhSubjects($query);
        }

        if (! empty($filters['status'])) {
            $query->where('review_status', $filters['status']);
        }

        if (! empty($filters['user_id'])) {
            $query->whereHas('task', fn ($q) => $q->where('assigned_to', $filters['user_id']));
        }

        if (! empty($filters['from'])) {
            $query->where('reported_at', '>=', Carbon::parse($filters['from'], config('app.business_timezone'))->startOfDay()->setTimezone(config('app.timezone')));
        }

        if (! empty($filters['to'])) {
            $query->where('reported_at', '<=', Carbon::parse($filters['to'], config('app.business_timezone'))->endOfDay()->setTimezone(config('app.timezone')));
        }

        return $query->orderByDesc('reported_at')->orderByDesc('id')->limit(300)->get();
    }

    private function ensureCanReview(User $actor, TaskReport $report): void
    {
        if (! in_array($report->review_status, $this->pendingStatuses(), true)) {
            $this->fail('report', 'Laporan ini sudah diproses.');
        }

        $task = $report->task;

        if ((int) $task->assigned_to === (int) $actor->id) {
            abort(403, 'Anda tidak dapat memverifikasi laporan pekerjaan Anda sendiri.');
        }

        if ($actor->role === UserRole::Pemilik->value) {
            return;
        }

        $subject = $task->assignee;

        if (
            $actor->role === UserRole::Mandor->value
            && $subject
            && $subject->role === UserRole::Buruh->value
            && $report->reviewer_role === UserRole::Mandor->value
        ) {
            return;
        }

        abort(403, 'Anda tidak berwenang memverifikasi laporan ini.');
    }

    public function verify(User $actor, TaskReport $report): TaskReport
    {
        $this->escalateOverdue();
        $report->refresh();

        $this->ensureCanReview($actor, $report);

        return DB::transaction(function () use ($actor, $report) {
            $report->forceFill([
                'review_status' => ReviewStatus::Terverifikasi->value,
                'reviewed_by'   => $actor->id,
                'reviewed_role' => $actor->role,
                'reviewed_at'   => now(),
                'reject_reason' => null,
            ])->save();

            $report->task->forceFill(['status' => TaskStatus::Selesai])->save();

            return $report->load(self::RELATIONS);
        });
    }

    public function reject(User $actor, TaskReport $report, string $reason): TaskReport
    {
        $this->escalateOverdue();
        $report->refresh();

        $this->ensureCanReview($actor, $report);

        return DB::transaction(function () use ($actor, $report, $reason) {
            $report->forceFill([
                'review_status' => ReviewStatus::Ditolak->value,
                'reviewed_by'   => $actor->id,
                'reviewed_role' => $actor->role,
                'reviewed_at'   => now(),
                'reject_reason' => $reason,
                'is_final'      => $actor->role === UserRole::Pemilik->value && $report->objection_count >= 1,
            ])->save();

            $report->task->forceFill(['status' => TaskStatus::Ditolak])->save();

            return $report->load(self::RELATIONS);
        });
    }

    public function object(User $actor, TaskReport $report, string $note): TaskReport
    {
        $task = $report->task;

        if ((int) $task->assigned_to !== (int) $actor->id) {
            abort(403, 'Anda hanya dapat mengajukan keberatan atas laporan pekerjaan Anda sendiri.');
        }

        if ($report->review_status !== ReviewStatus::Ditolak->value) {
            $this->fail('report', 'Keberatan hanya dapat diajukan untuk laporan yang ditolak.');
        }

        if ($report->is_final || $report->objection_count >= self::MAX_OBJECTIONS) {
            $this->fail('report', 'Keputusan atas laporan ini sudah final.');
        }

        $count = $report->objection_count + 1;

        $toMandor = $actor->role === UserRole::Buruh->value
            && $report->reviewed_role === UserRole::Mandor->value
            && $count === 1;

        return DB::transaction(function () use ($report, $task, $note, $count, $toMandor) {
            $report->forceFill([
                'review_status'        => ReviewStatus::Keberatan->value,
                'objection_note'       => $note,
                'objection_count'      => $count,
                'reviewer_role'        => $toMandor ? UserRole::Mandor->value : UserRole::Pemilik->value,
                'reviewer_assigned_at' => now(),
            ])->save();

            $task->forceFill(['status' => TaskStatus::MenungguVerifikasi])->save();

            return $report->load(self::RELATIONS);
        });
    }
}
