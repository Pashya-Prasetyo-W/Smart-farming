<?php

namespace App\Models;

use App\Models\Concerns\BelongsToCompany;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Attendance extends Model
{
    use HasFactory, BelongsToCompany;

    protected function casts(): array
    {
        return [
            'work_date'            => 'date:Y-m-d',
            'check_in_at'          => 'datetime',
            'check_out_at'         => 'datetime',
            'reviewer_assigned_at' => 'datetime',
            'reviewed_at'          => 'datetime',
            'escalated_at'         => 'datetime',
            'is_final'             => 'boolean',
            'objection_count'      => 'integer',
        ];
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function reviewer()
    {
        return $this->belongsTo(User::class, 'reviewed_by');
    }

    public function recorder()
    {
        return $this->belongsTo(User::class, 'recorded_by');
    }

    public function company()
    {
        return $this->belongsTo(Company::class);
    }
}
