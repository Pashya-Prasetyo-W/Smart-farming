<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use App\Observers\ToolObserver;
use Illuminate\Database\Eloquent\Attributes\ObservedBy;

#[ObservedBy(ToolObserver::class)]
class Tool extends Model
{
    use HasFactory;

    protected $fillable = [
        'company_id',
        'name',
        'unit_label',
    ];

    protected function casts(): array
    {
        return [
            'total_qty' => 'integer',
            'available_qty' => 'integer',
        ];
    }

    public function company()
    {
        return $this->belongsTo(Company::class);
    }

    public function units()
    {
        return $this->hasMany(ToolUnit::class);
    }

    public function tasks()
    {
        return $this->belongsToMany(
            Task::class, 
            'task_tools', 
            'tool_id', 
            'task_id'
            )
        ->withPivot([
            'qty',
            'lost_qty'
            ])
        ->withTimestamps();
    }
}
