<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class Finance extends Model
{
    use HasFactory;

    protected $fillable = [
        'planting_id',
        'type',
        'amount',
        'description',
        'record_date'
    ];

    protected function casts(): array
    {
        return [
            'amount' => 'decimal:2',
            'record_date' => 'date'
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
}
