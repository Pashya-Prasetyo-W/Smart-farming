<?php

namespace App\Services;

use App\Enums\TaskStatus;
use App\Models\Finance;
use App\Models\Planting;
use App\Models\Resource;
use App\Models\Task;
use App\Models\TaskReport;
use App\Models\Tool;
use App\Models\ToolUnit;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class ReportService
{
    public function submitReport(Task $task, array $data): TaskReport
    {
        if ($task->status !== TaskStatus::Dikerjakan) {
            throw ValidationException::withMessages([
                'status' => ['Tugas harus berstatus sedang dikerjakan untuk dapat dilaporkan.'],
            ]);
        }

        return DB::transaction(function () use ($task, $data) {
            $report = new TaskReport();
            $report->forceFill([
                'company_id'  => $task->company_id,
                'task_id'     => $task->id,
                'type'        => 'selesai',
                'media_urls'  => $data['media_urls'] ?? [],
                'notes'       => $data['notes'] ?? null,
                'reported_at' => $data['reported_at'] ?? now(),
            ]);
            $report->save();

            $task->status = TaskStatus::Selesai;
            $task->save();

            $totalTaskCost = 0;

            if (!empty($data['resources'])) {
                foreach ($data['resources'] as $resInput) {
                    $resourceId    = $resInput['resource_id'];
                    $actualUsedQty = $resInput['actual_used_qty'];

                    $pivotData = $task->resources()->where('resource_id', $resourceId)->first()?->pivot;

                    if (!$pivotData) {
                        continue;
                    }

                    $maxAllocated = $pivotData->max_allocated_qty;
                    $variance     = $actualUsedQty - $maxAllocated;
                    $isOver       = $actualUsedQty > $maxAllocated;

                    $task->resources()->updateExistingPivot($resourceId, [
                        'actual_used_qty'   => $actualUsedQty,
                        'variance_qty'      => $variance,
                        'is_over_allocated' => $isOver,
                    ]);

                    $resource = Resource::where('id', $resourceId)->lockForUpdate()->first();
                    if ($resource) {
                        $resource->stock_qty = max(0, $resource->stock_qty - $actualUsedQty);
                        $resource->save();

                        $cost = $actualUsedQty * $resource->unit_price;
                        $totalTaskCost += $cost;

                        Finance::forceCreate([
                            'company_id'  => $task->company_id,
                            'planting_id' => $task->planting_id,
                            'type'        => 'pengeluaran',
                            'amount'      => $cost,
                            'description' => "Pengeluaran bahan {$resource->name} untuk tugas: {$task->title}",
                            'record_date' => now(),
                        ]);
                    }
                }
            }

            if ($totalTaskCost > 0) {
                $planting = Planting::where('id', $task->planting_id)->lockForUpdate()->first();
                if ($planting) {
                    $planting->total_cost += $totalTaskCost;
                    $planting->save();
                }
            }

            foreach ($task->tools as $tool) {
                $assignedUnitIds = $tool->pivot->assigned_unit_ids ?? [];
                $borrowedQty     = $tool->pivot->qty;

                if (!empty($assignedUnitIds)) {
                    ToolUnit::whereIn('id', $assignedUnitIds)->update([
                        'is_available' => true,
                    ]);
                }

                $lockedTool = Tool::where('id', $tool->id)->lockForUpdate()->first();
                if ($lockedTool) {
                    $lockedTool->available_qty += $borrowedQty;
                    $lockedTool->save();
                }
            }

            return $report->load(['task.planting', 'company']);
        });
    }
}