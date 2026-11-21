<?php

namespace App\Models;

use App\Models\Concerns\BelongsToCompany;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Harvest extends Model
{
    use HasFactory, BelongsToCompany;

    protected function casts(): array
    {
        return [
            'harvest_date' => 'date:Y-m-d',
            'quantity_kg'  => 'decimal:2',
            'sold_kg'      => 'decimal:2',
            'price_per_kg' => 'decimal:2',
        ];
    }

    public function planting()
    {
        return $this->belongsTo(Planting::class);
    }

    public function recorder()
    {
        return $this->belongsTo(User::class, 'recorded_by');
    }

    public function income()
    {
        return $this->hasOne(Finance::class);
    }
}
