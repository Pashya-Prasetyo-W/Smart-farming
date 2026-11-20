<?php

namespace App\Console\Commands;

use App\Services\AttendanceService;
use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;

#[Signature('attendances:escalate')]
#[Description('Menaikkan verifikasi absensi yang tertunda lebih dari 24 jam ke pemilik')]
class EscalateAttendancesCommand extends Command
{
    public function handle(AttendanceService $service): void
    {
        $count = $service->escalateOverdue();

        $this->info("{$count} absensi dinaikkan ke pemilik.");
    }
}
