<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\TaskService;
use App\Services\ReportService;
use App\Models\Task;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class TaskController extends Controller
{
    public function __construct(
        protected TaskService $taskService,
        protected ReportService $reportService
    ) {}

    public function store(Request $request): JsonResponse
    {
        $validatedData = $request->validate([
            'planting_id'                   => ['required', 'exists:plantings,id'],
            'assigned_to'                   => ['required', 'exists:users,id'],
            'title'                         => ['required', 'string', 'max:255'],
            'task_date'                     => ['required', 'date'],
            'due_date'                      => ['required', 'date', 'after_or_equal:task_date'],
            'description'                   => ['nullable', 'string'],
            'resources'                     => ['nullable', 'array'],
            'resources.*.resource_id'       => ['required', 'exists:resources,id'],
            'resources.*.max_allocated_qty' => ['required', 'numeric', 'min:0'],
            'tools'                         => ['nullable', 'array'],
            'tools.*.tool_id'               => ['required', 'exists:tools,id'],
            'tools.*.qty'                   => ['required', 'integer', 'min:1'],
        ]);

        $task = $this->taskService->createTask($validatedData, $request->user());

        return response()->json([
            'message' => 'Tugas berhasil dibuat.',
            'data'    => $task,
        ], 201);
    }

    public function start(Request $request, Task $task): JsonResponse
    {
        abort_if(
            $request->user()->role !== 'buruh',
            403,
            'Akses ditolak. Hanya buruh yang dapat memulai tugas.'
        );

        abort_if(
            $task->assigned_to !== $request->user()->id,
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
            $request->user()->role !== 'buruh',
            403,
            'Akses ditolak. Hanya buruh yang dapat mengirim laporan tugas.'
        );

        abort_if(
            $task->assigned_to !== $request->user()->id,
            403,
            'Akses ditolak. Anda tidak memiliki akses ke tugas ini.'
        );

        $validatedData = $request->validate([
            'media_urls'                  => ['required', 'array'],
            'media_urls.*'                => ['string'],
            'notes'                       => ['nullable', 'string'],
            'reported_at'                 => ['nullable', 'date'],
            'resources'                   => ['nullable', 'array'],
            'resources.*.resource_id'     => ['required', 'exists:resources,id'],
            'resources.*.actual_used_qty' => ['required', 'numeric', 'min:0'],
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
            $request->user()->role !== 'pemilik',
            403,
            'Akses ditolak. Hanya pemilik yang dapat membatalkan tugas.'
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
        abort_if($task->company_id !== $request->user()->company_id, 403, 'Akses ditolak.');

        $task->load(['planting.land', 'assignee', 'resources', 'tools', 'report']);

        return response()->json([
            'message' => 'Detail tugas berhasil diambil.',
            'data'    => $task,
        ], 200);
    }

        public function update(Request $request, Task $task): JsonResponse
    {
        $validatedData = $request->validate([
            'planting_id'                   => ['required', 'exists:plantings,id'],
            'assigned_to'                   => ['required', 'exists:users,id'],
            'title'                         => ['required', 'string', 'max:255'],
            'task_date'                     => ['required', 'date'],
            'due_date'                      => ['required', 'date', 'after_or_equal:task_date'],
            'description'                   => ['nullable', 'string'],
            'resources'                     => ['nullable', 'array'],
            'resources.*.resource_id'       => ['required', 'exists:resources,id'],
            'resources.*.max_allocated_qty' => ['required', 'numeric', 'min:0'],
            'tools'                         => ['nullable', 'array'],
            'tools.*.tool_id'               => ['required', 'exists:tools,id'],
            'tools.*.qty'                   => ['required', 'integer', 'min:1'],
        ]);

        $updatedTask = $this->taskService->updateTask($task, $validatedData);

        return response()->json([
            'message' => 'Tugas berhasil diperbarui.',
            'data'    => $updatedTask,
        ], 200);
    }
}