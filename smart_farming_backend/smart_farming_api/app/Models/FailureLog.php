<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;


class FailureLog extends Model
{
    use HasFactory;

    protected $fillable = [
        'planting_id',
        'risk_score',
        'reason',
        'analyzed_data_json'
    ];

    protected function casts(): array
    {
        return [
            'analyzed_data_json' => 'array',
            'risk_score' => 'integer'
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

    public function inputBy()
    {
        return $this->belongsTo(User::class, 'input_by');
    }
}
