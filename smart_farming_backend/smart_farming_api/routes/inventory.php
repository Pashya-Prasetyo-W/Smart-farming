<?php

use App\Http\Controllers\Api\ResourcePurchaseController;
use App\Http\Controllers\Api\ToolIncidentController;
use Illuminate\Support\Facades\Route;

Route::middleware(['auth:sanctum', 'active', 'role:pemilik,mandor'])->group(function () {
    Route::get('/resource-purchases', [ResourcePurchaseController::class, 'index']);
    Route::post('/resource-purchases', [ResourcePurchaseController::class, 'store']);
    Route::post('/resource-purchases/{purchase}/cancel', [ResourcePurchaseController::class, 'cancel']);

    Route::get('/tool-incidents', [ToolIncidentController::class, 'index']);
    Route::post('/tool-incidents', [ToolIncidentController::class, 'store']);
});

Route::middleware(['auth:sanctum', 'active', 'role:pemilik'])->group(function () {
    Route::post('/resource-purchases/{purchase}/approve', [ResourcePurchaseController::class, 'approve']);
    Route::post('/resource-purchases/{purchase}/reject', [ResourcePurchaseController::class, 'reject']);
    Route::post('/tool-incidents/{incident}/resolve', [ToolIncidentController::class, 'resolve']);
});
