<?php

use App\Http\Controllers\Api\PayrollController;
use Illuminate\Support\Facades\Route;

Route::middleware(['auth:sanctum', 'active'])->group(function () {
    Route::get('/payrolls/mine', [PayrollController::class, 'mine'])->middleware('role:buruh,mandor');

    Route::middleware('role:pemilik')->group(function () {
        Route::get('/payrolls', [PayrollController::class, 'index']);
        Route::post('/payrolls', [PayrollController::class, 'store']);
        Route::get('/payrolls/{payroll}', [PayrollController::class, 'show']);
        Route::post('/payrolls/{payroll}/recalculate', [PayrollController::class, 'recalculate']);
        Route::post('/payrolls/{payroll}/approve', [PayrollController::class, 'approve']);
        Route::post('/payrolls/{payroll}/pay', [PayrollController::class, 'pay']);
        Route::delete('/payrolls/{payroll}', [PayrollController::class, 'destroy']);
    });
});
