<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class Resource extends Model
{
    use HasFactory;

    protected $fillable = [
        'company_id',
        'name',
        'unit',
        'stock_qty',
        'unit_price',
    ];

    public function company()
    {
        return $this->belongsTo(Company::class);
    }

    public function taskResources()
    {
        return $this->hasMany(TaskResource::class);
    }

    public function tasks()
    {
        return $this->belongsToMany(
            Task::class, 
            'task_resources', 
            'resource_id', 
            'task_id'
            )
        ->withPivot([
            'max_allocated_qty',
            'actual_used_qty',
            'variance_qty',
            'is_over_allocated'
            ])
        ->withTimestamps();
    }
}
