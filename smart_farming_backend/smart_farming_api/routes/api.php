<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\WorkerController;
use App\Http\Controllers\Api\LandController;
use App\Http\Controllers\Api\ToolController;
use App\Http\Controllers\Api\ResourceController;
use App\Http\Controllers\Api\PlantingController;
use Illuminate\Support\Facades\Route;

Route::prefix('auth')->group(function () {
    Route::post('/register', [AuthController::class, 'register']);
    Route::post('/login', [AuthController::class, 'login']);
});

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/auth/logout', [AuthController::class, 'logout']);
    Route::post('/workers', [WorkerController::class, 'store']);
    Route::apiResource('lands', LandController::class)->only(['index', 'store']);
    Route::apiResource('tools', ToolController::class)->only(['index', 'store']);
    Route::apiResource('resources', ResourceController::class)->only(['index', 'store']);
    Route::apiResource('plantings', PlantingController::class)->only(['index', 'store']);
});