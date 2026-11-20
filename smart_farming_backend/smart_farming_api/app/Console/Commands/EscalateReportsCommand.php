<?php

namespace App\Console\Commands;

use App\Services\ReportVerificationService;
use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;

#[Signature('reports:escalate')]
#[Description('Menaikkan verifikasi laporan kerja yang tertunda lebih dari 24 jam ke pemilik')]
class EscalateReportsCommand extends Command
{
    public function handle(ReportVerificationService $service): void
    {
        $count = $service->escalateOverdue();

        $this->info("{$count} laporan dinaikkan ke pemilik.");
    }
}
