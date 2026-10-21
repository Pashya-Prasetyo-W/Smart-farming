<?php

namespace App\Services;

use App\Enums\TaskStatus;
use App\Models\Task;
use App\Models\User;
use App\Models\Tool;
use App\Models\ToolUnit;
use App\Models\TaskTool;
use Illuminate\Validation\ValidationException;
use Illuminate\Support\Facades\DB;

class TaskService
{
    public function createTask(array $data, User $pemilik): Task
    {
        return DB::transaction(function () use ($data, $pemilik) {
            $task = new Task();
            $task->forceFill([
                'company_id'  => $pemilik->company_id,
                'planting_id' => $data['planting_id'],
                'assigned_to' => $data['assigned_to'] ?? null,
                'title'       => $data['title'],
                'description' => $data['description'] ?? null,
                'task_date'   => $data['task_date'],
                'due_date'    => $data['due_date'],
                'status'      => TaskStatus::Menunggu,
            ]);
            
            $task->save();

            if (!empty($data['resources'])) {
                foreach ($data['resources'] as $resourceData) {
                    $task->resources()->attach($resourceData['resource_id'], [
                        'company_id'        => $pemilik->company_id,
                        'max_allocated_qty' => $resourceData['max_allocated_qty'],
                        'actual_used_qty'   => 0,
                        'variance_qty'      => 0,
                        'is_over_allocated' => false,
                    ]);
                }
            }

            if (!empty($data['tools'])) {
                foreach ($data['tools'] as $toolData) {
                    $task->tools()->attach($toolData['tool_id'], [
                        'company_id' => $pemilik->company_id,
                        'qty'        => $toolData['qty'],
                        'lost_qty'   => 0,
                    ]);
                }
            }

            return $task->load(['planting', 'assignee', 'resources', 'tools']);
        });
    }

    public function startTask(Task $task, User $buruh): Task
    {
        if ($task->status !== TaskStatus::Menunggu) {
            throw ValidationException::withMessages([
                'status' => ['Tugas ini sudah dimulai, selesai, atau dibatalkan.'],
            ]);
        }

        return DB::transaction(function () use ($task) {
            $task->status = TaskStatus::Dikerjakan;
            $task->save();

            foreach ($task->tools as $tool) {
                $requestedQty = $tool->pivot->qty;

                $lockedTool = Tool::where('id', $tool->id)->lockForUpdate()->first();

                if ($lockedTool->available_qty < $requestedQty) {
                    throw ValidationException::withMessages([
                        'tools' => ["Stok tersedia untuk alat '{$lockedTool->name}' tidak mencukupi."],
                    ]);
                }

                $lockedTool->available_qty -= $requestedQty;
                $lockedTool->save();

                $units = ToolUnit::where('tool_id', $lockedTool->id)
                    ->where('is_available', true)
                    ->take($requestedQty)
                    ->lockForUpdate()
                    ->get();

                if ($units->count() < $requestedQty) {
                    throw ValidationException::withMessages([
                        'tools' => ["Unit fisik alat '{$lockedTool->name}' yang siap pakai tidak mencukupi."],
                    ]);
                }

                $unitIds = [];
                foreach ($units as $unit) {
                    $unit->is_available = false;
                    $unit->save();
                    
                    $unitIds[] = $unit->id;
                }

                TaskTool::where('task_id', $task->id)
                    ->where('tool_id', $tool->id)
                    ->update(['assigned_unit_ids' => $unitIds]);
            }

            return $task->load(['planting', 'assignee', 'resources', 'tools']);
        });
    }
}