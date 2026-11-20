<?php

namespace App\Models;

use App\Models\Concerns\BelongsToCompany;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Payroll extends Model
{
    use HasFactory, BelongsToCompany;

    public const STATUS_DRAF = 'draf';
    public const STATUS_DISETUJUI = 'disetujui';
    public const STATUS_DIBAYAR = 'dibayar';

    protected function casts(): array
    {
        return [
            'period_start' => 'date:Y-m-d',
            'period_end'   => 'date:Y-m-d',
            'total_amount' => 'decimal:2',
            'approved_at'  => 'datetime',
            'paid_at'      => 'datetime',
        ];
    }

    public function items()
    {
        return $this->hasMany(PayrollItem::class)->orderBy('id');
    }

    public function creator()
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function approver()
    {
        return $this->belongsTo(User::class, 'approved_by');
    }

    public function company()
    {
        return $this->belongsTo(Company::class);
    }
}
