<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\WorkerController;
use App\Http\Controllers\Api\LandController;
use App\Http\Controllers\Api\ToolController;
use App\Http\Controllers\Api\ResourceController;
use App\Http\Controllers\Api\PlantingController;
use App\Http\Controllers\Api\TaskController;
use App\Http\Controllers\Api\IncidentReportController;
use App\Http\Controllers\Api\FinanceController;
use App\Http\Controllers\Api\DashboardController;
use App\Http\Controllers\Api\ChatbotController;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\UserController;

Route::prefix('auth')->group(function () {
    Route::post('/register', [AuthController::class, 'register']);
    Route::post('/login', [AuthController::class, 'login']);
});

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/auth/logout', [AuthController::class, 'logout']);
    Route::post('/workers', [WorkerController::class, 'store']);
    Route::post('/tasks/{task}/start', [TaskController::class, 'start']);
    Route::post('/tasks/{task}/report', [TaskController::class, 'report']);
    Route::post('/tasks/{task}/cancel', [TaskController::class, 'cancel']);
    Route::post('/chatbot', [ChatbotController::class, 'ask']);
    Route::apiResource('lands', LandController::class)->only(['index', 'store']);
    Route::apiResource('tools', ToolController::class)->only(['index', 'store']);
    Route::apiResource('resources', ResourceController::class)->only(['index', 'store']);
    Route::apiResource('plantings', PlantingController::class)->only(['index', 'store']);
    Route::apiResource('tasks', TaskController::class)->only(['index', 'store', 'show']);
    Route::apiResource('incidents', IncidentReportController::class)->only(['index', 'store']);
    Route::apiResource('finances', FinanceController::class)->only(['index', 'store']);
    Route::apiResource('workers', WorkerController::class);
    Route::get('/plantings/{planting}/hpp', [FinanceController::class, 'calculateHPP']);
    Route::get('/dashboard/owner', [DashboardController::class, 'owner']);
    Route::get('/dashboard/worker', [DashboardController::class, 'worker']);
    Route::get('/user', [UserController::class, 'show']);
});