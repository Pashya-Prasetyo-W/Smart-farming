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
    public function handle(CropRiskService $service): void
    {
        $service->runAnalysis();

        $this->info('Analisis risiko selesai dijalankan.');
    }
}
