<?php

use App\Http\Controllers\Api\AnalyticsController;
use Illuminate\Support\Facades\Route;

Route::middleware(['auth:sanctum', 'active', 'role:pemilik'])->group(function () {
    Route::get('/analytics/profit', [AnalyticsController::class, 'profit']);
    Route::get('/analytics/risk', [AnalyticsController::class, 'risk']);
});
