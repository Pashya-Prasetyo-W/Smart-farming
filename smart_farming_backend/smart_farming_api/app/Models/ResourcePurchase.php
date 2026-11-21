<?php

namespace App\Models;

use App\Models\Concerns\BelongsToCompany;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ResourcePurchase extends Model
{
    use HasFactory, BelongsToCompany;

    public const STATUS_MENUNGGU = 'menunggu';
    public const STATUS_DISETUJUI = 'disetujui';
    public const STATUS_DITOLAK = 'ditolak';
    public const STATUS_DIBATALKAN = 'dibatalkan';

    protected function casts(): array
    {
        return [
            'qty'          => 'decimal:2',
            'unit_price'   => 'decimal:2',
            'total_cost'   => 'decimal:2',
            'purchased_at' => 'date:Y-m-d',
            'decided_at'   => 'datetime',
        ];
    }

    public function resource()
    {
        return $this->belongsTo(Resource::class);
    }

    public function requester()
    {
        return $this->belongsTo(User::class, 'requested_by');
    }

    public function decider()
    {
        return $this->belongsTo(User::class, 'decided_by');
    }

    public function finance()
    {
        return $this->hasOne(Finance::class);
    }
}
