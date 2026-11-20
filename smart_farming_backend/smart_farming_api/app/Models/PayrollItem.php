<?php

namespace App\Models;

use App\Models\Concerns\BelongsToCompany;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class PayrollItem extends Model
{
    use HasFactory, BelongsToCompany;

    protected function casts(): array
    {
        return [
            'rate'             => 'decimal:2',
            'units'            => 'integer',
            'base_amount'      => 'decimal:2',
            'allowances_total' => 'decimal:2',
            'total_amount'     => 'decimal:2',
            'details'          => 'array',
        ];
    }

    public function payroll()
    {
        return $this->belongsTo(Payroll::class);
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
