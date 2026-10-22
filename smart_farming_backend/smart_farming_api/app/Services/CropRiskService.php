<?php

namespace App\Services;

use App\Enums\TaskStatus;
use App\Models\FailureLog;
use App\Models\Planting;
use Carbon\Carbon;
use Illuminate\Support\Facades\Log;
use Exception;

class CropRiskService
{
    public function __construct(
        protected WeatherService $weatherService
    ) {}

    public function runAnalysis(): void
    {
        $plantings = Planting::where('status', 'berjalan')
            ->with(['land', 'tasks'])
            ->get();

        $today = Carbon::today();

        foreach ($plantings as $planting) {
            if (!$planting->land || !$planting->land->location_lat || !$planting->land->location_long) {
                continue;
            }

            $weatherData = null;

            try {
                $weatherData = $this->weatherService->getForecast(
                    (float) $planting->land->location_lat,
                    (float) $planting->land->location_long
                );
            } catch (Exception $e) {
                Log::error("Gagal mengambil data cuaca untuk Planting ID {$planting->id}: " . $e->getMessage());
                continue;
            }

            $overdueTasksCount = $planting->tasks->filter(function ($task) use ($today) {
                return in_array($task->status, [TaskStatus::Menunggu, TaskStatus::Dikerjakan])
                    && Carbon::parse($task->due_date)->lt($today);
            })->count();

            $score = 0;
            $reasons = [];

            if ($overdueTasksCount > 0) {
                $score += 50;
                $reasons[] = "Terdapat {$overdueTasksCount} tugas terlambat";
            }

            $firstForecast = $weatherData['list'][0] ?? null;
            $weatherMain   = $firstForecast['weather'][0]['main'] ?? '';
            $temperature   = $firstForecast['main']['temp'] ?? 0;

            if ($weatherMain === 'Rain') {
                $score += 30;
                $reasons[] = "Prakiraan cuaca hujan";
            }

            if ($temperature > 35) {
                $score += 20;
                $reasons[] = "Suhu ekstrem ({$temperature}°C)";
            }

            $score = min(100, $score);

            if ($score > 0) {
                $reasonString = implode(' dan ', $reasons);

                $failureLog = new FailureLog();

                $filteredForecast = [
                    'forecast_time' => $firstForecast['dt_txt'] ?? null,
                    'weather_main'  => $weatherMain,
                    'description'   => $firstForecast['weather'][0]['description'] ?? null,
                    'temperature'   => $temperature,
                    'humidity'      => $firstForecast['main']['humidity'] ?? null,
                ];

                $failureLog->forceFill([
                    'company_id'         => $planting->company_id,
                    'planting_id'        => $planting->id,
                    'source'             => 'cronjob',
                    'input_by'           => null,
                    'risk_score'         => $score,
                    'reason'             => $reasonString,
                    'analyzed_data_json' => [
                        'overdue_tasks_count' => $overdueTasksCount,
                        'weather_summary'     => $filteredForecast,
                    ],
                ]);
                $failureLog->save();

                if ($score > 70) {
                    Log::warning("Risiko gagal panen tinggi (Skor: {$score}) untuk Planting ID: {$planting->id}. Alasan: {$reasonString}");
                }
            }
        }
    }
}