<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Casts\Attribute;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class TaskTool extends Model
{
    use HasFactory;

    protected $table = 'task_tools';

    protected $fillable = [
        'tool_id',
        'qty',
        'lost_qty',
    ];

    protected function casts(): array
    {
        return [
            'qty'      => 'integer',
            'lost_qty' => 'integer',
            'assigned_unit_ids' => 'array'
        ];
    }

    protected function returnedQty(): Attribute
    {
        return Attribute::make(
            get: fn () => max(0, $this->qty - ($this->lost_qty ?? 0))
        );
    }

    public function company()
    {
        return $this->belongsTo(Company::class);
    }

    public function task()
    {
        return $this->belongsTo(Task::class);
    }

    public function tool()
    {
        return $this->belongsTo(Tool::class);
    }
}
