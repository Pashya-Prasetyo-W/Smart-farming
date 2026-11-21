<?php

namespace App\Models;

use App\Models\Concerns\BelongsToCompany;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ToolIncident extends Model
{
    use HasFactory, BelongsToCompany;

    public const KIND_HILANG = 'hilang';
    public const KIND_RUSAK = 'rusak';

    public const STATUS_TERBUKA = 'terbuka';
    public const STATUS_SELESAI = 'selesai';

    public const RESOLUTION_DIPERBAIKI = 'diperbaiki';
    public const RESOLUTION_DITEMUKAN = 'ditemukan';
    public const RESOLUTION_DIGANTI = 'diganti';
    public const RESOLUTION_DIHAPUSKAN = 'dihapuskan';

    protected function casts(): array
    {
        return [
            'resolution_cost' => 'decimal:2',
            'resolved_at'     => 'datetime',
        ];
    }

    public function tool()
    {
        return $this->belongsTo(Tool::class);
    }

    public function unit()
    {
        return $this->belongsTo(ToolUnit::class, 'tool_unit_id');
    }

    public function task()
    {
        return $this->belongsTo(Task::class);
    }

    public function reporter()
    {
        return $this->belongsTo(User::class, 'reported_by');
    }

    public function resolver()
    {
        return $this->belongsTo(User::class, 'resolved_by');
    }
}
