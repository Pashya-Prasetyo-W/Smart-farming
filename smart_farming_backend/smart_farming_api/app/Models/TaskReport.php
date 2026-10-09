<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class TaskReport extends Model
{
    use HasFactory;

    protected $fillable = [
        'type',
        'media_urls',
        'notes',
        'reported_at'
    ];

    protected function casts(): array
    {
        return [
            'media_urls' => 'array',
            'reported_at' => 'datetime:Y-m-d H:i:s'
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
}
