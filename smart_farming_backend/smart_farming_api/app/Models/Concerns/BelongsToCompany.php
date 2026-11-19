<?php

namespace App\Models\Concerns;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\Auth;

trait BelongsToCompany
{
    protected static function bootBelongsToCompany(): void
    {
        static::addGlobalScope('company', function (Builder $builder) {
            $user = Auth::user();

            if ($user === null) {
                return;
            }

            $builder->where(
                $builder->getModel()->getTable() . '.company_id',
                $user->company_id ?? 0
            );
        });
    }
}
