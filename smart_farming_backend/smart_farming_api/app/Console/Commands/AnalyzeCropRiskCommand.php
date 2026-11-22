<?php

namespace App\Console\Commands;

use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;
use App\Services\CropRiskService;

#[Signature('crop:analyze-risk')]
#[Description('Menganalisis risiko gagal panen untuk semua tanaman berjalan')]
class AnalyzeCropRiskCommand extends Command
{
    public function handle(CropRiskService $service): int
    {
        $summary = $service->runAnalysis();

        $this->info(sprintf(
            'Analisis risiko selesai: %d tanaman dianalisis, %d berisiko, %d dilewati, %d gagal.',
            $summary['checked'],
            $summary['logged'],
            $summary['skipped'],
            $summary['failed'],
        ));

        return self::SUCCESS;
    }
}
