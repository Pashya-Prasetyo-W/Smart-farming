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
}