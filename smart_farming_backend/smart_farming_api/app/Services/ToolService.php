<?php

namespace App\Services;

use App\Models\Tool;
use App\Models\User;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\DB;

class ToolService
{
    public function createTool(array $data, User $pemilik): Tool
    {
        return DB::transaction(function () use ($data, $pemilik) {
            $qty = $data['total_qty'] ?? 1;

            $tool = new Tool();
            $tool->forceFill([
                'company_id'    => $pemilik->company_id,
                'name'          => $data['name'],
                'unit_label'    => $data['unit_label'] ?? null,
                'total_qty'     => $qty,
                'available_qty' => $qty,
            ]);
            $tool->save();

            return $tool->load('units');
        });
    }

    public function getTools(User $pemilik): Collection
    {
        return Tool::where('company_id', $pemilik->company_id)
            ->withCount('units')
            ->latest()
            ->get();
    }

    public function updateTool(\App\Models\Tool $tool, array $data): \App\Models\Tool
    {
        return \Illuminate\Support\Facades\DB::transaction(function () use ($tool, $data) {
            $oldName = $tool->name;
            $newName = $data['name'];
            $newTotalQty = (int) $data['total_qty'];
            $currentCount = $tool->units()->count();

            if ($oldName !== $newName) {
                $units = $tool->units;
                foreach ($units as $unit) {
                    $parts = explode('-', $unit->unit_code);
                    $suffix = end($parts); 
                    
                    $newCode = $newName . '-' . $suffix;
                    
                    $unit->forceFill(['unit_code' => $newCode])->save();
                }
            }

            if ($newTotalQty > $currentCount) {
                $diff = $newTotalQty - $currentCount;
                for ($i = 1; $i <= $diff; $i++) {
                    $suffix = $currentCount + $i;
                    $unitCode = $newName . '-' . str_pad($suffix, 2, '0', STR_PAD_LEFT);

                    while ($tool->units()->where('unit_code', $unitCode)->exists()) {
                        $suffix++;
                        $unitCode = $newName . '-' . str_pad($suffix, 2, '0', STR_PAD_LEFT);
                    }

                    $tool->units()->forceCreate([
                        'company_id'   => $tool->company_id,
                        'unit_code'    => $unitCode,
                        'condition'    => 'baik',
                        'is_available' => true,
                    ]);
                }
            }
            elseif ($newTotalQty < $currentCount) {
                $qtyToDelete = $currentCount - $newTotalQty;
                $availableUnits = $tool->units()
                    ->where('is_available', true)
                    ->where('condition', 'baik')
                    ->orderByDesc('id')
                    ->limit($qtyToDelete)
                    ->get();

                if ($availableUnits->count() < $qtyToDelete) {
                    throw \Illuminate\Validation\ValidationException::withMessages([
                        'total_qty' => ['Tidak dapat mengurangi jumlah alat. Ada unit yang sedang dipinjam atau rusak.'],
                    ]);
                }

                $tool->units()->whereIn('id', $availableUnits->pluck('id'))->delete();
            }

            $tool->forceFill([
                'name'          => $newName,
                'unit_label'    => $data['unit_label'],
                'total_qty'     => $tool->units()->count(),
                'available_qty' => $tool->units()->where('is_available', true)->count(),
            ])->save();

            return $tool->load('units');
        });
    }
}