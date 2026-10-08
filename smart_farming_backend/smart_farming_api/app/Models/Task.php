<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use App\Enums\TaskStatus;

class Task extends Model
{
    use HasFactory;

    protected $fillable = [
        'planting_id',
        'assigned_to',
        'title',
        'description',
        'task_date',
        'due_date',
        'status',
    ];

    protected function casts(): array
    {
        return [
            'task_date' => 'date',
            'due_date' => 'date',
            'status' => TaskStatus::class,
        ];
    }

    public function company()
    {
        return $this->belongsTo(Company::class);
    }

    public function planting()
    {
        return $this->belongsTo(Planting::class);
    }

    public function assignee()
    {
        return $this->belongsTo(User::class, 'assigned_to');
    }

    public function resources()
    {
        return $this->belongsToMany(Resource::class,
            'task_resources',
            'task_id',
            'resource_id')
        ->using(TaskResource::class)
        ->withPivot([
            'max_allocated_qty',
            'actual_used_qty',
            'variance_qty',
            'is_over_allocated'])
        ->withTimestamps();
    }

    public function tools()
    {
        return $this->belongsToMany(Tool::class,
            'task_tools',
            'task_id',
            'tool_id')
        ->using(TaskTool::class)
        ->withPivot([
            'qty',
            'lost_qty',])
            ->withTimestamps();
    }

    public function report()
    {
        return $this->hasOne(TaskReport::class);
    }
}
