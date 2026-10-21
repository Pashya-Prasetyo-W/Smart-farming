<?php

namespace App\Services;

use App\Models\IncidentReport;
use App\Models\User;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\DB;

class IncidentReportService
{
    public function createIncident(array $data, User $user): IncidentReport
    {
        return DB::transaction(function () use ($user, $data) {
            $incident = new IncidentReport();
            $incident->forceFill([
                'company_id'  => $user->company_id,
                'land_id'     => $data['land_id'],
                'reported_by' => $user->id,
                'type'        => $data['type'],
                'description' => $data['description'],
                'media_urls'  => $data['media_urls'] ?? [],
                'reported_at' => $data['reported_at'] ?? now(),
            ]);

            $incident->save();

            return $incident->load(['land', 'reporter', 'company']);
        });
    }

    public function getIncidents(User $user): Collection
    {
        return IncidentReport::where('company_id', $user->company_id)
            ->with(['land', 'reporter'])
            ->latest('reported_at')
            ->get();
    }
}