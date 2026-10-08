<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class TaskResource extends Model
{
    use HasFactory;

    protected $table = 'task_resources';

    protected $fillable = [
        'resource_id',
        'max_allocated_qty',
        'actual_used_qty'
    ];

    protected function casts(): array
    {
        return [
            'max_allocated_qty' => 'decimal:2',
            'actual_used_qty' => 'decimal:2',
            'variance_qty' => 'decimal:2',
            'is_over_allocated' => 'boolean'
        ];
    }

    public function company()
    {
        return $this->belongsTo(Company::class);
    }

    public function task()
    {
        return $this->belongsTo(Task::class);
    }

    public function resource()
    {
        return $this->belongsTo(Resource::class);
    }
}
