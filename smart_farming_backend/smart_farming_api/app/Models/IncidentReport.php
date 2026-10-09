<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class IncidentReport extends Model
{
    use HasFactory;

    protected $fillable = [
        'land_id',
        'type',
        'description',
        'media_urls',
        'reported_at'
    ];

    protected function casts(): array
    {
        return [
            'media_urls' => 'array',
            'reported_at' => 'datetime:Y-m-d H:i:s'
        ];
    }

    public function company()
    {
        return $this->belongsTo(Company::class);
    }

    public function land()
    {
        return $this->belongsTo(Land::class);
    }

    public function reporter()
    {
        return $this->belongsTo(User::class, 'reported_by');
    }
}
