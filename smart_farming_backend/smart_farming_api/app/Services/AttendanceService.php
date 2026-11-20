<?php

namespace App\Services;

use App\Enums\AttendanceStatus;
use App\Enums\UserRole;
use App\Models\Attendance;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Validation\ValidationException;

class AttendanceService
{
    public const ESCALATE_AFTER_HOURS = 24;
    public const MAX_OBJECTIONS = 2;
    public const MANDOR_BACKDATE_DAYS = 7;
    public const PEMILIK_BACKDATE_DAYS = 31;

    private const RELATIONS = ['user:id,name,role', 'reviewer:id,name', 'recorder:id,name'];

    private function businessNow(): Carbon
    {
        return now(config('app.business_timezone'));
    }

    private function reviewerRoleFor(User $subject): string
    {
        return $subject->role === UserRole::Mandor->value
            ? UserRole::Pemilik->value
            : UserRole::Mandor->value;
    }

    private function fail(string $field, string $message): never
    {
        throw ValidationException::withMessages([$field => [$message]]);
    }

    public function today(User $user): ?Attendance
    {
        return Attendance::with(self::RELATIONS)
            ->where('user_id', $user->id)
            ->whereDate('work_date', $this->businessNow()->toDateString())
            ->first();
    }

    public function checkIn(User $user): Attendance
    {
        $date = $this->businessNow()->toDateString();

        if (Attendance::where('user_id', $user->id)->whereDate('work_date', $date)->exists()) {
            $this->fail('attendance', 'Anda sudah absen masuk hari ini.');
        }

        $attendance = new Attendance();
        $attendance->forceFill([
            'company_id'           => $user->company_id,
            'user_id'              => $user->id,
            'work_date'            => $date,
            'check_in_at'          => now(),
            'source'               => 'mandiri',
            'status'               => AttendanceStatus::Menunggu->value,
            'reviewer_role'        => $this->reviewerRoleFor($user),
            'reviewer_assigned_at' => now(),
        ]);

        try {
            $attendance->save();
        } catch (UniqueConstraintViolationException) {
            $this->fail('attendance', 'Anda sudah absen masuk hari ini.');
        }

        return $attendance->load(self::RELATIONS);
    }

    public function checkOut(User $user): Attendance
    {
        $attendance = Attendance::where('user_id', $user->id)
            ->whereDate('work_date', $this->businessNow()->toDateString())
            ->first();

        if (! $attendance) {
            $this->fail('attendance', 'Anda belum absen masuk hari ini.');
        }

        if ($attendance->check_out_at !== null) {
            $this->fail('attendance', 'Anda sudah absen pulang hari ini.');
        }

        if ($attendance->status !== AttendanceStatus::Menunggu->value) {
            $this->fail('attendance', 'Absensi hari ini sudah diproses dan tidak dapat diubah.');
        }

        $attendance->forceFill(['check_out_at' => now()])->save();

        return $attendance->load(self::RELATIONS);
    }

    public function record(User $actor, array $data): Attendance
    {
        $target = User::where('company_id', $actor->company_id)->find($data['user_id']);

        $allowedRoles = $actor->role === UserRole::Pemilik->value
            ? [UserRole::Buruh->value, UserRole::Mandor->value]
            : [UserRole::Buruh->value];

        if (! $target || ! in_array($target->role, $allowedRoles, true) || ! $target->is_active) {
            $this->fail('user_id', 'Karyawan tidak valid untuk Anda catat absensinya.');
        }

        $timezone = config('app.business_timezone');
        $today = $this->businessNow()->startOfDay();
        $workDate = Carbon::parse($data['work_date'], $timezone)->startOfDay();
        $maxBack = $actor->role === UserRole::Pemilik->value
            ? self::PEMILIK_BACKDATE_DAYS
            : self::MANDOR_BACKDATE_DAYS;

        if ($workDate->gt($today)) {
            $this->fail('work_date', 'Tanggal absensi tidak boleh di masa depan.');
        }

        if ($workDate->lt($today->copy()->subDays($maxBack))) {
            $this->fail('work_date', "Absensi hanya dapat dicatat maksimal {$maxBack} hari ke belakang.");
        }

        $checkIn = Carbon::parse($workDate->toDateString() . ' ' . $data['check_in_time'], $timezone);
        $checkOut = ! empty($data['check_out_time'])
            ? Carbon::parse($workDate->toDateString() . ' ' . $data['check_out_time'], $timezone)
            : null;

        if ($checkOut && $checkOut->lte($checkIn)) {
            $this->fail('check_out_time', 'Jam pulang harus setelah jam masuk.');
        }

        if (Attendance::where('user_id', $target->id)->whereDate('work_date', $workDate->toDateString())->exists()) {
            $this->fail('work_date', 'Absensi karyawan ini pada tanggal tersebut sudah ada.');
        }

        $attendance = new Attendance();
        $attendance->forceFill([
            'company_id'           => $actor->company_id,
            'user_id'              => $target->id,
            'work_date'            => $workDate->toDateString(),
            'check_in_at'          => $checkIn->copy()->setTimezone(config('app.timezone')),
            'check_out_at'         => $checkOut?->copy()->setTimezone(config('app.timezone')),
            'source'               => 'dicatat',
            'recorded_by'          => $actor->id,
            'status'               => AttendanceStatus::Terverifikasi->value,
            'reviewer_role'        => $actor->role,
            'reviewer_assigned_at' => now(),
            'reviewed_by'          => $actor->id,
            'reviewed_role'        => $actor->role,
            'reviewed_at'          => now(),
        ])->save();

        return $attendance->load(self::RELATIONS);
    }

    public function escalateOverdue(): int
    {
        return Attendance::where('reviewer_role', UserRole::Mandor->value)
            ->whereIn('status', [AttendanceStatus::Menunggu->value, AttendanceStatus::Keberatan->value])
            ->where('reviewer_assigned_at', '<=', now()->subHours(self::ESCALATE_AFTER_HOURS))
            ->update([
                'reviewer_role'        => UserRole::Pemilik->value,
                'reviewer_assigned_at' => now(),
                'escalated_at'         => now(),
            ]);
    }

    public function reviewQueue(User $actor): Collection
    {
        $this->escalateOverdue();

        $query = Attendance::with(self::RELATIONS)
            ->whereIn('status', [AttendanceStatus::Menunggu->value, AttendanceStatus::Keberatan->value]);

        if ($actor->role === UserRole::Mandor->value) {
            $query->where('reviewer_role', UserRole::Mandor->value)
                ->whereHas('user', fn ($q) => $q->where('role', UserRole::Buruh->value));
        }

        return $query->orderBy('work_date')->orderBy('id')->get();
    }

    public function history(User $actor, array $filters): Collection
    {
        $this->escalateOverdue();

        $from = $filters['from'] ?? $this->businessNow()->subDays(30)->toDateString();
        $to = $filters['to'] ?? $this->businessNow()->toDateString();

        $query = Attendance::with(self::RELATIONS)
            ->whereDate('work_date', '>=', $from)
            ->whereDate('work_date', '<=', $to);

        if ($actor->role === UserRole::Mandor->value) {
            $query->whereHas('user', fn ($q) => $q->where('role', UserRole::Buruh->value));
        }

        if (! empty($filters['user_id'])) {
            $query->where('user_id', $filters['user_id']);
        }

        if (! empty($filters['status'])) {
            $query->where('status', $filters['status']);
        }

        return $query->orderByDesc('work_date')->orderByDesc('id')->limit(500)->get();
    }

    public function mine(User $user, array $filters): Collection
    {
        $from = $filters['from'] ?? $this->businessNow()->subDays(30)->toDateString();
        $to = $filters['to'] ?? $this->businessNow()->toDateString();

        return Attendance::with(self::RELATIONS)
            ->where('user_id', $user->id)
            ->whereDate('work_date', '>=', $from)
            ->whereDate('work_date', '<=', $to)
            ->orderByDesc('work_date')
            ->get();
    }

    private function ensureCanReview(User $actor, Attendance $attendance): void
    {
        $pending = [AttendanceStatus::Menunggu->value, AttendanceStatus::Keberatan->value];

        if (! in_array($attendance->status, $pending, true)) {
            $this->fail('attendance', 'Absensi ini sudah diproses.');
        }

        if ($actor->id === $attendance->user_id) {
            abort(403, 'Anda tidak dapat memverifikasi absensi Anda sendiri.');
        }

        if ($actor->role === UserRole::Pemilik->value) {
            return;
        }

        $subject = $attendance->user ?? User::find($attendance->user_id);

        if (
            $actor->role === UserRole::Mandor->value
            && $subject
            && $subject->role === UserRole::Buruh->value
            && $attendance->reviewer_role === UserRole::Mandor->value
        ) {
            return;
        }

        abort(403, 'Anda tidak berwenang memverifikasi absensi ini.');
    }

    public function verify(User $actor, Attendance $attendance): Attendance
    {
        $this->escalateOverdue();
        $attendance->refresh();

        $this->ensureCanReview($actor, $attendance);

        $workDate = Carbon::parse($attendance->work_date->toDateString(), config('app.business_timezone'));

        if ($attendance->check_out_at === null && $workDate->gte($this->businessNow()->startOfDay())) {
            $this->fail('attendance', 'Karyawan belum absen pulang, absensi belum dapat diverifikasi.');
        }

        $attendance->forceFill([
            'status'        => AttendanceStatus::Terverifikasi->value,
            'reviewed_by'   => $actor->id,
            'reviewed_role' => $actor->role,
            'reviewed_at'   => now(),
            'reject_reason' => null,
        ])->save();

        return $attendance->load(self::RELATIONS);
    }

    public function reject(User $actor, Attendance $attendance, string $reason): Attendance
    {
        $this->escalateOverdue();
        $attendance->refresh();

        $this->ensureCanReview($actor, $attendance);

        $attendance->forceFill([
            'status'        => AttendanceStatus::Ditolak->value,
            'reviewed_by'   => $actor->id,
            'reviewed_role' => $actor->role,
            'reviewed_at'   => now(),
            'reject_reason' => $reason,
            'is_final'      => $actor->role === UserRole::Pemilik->value && $attendance->objection_count >= 1,
        ])->save();

        return $attendance->load(self::RELATIONS);
    }

    public function object(User $actor, Attendance $attendance, string $note): Attendance
    {
        if ($attendance->user_id !== $actor->id) {
            abort(403, 'Anda hanya dapat mengajukan keberatan atas absensi Anda sendiri.');
        }

        if ($attendance->status !== AttendanceStatus::Ditolak->value) {
            $this->fail('attendance', 'Keberatan hanya dapat diajukan untuk absensi yang ditolak.');
        }

        if ($attendance->is_final || $attendance->objection_count >= self::MAX_OBJECTIONS) {
            $this->fail('attendance', 'Keputusan atas absensi ini sudah final.');
        }

        $count = $attendance->objection_count + 1;

        $toMandor = $actor->role === UserRole::Buruh->value
            && $attendance->reviewed_role === UserRole::Mandor->value
            && $count === 1;

        $attendance->forceFill([
            'status'               => AttendanceStatus::Keberatan->value,
            'objection_note'       => $note,
            'objection_count'      => $count,
            'reviewer_role'        => $toMandor ? UserRole::Mandor->value : UserRole::Pemilik->value,
            'reviewer_assigned_at' => now(),
        ])->save();

        return $attendance->load(self::RELATIONS);
    }
}
