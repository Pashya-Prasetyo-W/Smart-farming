<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class WorkerSchedule extends Model
{
    use HasFactory;

    protected $fillable = [
        'work_days',
        'start_time',
        'end_time',
        'break_start',
        'break_end',
    ];

    protected function casts(): array
    {
        return [
            'work_days' => 'array',
        ];
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function company()
    {
        return $this->belongsTo(Company::class);
    }
}
