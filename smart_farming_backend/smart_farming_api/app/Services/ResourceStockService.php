<?php

namespace App\Services;

use App\Enums\TaskStatus;
use App\Models\Resource;
use App\Models\TaskResource;
use Illuminate\Support\Collection;
use Illuminate\Validation\ValidationException;

class ResourceStockService
{
    public function reservedByResource(?int $excludeTaskId = null): Collection
    {
        return TaskResource::query()
            ->join('tasks', 'tasks.id', '=', 'task_resources.task_id')
            ->whereIn('tasks.status', [TaskStatus::Menunggu->value, TaskStatus::Dikerjakan->value])
            ->when($excludeTaskId, fn ($query, $id) => $query->where('task_resources.task_id', '!=', $id))
            ->selectRaw('task_resources.resource_id as resource_id, SUM(task_resources.max_allocated_qty) as reserved')
            ->groupBy('task_resources.resource_id')
            ->pluck('reserved', 'resource_id');
    }

    public function withAvailability(Collection $resources): Collection
    {
        $reserved = $this->reservedByResource();

        return $resources->each(function (Resource $resource) use ($reserved) {
            $held = (float) ($reserved[$resource->id] ?? 0);

            $resource->setAttribute('reserved_qty', $this->format($held));
            $resource->setAttribute('available_qty', $this->format(max(0, (float) $resource->stock_qty - $held)));
        });
    }

    public function assertAvailable(array $requests, int $companyId, ?int $excludeTaskId = null): void
    {
        $wanted = [];

        foreach ($requests as $request) {
            $id = (int) $request['resource_id'];
            $wanted[$id] = ($wanted[$id] ?? 0) + (float) $request['max_allocated_qty'];
        }

        if (empty($wanted)) {
            return;
        }

        $reserved = $this->reservedByResource($excludeTaskId);

        foreach ($wanted as $resourceId => $qty) {
            $resource = Resource::where('company_id', $companyId)
                ->where('id', $resourceId)
                ->lockForUpdate()
                ->firstOrFail();

            $held = (float) ($reserved[$resourceId] ?? 0);
            $available = max(0, (float) $resource->stock_qty - $held);

            if ($qty > $available + 0.00001) {
                throw ValidationException::withMessages([
                    'resources' => [
                        "Gagal! Stok {$resource->name} tidak mencukupi. Tersedia: {$this->format($available)} {$resource->unit} "
                        . "(stok {$this->format((float) $resource->stock_qty)}, sudah dialokasikan ke tugas lain {$this->format($held)})."
                    ],
                ]);
            }
        }
    }

    private function format(float $value): string
    {
        return number_format($value, 2, '.', '');
    }
}
