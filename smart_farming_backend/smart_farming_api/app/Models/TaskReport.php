<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use App\Models\Concerns\BelongsToCompany;

class TaskReport extends Model
{
    use HasFactory, BelongsToCompany;

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
            'reported_at' => 'datetime:Y-m-d H:i:s',
            'reviewer_assigned_at' => 'datetime',
            'reviewed_at' => 'datetime',
            'escalated_at' => 'datetime',
            'is_final' => 'boolean',
            'objection_count' => 'integer',
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

    public function reviewer()
    {
        return $this->belongsTo(User::class, 'reviewed_by');
    }
}
