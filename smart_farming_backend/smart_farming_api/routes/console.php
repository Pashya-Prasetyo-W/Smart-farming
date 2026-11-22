<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

Schedule::command('crop:analyze-risk')
    ->dailyAt('00:00')
    ->timezone(config('app.business_timezone'))
    ->withoutOverlapping()
    ->appendOutputTo(storage_path('logs/crop-risk.log'));

Schedule::command('attendances:escalate')->hourly();
Schedule::command('reports:escalate')->hourly();
