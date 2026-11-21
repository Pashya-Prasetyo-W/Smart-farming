<?php

namespace App\Services;

use App\Models\Finance;
use App\Models\Task;
use App\Models\TaskTool;
use App\Models\Tool;
use App\Models\ToolIncident;
use App\Models\ToolUnit;
use App\Models\User;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class ToolIncidentService
{
    private const RELATIONS = [
        'tool:id,name,unit_label',
        'unit:id,unit_code,condition',
        'task:id,title',
        'reporter:id,name,role',
        'resolver:id,name',
    ];

    private function fail(string $field, string $message): never
    {
        throw ValidationException::withMessages([$field => [$message]]);
    }

    public function list(?string $status = null): Collection
    {
        return ToolIncident::with(self::RELATIONS)
            ->when($status, fn ($query, $value) => $query->where('status', $value))
            ->orderByRaw("CASE WHEN status = 'terbuka' THEN 0 ELSE 1 END")
            ->latest('id')
            ->limit(200)
            ->get();
    }

    public function record(User $actor, array $data): Collection
    {
        return DB::transaction(function () use ($actor, $data) {
            $tool = Tool::where('company_id', $actor->company_id)
                ->where('id', $data['tool_id'])
                ->lockForUpdate()
                ->firstOrFail();

            $qty = (int) ($data['qty'] ?? 1);

            $units = ToolUnit::where('tool_id', $tool->id)
                ->where('is_available', true)
                ->where('condition', 'baik')
                ->orderBy('id')
                ->limit($qty)
                ->lockForUpdate()
                ->get();

            if ($units->count() < $qty) {
                $this->fail('qty', "Unit {$tool->name} yang tersedia dan kondisi baik hanya {$units->count()}.");
            }

            $incidents = [];

            foreach ($units as $unit) {
                $incidents[] = $this->open($tool, $unit, $data['kind'], $actor->id, null, $data['notes'] ?? null);
            }

            $tool->syncAvailability();

            return (new Collection($incidents))->each->load(self::RELATIONS);
        });
    }

    public function returnTools(Task $task, array $returns, ?int $reporterId, ?string $notes = null): void
    {
        $byTool = [];

        foreach ($returns as $row) {
            $byTool[(int) $row['tool_id']] = [
                'lost'    => (int) ($row['lost_qty'] ?? 0),
                'damaged' => (int) ($row['damaged_qty'] ?? 0),
            ];
        }

        foreach ($byTool as $toolId => $counts) {
            if (! $task->tools->contains('id', $toolId) && ($counts['lost'] + $counts['damaged']) > 0) {
                $this->fail('tools', 'Alat yang dilaporkan tidak termasuk dalam tugas ini.');
            }
        }

        foreach ($task->tools as $tool) {
            $counts = $byTool[$tool->id] ?? ['lost' => 0, 'damaged' => 0];
            $borrowed = (int) $tool->pivot->qty;

            if ($counts['lost'] + $counts['damaged'] > $borrowed) {
                $this->fail('tools', "Jumlah {$tool->name} yang hilang dan rusak melebihi jumlah yang dipinjam ({$borrowed}).");
            }

            $taskTool = TaskTool::where('task_id', $task->id)->where('tool_id', $tool->id)->first();
            $unitIds = $taskTool ? ($taskTool->assigned_unit_ids ?? []) : [];

            $lockedTool = Tool::where('id', $tool->id)->lockForUpdate()->first();

            $units = ToolUnit::whereIn('id', $unitIds)->orderBy('id')->lockForUpdate()->get()->values();

            $lostUnits = $units->slice(0, $counts['lost']);
            $damagedUnits = $units->slice($counts['lost'], $counts['damaged']);
            $okUnits = $units->slice($counts['lost'] + $counts['damaged']);

            if ($okUnits->isNotEmpty()) {
                ToolUnit::whereIn('id', $okUnits->pluck('id'))->update(['is_available' => true]);
            }

            foreach ($lostUnits as $unit) {
                $this->open($lockedTool, $unit, ToolIncident::KIND_HILANG, $reporterId, $task->id, $notes);
            }

            foreach ($damagedUnits as $unit) {
                $this->open($lockedTool, $unit, ToolIncident::KIND_RUSAK, $reporterId, $task->id, $notes);
            }

            TaskTool::where('task_id', $task->id)->where('tool_id', $tool->id)->update([
                'lost_qty'    => $counts['lost'],
                'damaged_qty' => $counts['damaged'],
            ]);

            if ($lockedTool) {
                if (empty($unitIds)) {
                    $lockedTool->available_qty += $borrowed;
                    $lockedTool->save();
                } else {
                    $lockedTool->syncAvailability();
                }
            }
        }
    }

    public function resolve(User $pemilik, ToolIncident $incident, array $data): ToolIncident
    {
        return DB::transaction(function () use ($pemilik, $incident, $data) {
            $incident = ToolIncident::whereKey($incident->id)->lockForUpdate()->firstOrFail();

            if ($incident->status !== ToolIncident::STATUS_TERBUKA) {
                $this->fail('incident', 'Kejadian ini sudah diselesaikan.');
            }

            $resolution = $data['resolution'];

            if ($resolution === ToolIncident::RESOLUTION_DIPERBAIKI && $incident->kind !== ToolIncident::KIND_RUSAK) {
                $this->fail('resolution', 'Hanya alat rusak yang dapat ditandai diperbaiki.');
            }

            if ($resolution === ToolIncident::RESOLUTION_DITEMUKAN && $incident->kind !== ToolIncident::KIND_HILANG) {
                $this->fail('resolution', 'Hanya alat hilang yang dapat ditandai ditemukan.');
            }

            $cost = $resolution === ToolIncident::RESOLUTION_DIHAPUSKAN
                ? 0.0
                : round((float) ($data['cost'] ?? 0), 2);

            $tool = Tool::where('id', $incident->tool_id)->lockForUpdate()->first();
            $unit = $incident->tool_unit_id
                ? ToolUnit::where('id', $incident->tool_unit_id)->lockForUpdate()->first()
                : null;

            if ($unit) {
                if ($resolution === ToolIncident::RESOLUTION_DIHAPUSKAN) {
                    $unit->delete();
                } else {
                    $unit->forceFill(['condition' => 'baik', 'is_available' => true])->save();
                }
            }

            $incident->forceFill([
                'status'           => ToolIncident::STATUS_SELESAI,
                'resolution'       => $resolution,
                'resolution_cost'  => $cost > 0 ? $cost : null,
                'resolution_notes' => $data['notes'] ?? null,
                'resolved_by'      => $pemilik->id,
                'resolved_at'      => now(),
            ])->save();

            if ($cost > 0) {
                $label = $resolution === ToolIncident::RESOLUTION_DIGANTI ? 'Penggantian' : 'Perbaikan';
                $code = $incident->unit_code ?: $tool?->name;

                Finance::forceCreate([
                    'company_id'       => $incident->company_id,
                    'planting_id'      => null,
                    'tool_incident_id' => $incident->id,
                    'type'             => 'pengeluaran',
                    'category'         => Finance::CATEGORY_PERAWATAN,
                    'amount'           => $cost,
                    'description'      => mb_substr("{$label} alat {$code}", 0, 255),
                    'record_date'      => now()->setTimezone(config('app.business_timezone'))->toDateString(),
                ]);
            }

            $tool?->syncAvailability();

            return $incident->load(self::RELATIONS);
        });
    }

    private function open(Tool $tool, ToolUnit $unit, string $kind, ?int $reporterId, ?int $taskId, ?string $notes): ToolIncident
    {
        $unit->forceFill([
            'condition'    => $kind === ToolIncident::KIND_HILANG ? 'hilang' : 'rusak',
            'is_available' => false,
        ])->save();

        $incident = new ToolIncident();
        $incident->forceFill([
            'company_id'   => $tool->company_id,
            'tool_id'      => $tool->id,
            'tool_unit_id' => $unit->id,
            'unit_code'    => $unit->unit_code,
            'task_id'      => $taskId,
            'kind'         => $kind,
            'status'       => ToolIncident::STATUS_TERBUKA,
            'notes'        => $notes,
            'reported_by'  => $reporterId,
        ])->save();

        return $incident;
    }
}
