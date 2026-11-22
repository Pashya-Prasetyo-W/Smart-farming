<?php

namespace App\Services;

use App\Enums\TaskStatus;
use App\Models\FailureLog;
use App\Models\Finance;
use App\Models\Harvest;
use App\Models\IncidentReport;
use App\Models\Planting;
use App\Models\Task;
use Carbon\Carbon;
use Illuminate\Support\Collection;

class AnalyticsService
{
    private const INCIDENT_WEIGHTS = [
        'hama'             => 15,
        'penyakit_tanaman' => 20,
        'kerusakan_lahan'  => 15,
        'cuaca_ekstrem'    => 15,
        'lainnya'          => 5,
    ];

    private const INCIDENT_LABELS = [
        'hama'             => 'Hama',
        'penyakit_tanaman' => 'Penyakit tanaman',
        'kerusakan_lahan'  => 'Kerusakan lahan',
        'cuaca_ekstrem'    => 'Cuaca ekstrem',
        'lainnya'          => 'Lainnya',
    ];

    private function today(): Carbon
    {
        return now(config('app.business_timezone'))->startOfDay();
    }

    public function profit(array $filters = []): array
    {
        $plantings = Planting::with('land:id,name,area_sqm')
            ->when($filters['land_id'] ?? null, fn ($query, $id) => $query->where('land_id', $id))
            ->when($filters['status'] ?? null, fn ($query, $status) => $query->where('status', $status))
            ->orderByDesc('plant_date')
            ->orderByDesc('id')
            ->get();

        $ids = $plantings->pluck('id');

        $money = Finance::whereIn('planting_id', $ids)
            ->selectRaw('planting_id, type, category, SUM(amount) as total')
            ->groupBy('planting_id', 'type', 'category')
            ->get()
            ->groupBy('planting_id');

        $harvests = Harvest::whereIn('planting_id', $ids)
            ->selectRaw('planting_id, SUM(quantity_kg) as kg, SUM(sold_kg) as sold')
            ->groupBy('planting_id')
            ->get()
            ->keyBy('planting_id');

        $today = $this->today();

        $cycles = $plantings->map(function (Planting $planting) use ($money, $harvests, $today) {
            $rows = $money->get($planting->id, collect());

            $income = round((float) $rows->where('type', 'pemasukan')->sum('total'), 2);
            $costRows = $rows->where('type', 'pengeluaran');
            $cost = round((float) $costRows->sum('total'), 2);
            $profit = round($income - $cost, 2);
            $kg = round((float) ($harvests->get($planting->id)?->kg ?? 0), 2);
            $end = $planting->closed_at
                ? Carbon::parse($planting->closed_at->toDateString(), config('app.business_timezone'))
                : $today;

            return [
                'planting_id'    => $planting->id,
                'crop_name'      => $planting->crop_name,
                'status'         => $planting->status,
                'land_id'        => $planting->land_id,
                'land_name'      => $planting->land?->name,
                'plant_date'     => $planting->plant_date->toDateString(),
                'closed_at'      => $planting->closed_at?->toDateString(),
                'duration_days'  => max(0, (int) Carbon::parse($planting->plant_date->toDateString(), config('app.business_timezone'))->diffInDays($end)),
                'income'         => $income,
                'cost'           => $cost,
                'cost_breakdown' => $costRows
                    ->groupBy('category')
                    ->map(fn (Collection $group, string $category) => [
                        'category' => $category,
                        'amount'   => round((float) $group->sum('total'), 2),
                    ])
                    ->values()
                    ->all(),
                'profit'         => $profit,
                'margin_percent' => $income > 0 ? round($profit / $income * 100, 1) : null,
                'harvested_kg'   => $kg,
                'hpp_per_kg'     => $kg > 0 ? round($cost / $kg, 2) : null,
            ];
        })->values();

        $lands = $plantings->groupBy('land_id')->map(function (Collection $group) use ($cycles) {
            $land = $group->first()->land;
            $mine = $cycles->whereIn('planting_id', $group->pluck('id'));
            $profit = round((float) $mine->sum('profit'), 2);
            $area = (float) ($land?->area_sqm ?? 0);

            return [
                'land_id'            => $group->first()->land_id,
                'land_name'          => $land?->name,
                'area_sqm'           => $area,
                'cycles'             => $mine->count(),
                'running'            => $mine->where('status', 'berjalan')->count(),
                'harvested'          => $mine->where('status', 'panen')->count(),
                'failed'             => $mine->where('status', 'gagal')->count(),
                'income'             => round((float) $mine->sum('income'), 2),
                'cost'               => round((float) $mine->sum('cost'), 2),
                'profit'             => $profit,
                'harvested_kg'       => round((float) $mine->sum('harvested_kg'), 2),
                'avg_profit_per_cycle' => $mine->count() > 0 ? round($profit / $mine->count(), 2) : null,
                'profit_per_ha'      => $area > 0 ? round($profit / ($area / 10000), 2) : null,
            ];
        })->sortByDesc('profit')->values();

        $income = round((float) $cycles->sum('income'), 2);
        $cost = round((float) $cycles->sum('cost'), 2);

        $unallocated = empty($filters['land_id'])
            ? round((float) Finance::whereNull('planting_id')->operatingExpense()->sum('amount'), 2)
            : null;

        return [
            'overall' => [
                'income'           => $income,
                'cycle_cost'       => $cost,
                'cycle_profit'     => round($income - $cost, 2),
                'unallocated_cost' => $unallocated,
                'net_profit'       => $unallocated === null ? null : round($income - $cost - $unallocated, 2),
            ],
            'lands'   => $lands->all(),
            'cycles'  => $cycles->all(),
        ];
    }

    public function risk(): array
    {
        $today = $this->today();
        $plantings = Planting::where('status', 'berjalan')->with('land:id,name')->get();

        if ($plantings->isEmpty()) {
            return [];
        }

        $plantingIds = $plantings->pluck('id');
        $landIds = $plantings->pluck('land_id')->unique();
        $since = now()->subDays(30);

        $overdue = Task::whereIn('planting_id', $plantingIds)
            ->whereIn('status', [TaskStatus::Menunggu->value, TaskStatus::Dikerjakan->value])
            ->where('due_date', '<', $today->toDateString())
            ->selectRaw('planting_id, COUNT(*) as total')
            ->groupBy('planting_id')
            ->pluck('total', 'planting_id');

        $incidents = IncidentReport::whereIn('land_id', $landIds)
            ->where('reported_at', '>=', $since)
            ->orderByDesc('reported_at')
            ->get()
            ->groupBy('land_id');

        $failedCycles = Planting::where('status', 'gagal')
            ->whereIn('land_id', $landIds)
            ->where('closed_at', '>=', $today->copy()->subDays(365)->toDateString())
            ->selectRaw('land_id, COUNT(*) as total')
            ->groupBy('land_id')
            ->pluck('total', 'land_id');

        $weather = FailureLog::whereIn('planting_id', $plantingIds)
            ->where('created_at', '>=', now()->subDays(2))
            ->latest('id')
            ->get()
            ->groupBy('planting_id')
            ->map(fn (Collection $logs) => $logs->first());

        return $plantings->map(function (Planting $planting) use ($today, $overdue, $incidents, $failedCycles, $weather) {
            $factors = [];

            $overdueCount = (int) ($overdue[$planting->id] ?? 0);
            if ($overdueCount > 0) {
                $factors[] = [
                    'key'    => 'tugas_terlambat',
                    'label'  => "{$overdueCount} tugas melewati tenggat",
                    'points' => min(30, $overdueCount * 10),
                ];
            }

            $landIncidents = $incidents->get($planting->land_id, collect());
            $byType = $landIncidents->groupBy('type')->map->count();

            if ($landIncidents->isNotEmpty()) {
                $points = $landIncidents->sum(fn ($incident) => self::INCIDENT_WEIGHTS[$incident->type] ?? 5);
                $detail = $byType
                    ->map(fn ($count, $type) => (self::INCIDENT_LABELS[$type] ?? $type) . " {$count}")
                    ->values()
                    ->implode(', ');

                $factors[] = [
                    'key'    => 'kejadian_lapangan',
                    'label'  => "{$landIncidents->count()} kejadian lapangan dalam 30 hari ({$detail})",
                    'points' => min(40, (int) $points),
                ];
            }

            $summary = $weather->get($planting->id)?->analyzed_data_json['weather_summary'] ?? null;
            if ($summary) {
                if (($summary['weather_main'] ?? '') === 'Rain') {
                    $factors[] = ['key' => 'hujan', 'label' => 'Prakiraan cuaca hujan', 'points' => 15];
                }
                if ((float) ($summary['temperature'] ?? 0) > 35) {
                    $factors[] = ['key' => 'suhu_ekstrem', 'label' => 'Suhu ekstrem di atas 35°C', 'points' => 15];
                }
            }

            $daysToHarvest = (int) $today->diffInDays(Carbon::parse($planting->est_harvest_date->toDateString(), config('app.business_timezone')), false);
            if ($daysToHarvest < -7) {
                $factors[] = [
                    'key'    => 'panen_terlambat',
                    'label'  => 'Melewati perkiraan panen lebih dari 7 hari',
                    'points' => 10,
                ];
            }

            $failed = (int) ($failedCycles[$planting->land_id] ?? 0);
            if ($failed > 0) {
                $factors[] = [
                    'key'    => 'riwayat_gagal',
                    'label'  => "Lahan ini gagal panen {$failed} kali dalam 12 bulan terakhir",
                    'points' => 10,
                ];
            }

            $score = min(100, (int) collect($factors)->sum('points'));

            return [
                'planting_id'     => $planting->id,
                'crop_name'       => $planting->crop_name,
                'land'            => ['id' => $planting->land_id, 'name' => $planting->land?->name],
                'score'           => $score,
                'level'           => $score >= 60 ? 'tinggi' : ($score >= 30 ? 'sedang' : 'rendah'),
                'factors'         => $factors,
                'overdue_tasks'   => $overdueCount,
                'days_to_harvest' => $daysToHarvest,
                'incidents'       => [
                    'total'   => $landIncidents->count(),
                    'by_type' => $byType->map(fn ($count, $type) => [
                        'type'  => $type,
                        'label' => self::INCIDENT_LABELS[$type] ?? $type,
                        'count' => $count,
                    ])->values()->all(),
                    'recent'  => $landIncidents->take(3)->map(fn ($incident) => [
                        'id'          => $incident->id,
                        'type'        => $incident->type,
                        'description' => mb_substr((string) $incident->description, 0, 120),
                        'reported_at' => $incident->reported_at?->toDateTimeString(),
                    ])->values()->all(),
                ],
            ];
        })->sortByDesc('score')->values()->all();
    }
}
