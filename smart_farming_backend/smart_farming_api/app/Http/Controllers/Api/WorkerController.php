<?php

namespace App\Http\Controllers\Api;

use App\Enums\UserRole;
use App\Http\Controllers\Controller;
use App\Models\IncidentReport;
use App\Models\Task;
use App\Models\User;
use App\Models\WorkerBenefitItem;
use App\Models\WorkerWage;
use App\Services\WorkerService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class WorkerController extends Controller
{
    public function __construct(
        protected WorkerService $workerService
    ) {}

    private function manageableRoles(User $actor): array
    {
        return $actor->hasRole(UserRole::Pemilik->value)
            ? [UserRole::Buruh->value, UserRole::Mandor->value]
            : [UserRole::Buruh->value];
    }

    private function wageRules(string $role): array
    {
        return [
            'wage'                => ['nullable', 'array'],
            'wage.wage_type'      => ['required_with:wage', Rule::in(WorkerWage::typesFor($role))],
            'wage.amount'         => ['required_with:wage', 'exclude_if:wage.wage_type,borongan', 'numeric', 'min:0', 'max:1000000000'],
            'allowances'          => ['nullable', 'array', 'max:20'],
            'allowances.*.name'   => ['required', 'string', 'max:100'],
            'allowances.*.amount' => ['required', 'numeric', 'min:0', 'max:1000000000'],
        ];
    }

    private function payrollRelations(User $actor): array
    {
        return $actor->hasRole(UserRole::Pemilik->value) ? ['wage', 'allowances'] : [];
    }

    private function findManageable(Request $request, $id): User
    {
        $actor = $request->user();

        return User::where('company_id', $actor->company_id)
            ->whereIn('role', $this->manageableRoles($actor))
            ->findOrFail($id);
    }

    public function store(Request $request): JsonResponse
    {
        $actor = $request->user();

        $validatedData = $request->validate([
            'name'                          => ['required', 'string', 'max:255'],
            'email'                         => ['required', 'string', 'email', 'max:255', 'unique:users,email'],
            'password'                      => ['required', 'string', 'min:8'],
            'role'                          => ['nullable', Rule::in([UserRole::Buruh->value, UserRole::Mandor->value])],

            'schedule'                      => ['nullable', 'array'],
            'schedule.start_time'           => ['nullable', 'date_format:H:i:s'],
            'schedule.end_time'             => ['nullable', 'date_format:H:i:s'],
            'schedule.work_days'            => ['nullable', 'array'],
            'schedule.work_days.*'          => ['string'],

            'benefits'                      => ['nullable', 'array', 'max:20'],
            'benefits.*.type'               => ['required', Rule::in(WorkerBenefitItem::TYPES)],
            'benefits.*.name'               => ['required', 'string', 'max:255'],
            'benefits.*.description'        => ['nullable', 'string', 'max:255'],

            ...$this->wageRules(
                $request->input('role') === UserRole::Mandor->value
                    ? UserRole::Mandor->value
                    : UserRole::Buruh->value
            ),
        ]);

        $role = $validatedData['role'] ?? UserRole::Buruh->value;

        abort_if(
            ! in_array($role, $this->manageableRoles($actor), true),
            403,
            'Akses ditolak. Hanya pemilik yang dapat membuat akun mandor.'
        );

        $validatedData['role'] = $role;

        $worker = $this->workerService->createWorker($validatedData, $actor);
        $worker->load($this->payrollRelations($actor));

        return response()->json([
            'message' => $role === UserRole::Mandor->value
                ? 'Akun mandor berhasil ditambahkan.'
                : 'Data buruh berhasil ditambahkan.',
            'data'    => $worker,
        ], 201);
    }

    public function index(Request $request): JsonResponse
    {
        $actor = $request->user();

        $workers = User::where('company_id', $actor->company_id)
            ->whereIn('role', $this->manageableRoles($actor))
            ->with(array_unique(array_merge(['schedule', 'benefits', 'creator:id,name', 'wage'], $this->payrollRelations($actor))))
            ->orderBy('role')
            ->orderBy('name')
            ->get()
            ->each(function (User $worker) use ($actor) {
                $worker->setAttribute('wage_type', $worker->wage?->wage_type);

                if (! $actor->hasRole(UserRole::Pemilik->value)) {
                    $worker->unsetRelation('wage');
                }
            });

        return response()->json([
            'message' => 'Daftar karyawan berhasil diambil.',
            'data'    => $workers,
        ], 200);
    }

    public function update(Request $request, $id): JsonResponse
    {
        $worker = $this->findManageable($request, $id);

        $validatedData = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', Rule::unique('users', 'email')->ignore($worker->id)],
            'password' => ['nullable', 'string', 'min:8'],
            'schedule.start_time' => ['nullable', 'date_format:H:i:s'],
            'schedule.end_time' => ['nullable', 'date_format:H:i:s'],
            'schedule.work_days' => ['nullable', 'array'],
            'benefits' => ['nullable', 'array', 'max:20'],
            'benefits.*.type' => ['required', Rule::in(WorkerBenefitItem::TYPES)],
            'benefits.*.name' => ['required', 'string', 'max:255'],
            'benefits.*.description' => ['nullable', 'string', 'max:255'],
            ...$this->wageRules($worker->role),
        ]);

        $actor = $request->user();

        DB::transaction(function () use ($worker, $validatedData, $actor) {
            $updateData = [
                'name'  => $validatedData['name'],
                'email' => $validatedData['email'],
            ];

            $passwordReset = ! empty($validatedData['password']);

            if ($passwordReset) {
                $updateData['password'] = $validatedData['password'];
                $updateData['must_change_password'] = true;
            }

            $worker->forceFill($updateData)->save();

            if ($passwordReset) {
                $worker->tokens()->delete();
            }

            if (isset($validatedData['schedule'])) {
                $worker->schedule()->update([
                    'start_time' => $validatedData['schedule']['start_time'] ?? '08:00:00',
                    'end_time'   => $validatedData['schedule']['end_time'] ?? '16:00:00',
                    'work_days'  => $validatedData['schedule']['work_days'] ?? [],
                ]);
            }

            if (array_key_exists('benefits', $validatedData)) {
                $this->workerService->syncBenefits($worker, $validatedData['benefits'] ?? []);
            }

            if ($actor->hasRole(UserRole::Pemilik->value)) {
                $this->workerService->syncWage($worker, $validatedData['wage'] ?? null);

                if (array_key_exists('allowances', $validatedData)) {
                    $this->workerService->syncAllowances($worker, $validatedData['allowances'] ?? []);
                }
            }
        });

        return response()->json([
            'message' => 'Data karyawan berhasil diperbarui.',
            'data'    => $worker->load(array_merge(['schedule', 'benefits'], $this->payrollRelations($actor))),
        ], 200);
    }

    public function destroy(Request $request, $id): JsonResponse
    {
        $worker = $this->findManageable($request, $id);

        $hasHistory = Task::where('assigned_to', $worker->id)->exists()
            || IncidentReport::where('reported_by', $worker->id)->exists()
            || User::where('created_by', $worker->id)->exists();

        if ($hasHistory) {
            return response()->json([
                'message' => 'Akun ini sudah memiliki riwayat kerja dan tidak dapat dihapus. Nonaktifkan akun ini sebagai gantinya.',
            ], 422);
        }

        $worker->tokens()->delete();
        $worker->delete();

        return response()->json(['message' => 'Akun berhasil dihapus.'], 200);
    }

    public function deactivate(Request $request, $id): JsonResponse
    {
        return $this->setActive($request, $id, false);
    }

    public function activate(Request $request, $id): JsonResponse
    {
        return $this->setActive($request, $id, true);
    }

    private function setActive(Request $request, $id, bool $active): JsonResponse
    {
        $worker = $this->findManageable($request, $id);

        $worker->forceFill(['is_active' => $active])->save();

        if (! $active) {
            $worker->tokens()->delete();
        }

        return response()->json([
            'message' => $active ? 'Akun berhasil diaktifkan.' : 'Akun berhasil dinonaktifkan.',
            'data'    => $worker,
        ], 200);
    }

    public function getProfile(Request $request): JsonResponse
    {
        $user = User::with(['schedule', 'benefits', 'wage', 'allowances'])
            ->find($request->user()->id);

        return response()->json([
            'message' => 'Profil karyawan berhasil diambil.',
            'data'    => $user,
        ], 200);
    }
}
