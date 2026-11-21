<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use App\Models\Concerns\BelongsToCompany;

class Finance extends Model
{
    use HasFactory, BelongsToCompany;

    protected $fillable = [
        'planting_id',
        'type',
        'amount',
        'description',
        'record_date'
    ];

    public const CATEGORY_BAHAN = 'bahan';
    public const CATEGORY_UPAH = 'upah';
    public const CATEGORY_PENJUALAN = 'penjualan';
    public const CATEGORY_LAINNYA = 'lainnya';

    protected static function booted(): void
    {
        static::saved(function (Finance $finance) {
            static::syncPlantingCost($finance->planting_id, $finance->getOriginal('planting_id'));
        });

        static::deleted(function (Finance $finance) {
            static::syncPlantingCost($finance->planting_id);
        });
    }

    protected static function syncPlantingCost(mixed ...$plantingIds): void
    {
        foreach (array_unique(array_filter($plantingIds)) as $plantingId) {
            $total = static::withoutGlobalScopes()
                ->where('planting_id', $plantingId)
                ->where('type', 'pengeluaran')
                ->sum('amount');

            Planting::withoutGlobalScopes()->whereKey($plantingId)->update(['total_cost' => $total]);
        }
    }

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

    public function harvest()
    {
        return $this->belongsTo(Harvest::class);
    }
}
