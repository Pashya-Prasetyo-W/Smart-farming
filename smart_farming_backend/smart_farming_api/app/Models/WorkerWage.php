<?php

namespace App\Models;

use App\Enums\UserRole;
use App\Models\Concerns\BelongsToCompany;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class WorkerWage extends Model
{
    use HasFactory, BelongsToCompany;

    public const TYPE_HARIAN = 'harian';
    public const TYPE_BORONGAN = 'borongan';
    public const TYPE_BULANAN = 'bulanan';

    protected $fillable = [
        'wage_type',
        'amount',
    ];

    public static function typesFor(string $role): array
    {
        return $role === UserRole::Mandor->value
            ? [self::TYPE_BULANAN]
            : [self::TYPE_HARIAN, self::TYPE_BORONGAN];
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
