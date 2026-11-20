<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\WorkerController;
use App\Http\Controllers\Api\LandController;
use App\Http\Controllers\Api\MilestoneController;
use App\Http\Controllers\Api\ToolController;
use App\Http\Controllers\Api\ResourceController;
use App\Http\Controllers\Api\PlantingController;
use App\Http\Controllers\Api\TaskController;
use App\Http\Controllers\Api\TaskReportController;
use App\Http\Controllers\Api\IncidentReportController;
use App\Http\Controllers\Api\FinanceController;
use App\Http\Controllers\Api\DashboardController;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\UserController;
use App\Http\Controllers\Api\UploadController;
use App\Http\Controllers\Api\FailureLogController;
use App\Http\Controllers\Api\AttendanceController;



Route::prefix('auth')->group(function () {
    Route::post('/register', [AuthController::class, 'register']);
    Route::post('/login', [AuthController::class, 'login']);
    Route::post('/forgot-password', [AuthController::class, 'forgotPassword'])->middleware('throttle:5,1');
    Route::post('/reset-password', [AuthController::class, 'resetPassword'])->middleware('throttle:10,1');
});

Route::middleware(['auth:sanctum', 'active'])->group(function () {

    Route::post('/auth/logout', [AuthController::class, 'logout'])->name('auth.logout');
    Route::post('/auth/change-password', [AuthController::class, 'changePassword'])->name('auth.change-password');
    Route::get('/user', [UserController::class, 'show'])->name('user.show');
    Route::get('/worker/profile', [WorkerController::class, 'getProfile']);
    Route::post('/upload', [UploadController::class, 'upload']);
    Route::get('/dashboard/weather', [DashboardController::class, 'weather']);
    Route::get('/lands', [LandController::class, 'index']);
    Route::post('/incidents', [IncidentReportController::class, 'store']);
    Route::get('/tasks', [TaskController::class, 'index']);
    Route::get('/tasks/{task}', [TaskController::class, 'show']);

    Route::middleware('role:buruh,mandor')->group(function () {
        Route::post('/tasks/{task}/start', [TaskController::class, 'start']);
        Route::post('/tasks/{task}/report', [TaskController::class, 'report']);
        Route::get('/attendances/today', [AttendanceController::class, 'today']);
        Route::get('/attendances/mine', [AttendanceController::class, 'mine']);
        Route::post('/attendances/check-in', [AttendanceController::class, 'checkIn']);
        Route::post('/attendances/check-out', [AttendanceController::class, 'checkOut']);
        Route::post('/attendances/{attendance}/object', [AttendanceController::class, 'object']);
        Route::post('/task-reports/{report}/object', [TaskReportController::class, 'object']);
    });

    Route::middleware('role:buruh')->group(function () {
        Route::get('/dashboard/worker', [DashboardController::class, 'worker']);
    });

    Route::middleware('role:mandor')->group(function () {
        Route::get('/dashboard/mandor', [DashboardController::class, 'mandor']);
    });

    Route::middleware('role:pemilik,mandor')->group(function () {

        Route::get('/attendances', [AttendanceController::class, 'index']);
        Route::get('/attendances/queue', [AttendanceController::class, 'queue']);
        Route::post('/attendances', [AttendanceController::class, 'store']);
        Route::post('/attendances/{attendance}/verify', [AttendanceController::class, 'verify']);
        Route::post('/attendances/{attendance}/reject', [AttendanceController::class, 'reject']);

        Route::get('/task-reports', [TaskReportController::class, 'index']);
        Route::get('/task-reports/queue', [TaskReportController::class, 'queue']);
        Route::post('/task-reports/{report}/verify', [TaskReportController::class, 'verify']);
        Route::post('/task-reports/{report}/reject', [TaskReportController::class, 'reject']);

        Route::post('/tasks', [TaskController::class, 'store']);
        Route::put('/tasks/{task}', [TaskController::class, 'update']);
        Route::post('/tasks/{task}/cancel', [TaskController::class, 'cancel']);

        Route::get('/plantings', [PlantingController::class, 'index']);
        Route::post('/plantings', [PlantingController::class, 'store']);

        Route::apiResource('tools', ToolController::class)->only(['index', 'store', 'update', 'destroy']);
        Route::apiResource('resources', ResourceController::class)->only(['index', 'store', 'update', 'destroy']);

        Route::get('/lands/{land}/milestones', [MilestoneController::class, 'index']);
        Route::post('/lands/{land}/milestones', [MilestoneController::class, 'store']);
        Route::put('/milestones/{milestone}', [MilestoneController::class, 'update']);
        Route::put('/milestones/{milestone}/progress', [MilestoneController::class, 'updateProgress']);
        Route::delete('/milestones/{milestone}', [MilestoneController::class, 'destroy']);

        Route::get('/incidents', [IncidentReportController::class, 'index']);
        Route::get('/failure-logs', [FailureLogController::class, 'index']);

        Route::apiResource('workers', WorkerController::class)->only(['index', 'store', 'update', 'destroy']);
        Route::post('/workers/{worker}/deactivate', [WorkerController::class, 'deactivate']);
        Route::post('/workers/{worker}/activate', [WorkerController::class, 'activate']);
    });

    Route::middleware('role:pemilik')->group(function () {
        Route::post('/lands', [LandController::class, 'store']);
        Route::put('/lands/{land}', [LandController::class, 'update']);

        Route::post('/plantings/{planting}/harvest', [PlantingController::class, 'harvest']);
        Route::post('/plantings/{planting}/cancel', [PlantingController::class, 'cancelPlanting']);

        Route::get('/finances', [FinanceController::class, 'index']);
        Route::post('/finances', [FinanceController::class, 'store']);
        Route::get('/plantings/{planting}/hpp', [FinanceController::class, 'calculateHPP']);

        Route::get('/dashboard/owner', [DashboardController::class, 'owner']);
    });
});
