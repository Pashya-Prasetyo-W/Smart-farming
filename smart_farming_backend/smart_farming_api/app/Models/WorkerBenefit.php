<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class WorkerBenefit extends Model
{
    use HasFactory;

    protected $fillable = [
        'health_insurance',
        'food_allowance'
    ];

    protected function casts(): array
    {
        return [
            'health_insurance' => 'boolean',
            'food_allowance' => 'boolean',
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
