<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use App\Models\Concerns\BelongsToCompany;

class Land extends Model
{
    use HasFactory, BelongsToCompany;

    protected $fillable = [
        'company_id',
        'name',
        'location_lat',
        'location_long',
        'area_sqm',
    ];

    public function company()
    {
        return $this->belongsTo(Company::class);
    }

    public function plantings()
    {
        return $this->hasMany(Planting::class);
    }

    public function activePlanting()
    {
        return $this->hasOne(Planting::class)->where('status', 'berjalan');
    }

    public function milestones()
    {
        return $this->morphMany(Milestone::class, 'milestoneable');
    }

    public function incidentReports()
    {
        return $this->hasMany(IncidentReport::class);
    }
        
}
