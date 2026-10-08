<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class Planting extends Model
{
    use HasFactory;

    protected $fillable = [
        'land_id',
        'crop_name',
        'plant_date',
        'est_harvest_date',
        'status'
    ];

    protected function casts(): array
    {
        return [
            'plant_date' => 'date',
            'est_harvest_date' => 'date',
            'total_cost' => 'decimal:2',
        ];
    }

    public function company()
    {
        return $this->belongsTo(Company::class);
    }

    public function land()
    {
        return $this->belongsTo(Land::class);
    }

    public function tasks()
    {
        return $this->hasMany(Task::class);
    }

    public function milestones()
    {
        return $this->morphMany(Milestone::class, 'milestoneable');
    }

    public function finances()
    {
        return $this->hasMany(Finance::class);
    }

    public function failureLogs()
    {
        return $this->hasMany(FailureLog::class);
    }
}
