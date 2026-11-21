<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\TaskService;
use App\Services\ReportService;
use App\Models\Task;
use App\Models\WorkerWage;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class TaskController extends Controller
{
    public function __construct(
        protected TaskService $taskService,
        protected ReportService $reportService
    ) {}

    private function taskRules(Request $request, bool $multiple): array
    {
        $companyId = $request->user()->company_id;

        $sameCompany = fn (string $table) => Rule::exists($table, 'id')->where('company_id', $companyId);

        $assignable = fn () => Rule::exists('users', 'id')->where(
            fn ($query) => $query
                ->where('company_id', $companyId)
                ->whereIn('role', ['buruh', 'mandor'])
                ->where('is_active', true)
        );

        $assignees = $multiple
            ? [
                'assigned_to'      => ['nullable', 'required_without:assignee_ids', $assignable()],
                'assignee_ids'     => ['required_without:assigned_to', 'array', 'min:1', 'max:100'],
                'assignee_ids.*'   => ['integer', 'distinct', $assignable()],
            ]
            : [
                'assigned_to'      => ['required', $assignable()],
            ];

        return [
            ...$assignees,
            'planting_id'                   => ['required', $sameCompany('plantings')],
            'title'                         => ['required', 'string', 'max:255'],
            'task_date'                     => ['required', 'date'],
            'due_date'                      => ['required', 'date', 'after_or_equal:task_date'],
            'description'                   => ['nullable', 'string'],
            'wage_amount'                   => ['nullable', 'numeric', 'min:1', 'max:1000000000'],
            'resources'                     => ['nullable', 'array'],
            'resources.*.resource_id'       => ['required', $sameCompany('resources')],
            'resources.*.max_allocated_qty' => ['required', 'numeric', 'min:0'],
            'tools'                         => ['nullable', 'array'],
            'tools.*.tool_id'               => ['required', $sameCompany('tools')],
            'tools.*.qty'                   => ['required', 'integer', 'min:1'],
        ];
    }

    private function validateTask(Request $request, bool $multiple = false): array
    {
        $data = $request->validate($this->taskRules($request, $multiple));

        $assigneeIds = $multiple && ! empty($data['assignee_ids'])
            ? array_map('intval', $data['assignee_ids'])
            : [(int) $data['assigned_to']];

        $boronganIds = WorkerWage::whereIn('user_id', $assigneeIds)
            ->where('wage_type', WorkerWage::TYPE_BORONGAN)
            ->pluck('user_id')
            ->map(fn ($id) => (int) $id)
            ->all();

        if (! empty($boronganIds) && empty($data['wage_amount'])) {
            throw ValidationException::withMessages([
                'wage_amount' => ['Upah tugas wajib diisi untuk pelaksana dengan upah borongan.'],
            ]);
        }

        if (empty($boronganIds)) {
            $data['wage_amount'] = null;
        }

        $data['assignee_ids'] = $assigneeIds;
        $data['borongan_ids'] = $boronganIds;

        return $data;
    }

    public function store(Request $request): JsonResponse
    {
        $validatedData = $this->validateTask($request, true);

        $tasks = $this->taskService->createTasks(
            $validatedData,
            $validatedData['assignee_ids'],
            $request->user(),
            $validatedData['borongan_ids']
        );

        if ($request->has('assignee_ids')) {
            return response()->json([
                'message' => $tasks->count() . ' tugas berhasil dibuat.',
                'data'    => $tasks,
            ], 201);
        }

        return response()->json([
            'message' => 'Tugas berhasil dibuat.',
            'data'    => $tasks->first(),
        ], 201);
    }

    public function start(Request $request, Task $task): JsonResponse
    {
        abort_if(
            ! $request->user()->hasRole('buruh', 'mandor'),
            403,
            'Akses ditolak. Hanya pelaksana tugas (buruh/mandor) yang dapat memulai tugas.'
        );

        abort_if(
            (int) $task->assigned_to !== (int) $request->user()->id,
            403,
            'Akses ditolak. Anda tidak memiliki akses ke tugas ini.'
        );

        $updatedTask = $this->taskService->startTask($task, $request->user());

        return response()->json([
            'message' => 'Pekerjaan dimulai.',
            'data'    => $updatedTask,
        ], 200);
    }

    public function report(Request $request, Task $task): JsonResponse
    {
        abort_if(
            ! $request->user()->hasRole('buruh', 'mandor'),
            403,
            'Akses ditolak. Hanya pelaksana tugas (buruh/mandor) yang dapat mengirim laporan tugas.'
        );

        abort_if(
            (int) $task->assigned_to !== (int) $request->user()->id,
            403,
            'Akses ditolak. Anda tidak memiliki akses ke tugas ini.'
        );

        $companyId = $request->user()->company_id;

        $validatedData = $request->validate([
            'media_urls'                  => ['required', 'array'],
            'media_urls.*'                => ['string'],
            'notes'                       => ['nullable', 'string'],
            'reported_at'                 => ['nullable', 'date'],
            'resources'                   => ['nullable', 'array'],
            'resources.*.resource_id'     => ['required', Rule::exists('resources', 'id')->where('company_id', $companyId)],
            'resources.*.actual_used_qty' => ['required', 'numeric', 'min:0'],
            'tools'                       => ['nullable', 'array'],
            'tools.*.tool_id'             => ['required', Rule::exists('tools', 'id')->where('company_id', $companyId)],
            'tools.*.lost_qty'            => ['nullable', 'integer', 'min:0', 'max:1000'],
            'tools.*.damaged_qty'         => ['nullable', 'integer', 'min:0', 'max:1000'],
        ]);

        $report = $this->reportService->submitReport($task, $validatedData);

        return response()->json([
            'message' => 'Laporan berhasil dikirim.',
            'data'    => $report,
        ], 201);
    }

    public function cancel(Request $request, Task $task): JsonResponse
    {
        abort_if(
            ! $request->user()->hasRole('pemilik', 'mandor'),
            403,
            'Akses ditolak. Hanya pemilik atau mandor yang dapat membatalkan tugas.'
        );

        $validatedData = $request->validate([
            'reason' => ['required', 'string', 'max:500'],
        ]);

        $updatedTask = $this->taskService->cancelTask($task, $request->user(), $validatedData['reason']);

        return response()->json([
            'message' => 'Tugas berhasil dibatalkan.',
            'data'    => $updatedTask,
        ], 200);
    }

    public function index(Request $request): JsonResponse
    {
        $tasks = $this->taskService->getTasks($request->user());

        return response()->json([
            'message' => 'Daftar tugas berhasil diambil.',
            'data'    => $tasks,
        ], 200);
    }

    public function show(Request $request, Task $task): JsonResponse
    {
        abort_if(
            $request->user()->hasRole('buruh') && (int) $task->assigned_to !== (int) $request->user()->id,
            403,
            'Akses ditolak.'
        );

        $task->load(['planting.land', 'assignee', 'resources', 'tools', 'report.reviewer:id,name']);

        return response()->json([
            'message' => 'Detail tugas berhasil diambil.',
            'data'    => $task,
        ], 200);
    }

    public function update(Request $request, Task $task): JsonResponse
    {
        $validatedData = $this->validateTask($request);

        $updatedTask = $this->taskService->updateTask($task, $validatedData);

        return response()->json([
            'message' => 'Tugas berhasil diperbarui.',
            'data'    => $updatedTask,
        ], 200);
    }
}
