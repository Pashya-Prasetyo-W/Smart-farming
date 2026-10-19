<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\WorkerService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class WorkerController extends Controller
{
    public function __construct(
        protected WorkerService $workerService
    ) {}

    public function store(Request $request): JsonResponse
    {
        abort_if(
            $request->user()->role !== 'pemilik',
            403,
            'Akses ditolak. Hanya pemilik yang dapat menambahkan buruh.'
        );

        $validatedData = $request->validate([
            'name'                     => ['required', 'string', 'max:255'],
            'email'                    => ['required', 'string', 'email', 'max:255', 'unique:users,email'],
            'password'                 => ['required', 'string', 'min:8'],
            
            'schedule'                 => ['nullable', 'array'],
            'schedule.start_time'      => ['nullable', 'date_format:H:i:s'],
            'schedule.end_time'        => ['nullable', 'date_format:H:i:s'],
            'schedule.work_days'       => ['nullable', 'array'],
            'schedule.work_days.*'     => ['string'],

            'benefit'                  => ['nullable', 'array'],
            'benefit.health_insurance' => ['nullable', 'numeric', 'min:0'],
            'benefit.food_allowance'   => ['nullable', 'numeric', 'min:0'],
        ]);

        $worker = $this->workerService->createWorker($validatedData, $request->user());

        return response()->json([
            'message' => 'Data buruh berhasil ditambahkan.',
            'data'    => $worker,
        ], 201);
    }
}