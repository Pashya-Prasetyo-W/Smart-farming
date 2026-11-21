<?php

namespace App\Services;

use App\Enums\TaskStatus;
use App\Models\Task;
use App\Models\User;
use App\Models\Tool;
use App\Models\ToolUnit;
use App\Models\TaskTool;
use App\Models\Resource;
use Illuminate\Validation\ValidationException;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\DB;

class TaskService
{
    public function createTasks(array $data, array $assigneeIds, User $actor, array $boronganIds = []): Collection
    {
        $count = count($assigneeIds);

        return DB::transaction(function () use ($data, $assigneeIds, $actor, $boronganIds, $count) {
            $this->assertToolsForGroup($data['tools'] ?? [], $count, $actor->company_id);

            $shares = $this->splitResources($data['resources'] ?? [], $count);
            $tasks = new Collection();

            foreach (array_values($assigneeIds) as $index => $assigneeId) {
                $payload = array_merge($data, [
                    'assigned_to' => $assigneeId,
                    'resources'   => $shares[$index],
                    'wage_amount' => in_array($assigneeId, $boronganIds, true) ? ($data['wage_amount'] ?? null) : null,
                ]);

                $tasks->push($this->createTask($payload, $actor));
            }

            return $tasks;
        });
    }

    private function assertToolsForGroup(array $tools, int $count, int $companyId): void
    {
        if ($count < 2) {
            return;
        }

        foreach ($tools as $toolData) {
            $tool = Tool::where('company_id', $companyId)
                ->where('id', $toolData['tool_id'])
                ->lockForUpdate()
                ->firstOrFail();

            $needed = (int) $toolData['qty'] * $count;

            if ($needed > $tool->available_qty) {
                throw ValidationException::withMessages([
                    'tools' => ["Gagal! Alat {$tool->name} yang tersedia hanya {$tool->available_qty}, sedangkan {$count} karyawan membutuhkan {$needed}."],
                ]);
            }
        }
    }

    private function splitResources(array $resources, int $count): array
    {
        $shares = array_fill(0, $count, []);

        foreach ($resources as $resource) {
            $total = (float) $resource['max_allocated_qty'];
            $each = floor($total / $count * 100) / 100;
            $remainder = round($total - $each * ($count - 1), 2);

            for ($i = 0; $i < $count; $i++) {
                $shares[$i][] = [
                    'resource_id'       => $resource['resource_id'],
                    'max_allocated_qty' => $i === $count - 1 ? $remainder : $each,
                ];
            }
        }

        return $shares;
    }

    public function createTask(array $data, User $pemilik): Task
    {
        return DB::transaction(function () use ($data, $pemilik) {
            
            app(ResourceStockService::class)->assertAvailable($data['resources'] ?? [], $pemilik->company_id);

            if (!empty($data['tools'])) {
                foreach ($data['tools'] as $toolData) {
                    $tool = Tool::where('company_id', $pemilik->company_id)
                        ->where('id', $toolData['tool_id'])
                        ->lockForUpdate()
                        ->firstOrFail();

                    if ($toolData['qty'] > $tool->available_qty) {
                        throw ValidationException::withMessages([
                            'tools' => ["Gagal! Alat {$tool->name} yang tersedia hanya {$tool->available_qty}."]
                        ]);
                    }
                }
            }

            $task = new Task();
            $task->forceFill([
                'company_id'  => $pemilik->company_id,
                'planting_id' => $data['planting_id'],
                'assigned_to' => $data['assigned_to'] ?? null,
                'title'       => $data['title'],
                'description' => $data['description'] ?? null,
                'task_date'   => $data['task_date'],
                'due_date'    => $data['due_date'],
                'wage_amount' => $data['wage_amount'] ?? null,
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

        public function updateTask(Task $task, array $data): Task
    {
        if ($task->status !== TaskStatus::Menunggu) {
            throw ValidationException::withMessages([
                'status' => ['Gagal! Hanya tugas berstatus MENUNGGU yang dapat diedit.'],
            ]);
        }

        return DB::transaction(function () use ($task, $data) {
            app(ResourceStockService::class)->assertAvailable($data['resources'] ?? [], $task->company_id, $task->id);

            if (!empty($data['tools'])) {
                foreach ($data['tools'] as $toolData) {
                    $tool = \App\Models\Tool::where('id', $toolData['tool_id'])->lockForUpdate()->first();
                    if ($toolData['qty'] > $tool->available_qty) {
                        throw ValidationException::withMessages(['tools' => ["Alat {$tool->name} tidak mencukupi."]]);
                    }
                }
            }

            $task->update([
                'planting_id' => $data['planting_id'],
                'assigned_to' => $data['assigned_to'],
                'title'       => $data['title'],
                'description' => $data['description'] ?? null,
                'task_date'   => $data['task_date'],
                'due_date'    => $data['due_date'],
                'wage_amount' => $data['wage_amount'] ?? null,
            ]);

            $task->resources()->detach();
            if (!empty($data['resources'])) {
                foreach ($data['resources'] as $res) {
                    $task->resources()->attach($res['resource_id'], [
                        'company_id'        => $task->company_id,
                        'max_allocated_qty' => $res['max_allocated_qty'],
                        'actual_used_qty'   => 0,
                        'variance_qty'      => 0,
                        'is_over_allocated' => false,
                    ]);
                }
            }

            $task->tools()->detach();
            if (!empty($data['tools'])) {
                foreach ($data['tools'] as $toolData) {
                    $task->tools()->attach($toolData['tool_id'], [
                        'company_id' => $task->company_id,
                        'qty'        => $toolData['qty'],
                        'lost_qty'   => 0,
                    ]);
                }
            }

            return $task->load(['planting.land', 'assignee', 'resources', 'tools']);
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

    public function cancelTask(Task $task, User $pemilik, string $reason): Task
    {
        if (!in_array($task->status, [TaskStatus::Menunggu, TaskStatus::Dikerjakan])) {
            throw ValidationException::withMessages([
                'status' => ['Tugas dengan status ini tidak dapat dibatalkan.'],
            ]);
        }

        return DB::transaction(function () use ($task, $reason) {
            $previousStatus = $task->status;

            $task->status = TaskStatus::Batal;
            $task->cancel_reason = $reason;
            $task->cancelled_at = now();
            $task->save();

            if ($previousStatus === TaskStatus::Dikerjakan) {
                foreach ($task->tools as $tool) {
                    $taskTool = TaskTool::where('task_id', $task->id)
                        ->where('tool_id', $tool->id)
                        ->first();
                    $assignedUnitIds = $taskTool ? $taskTool->assigned_unit_ids : [];
                    $borrowedQty = $tool->pivot->qty;

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
            }

            return $task->load(['planting', 'assignee', 'resources', 'tools']);
        });
    }

    public function getTasks(User $user): \Illuminate\Database\Eloquent\Collection
    {
        $query = Task::with(['planting.land', 'assignee'])->latest();
        
        if ($user->hasRole('pemilik', 'mandor')) {
            return $query->where('company_id', $user->company_id)->get();
        }

        return $query->where('assigned_to', $user->id)->get();
    }
}