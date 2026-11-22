<?php

use App\Http\Controllers\Api\HarvestController;
use Illuminate\Support\Facades\Route;

Route::middleware(['auth:sanctum', 'active', 'role:pemilik,mandor'])->group(function () {
    Route::get('/plantings/{planting}/harvests', [HarvestController::class, 'index']);
    Route::post('/plantings/{planting}/harvests', [HarvestController::class, 'store']);
    Route::delete('/harvests/{harvest}', [HarvestController::class, 'destroy']);
});

Route::middleware(['auth:sanctum', 'active', 'role:pemilik'])->group(function () {
    Route::get('/plantings/{planting}/summary', [HarvestController::class, 'summary']);
});
