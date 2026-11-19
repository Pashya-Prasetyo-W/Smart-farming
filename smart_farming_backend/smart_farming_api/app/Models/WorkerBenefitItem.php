<?php

namespace App\Models;

use App\Models\Concerns\BelongsToCompany;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class WorkerBenefitItem extends Model
{
    use HasFactory, BelongsToCompany;

    public const TYPE_KESEHATAN = 'kesehatan';
    public const TYPE_MAKAN = 'makan';

    public const TYPES = [self::TYPE_KESEHATAN, self::TYPE_MAKAN];

    protected $fillable = [
        'type',
        'name',
        'description',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function company()
    {
        return $this->belongsTo(Company::class);
    }
}
