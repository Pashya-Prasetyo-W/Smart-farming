<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class CropRiskRun extends Model
{
    protected $fillable = ['ran_at', 'checked', 'logged', 'skipped', 'failed'];

    protected function casts(): array
    {
        return [
            'ran_at'  => 'datetime',
            'checked' => 'integer',
            'logged'  => 'integer',
            'skipped' => 'integer',
            'failed'  => 'integer',
        ];
    }
}
