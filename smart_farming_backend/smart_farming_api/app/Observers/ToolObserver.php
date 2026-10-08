<?php

namespace App\Observers;

use App\Models\Tool;
use App\Models\ToolUnit;
use Illuminate\Support\Facades\DB;

class ToolObserver
{
    /**
     * Handle the Tool "created" event.
     */
    public function created(Tool $tool): void
    {
        DB::transaction(function () use ($tool) {
            for ($i = 1; $i <= $tool->total_qty; $i++) {
                $unit = new ToolUnit();
                $unit->company_id = $tool->company_id;
                $unit->tool_id = $tool->id;
                $unit->unit_code = $tool->name . '-' . str_pad((string) $i, 2, '0', STR_PAD_LEFT);
                $unit->condition = 'baik';
                $unit->is_available = true;
                $unit->save();
            }
        });
    }

}
