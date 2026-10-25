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
            'name'                          => ['required', 'string', 'max:255'],
            'email'                         => ['required', 'string', 'email', 'max:255', 'unique:users,email'],
            'password'                      => ['required', 'string', 'min:8'],
            
            'schedule'                      => ['nullable', 'array'],
            'schedule.start_time'           => ['nullable', 'date_format:H:i:s'],
            'schedule.end_time'             => ['nullable', 'date_format:H:i:s'],
            'schedule.work_days'            => ['nullable', 'array'],
            'schedule.work_days.*'          => ['string'],

            'benefit'                       => ['nullable', 'array'],
            'benefit.health_insurance'      => ['nullable', 'numeric', 'min:0'],
            'benefit.health_insurance_desc' => ['nullable', 'string', 'max:255'],
            'benefit.food_allowance'        => ['nullable', 'numeric', 'min:0'],
            'benefit.food_allowance_desc'   => ['nullable', 'string', 'max:255'],
        ]);

        $worker = $this->workerService->createWorker($validatedData, $request->user());

        return response()->json([
            'message' => 'Data buruh berhasil ditambahkan.',
            'data'    => $worker,
        ], 201);
    }

        public function index(Request $request): JsonResponse
    {
        abort_if($request->user()->role !== 'pemilik', 403, 'Akses ditolak.');

        $workers = \App\Models\User::where('company_id', $request->user()->company_id)
            ->where('role', 'buruh')
            ->with(['schedule', 'benefit'])
            ->get();

        return response()->json([
            'message' => 'Daftar buruh berhasil diambil.',
            'data'    => $workers,
        ], 200);
    }

    public function update(Request $request, $id): JsonResponse
    {
        abort_if($request->user()->role !== 'pemilik', 403, 'Akses ditolak.');

        $worker = \App\Models\User::where('company_id', $request->user()->company_id)
            ->where('role', 'buruh')->findOrFail($id);

        $validatedData = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email,' . $worker->id],
            'schedule.start_time' => ['nullable', 'date_format:H:i:s'],
            'schedule.end_time' => ['nullable', 'date_format:H:i:s'],
            'schedule.work_days' => ['nullable', 'array'],
            'benefit.health_insurance' => ['nullable', 'numeric'],
            'benefit.health_insurance_desc' => ['nullable', 'string', 'max:255'],
            'benefit.food_allowance' => ['nullable', 'numeric'],
            'benefit.food_allowance_desc' => ['nullable', 'string', 'max:255'],
        ]);

        \DB::transaction(function () use ($worker, $validatedData) {
            $worker->update(['name' => $validatedData['name'], 'email' => $validatedData['email']]);
            
            if (isset($validatedData['schedule'])) {
                $worker->schedule()->update([
                    'start_time' => $validatedData['schedule']['start_time'] ?? '08:00:00',
                    'end_time' => $validatedData['schedule']['end_time'] ?? '16:00:00',
                    'work_days' => $validatedData['schedule']['work_days'] ?? [],
                ]);
            }

            if (isset($validatedData['benefit'])) {
                $worker->benefit()->update([
                    'health_insurance' => $validatedData['benefit']['health_insurance'] ?? 0,
                    'health_insurance_desc' => $validatedData['benefit']['health_insurance_desc'] ?? null,
                    'food_allowance' => $validatedData['benefit']['food_allowance'] ?? 0,
                    'food_allowance_desc' => $validatedData['benefit']['food_allowance_desc'] ?? null,
                ]);
            }
        });

        return response()->json(['message' => 'Data buruh berhasil diperbarui.', 'data' => $worker->load(['schedule', 'benefit'])], 200);
    }

    public function destroy(Request $request, $id): JsonResponse
    {
        abort_if($request->user()->role !== 'pemilik', 403, 'Akses ditolak.');

        $worker = \App\Models\User::where('company_id', $request->user()->company_id)
            ->where('role', 'buruh')
            ->findOrFail($id);

        $worker->delete();

        return response()->json(['message' => 'Akun buruh berhasil dihapus.'], 200);
    }

        public function getProfile(Request $request): JsonResponse
    {
        $user = \App\Models\User::with(['schedule', 'benefit'])
            ->find($request->user()->id);

        return response()->json([
            'message' => 'Profil buruh berhasil diambil.',
            'data'    => $user,
        ], 200);
    }
}