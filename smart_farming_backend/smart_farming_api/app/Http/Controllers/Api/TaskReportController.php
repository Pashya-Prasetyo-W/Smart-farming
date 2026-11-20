<?php

namespace App\Http\Controllers\Api;

use App\Enums\ReviewStatus;
use App\Http\Controllers\Controller;
use App\Models\TaskReport;
use App\Services\ReportVerificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class TaskReportController extends Controller
{
    public function __construct(
        protected ReportVerificationService $verificationService
    ) {}

    public function queue(Request $request): JsonResponse
    {
        return response()->json([
            'data' => $this->verificationService->queue($request->user()),
        ]);
    }

    public function index(Request $request): JsonResponse
    {
        $filters = $request->validate([
            'from'    => ['nullable', 'date_format:Y-m-d'],
            'to'      => ['nullable', 'date_format:Y-m-d', 'after_or_equal:from'],
            'user_id' => ['nullable', 'integer'],
            'status'  => ['nullable', Rule::in(array_column(ReviewStatus::cases(), 'value'))],
        ]);

        return response()->json([
            'data' => $this->verificationService->history($request->user(), $filters),
        ]);
    }

    public function verify(Request $request, TaskReport $report): JsonResponse
    {
        $result = $this->verificationService->verify($request->user(), $report);

        return response()->json([
            'message' => 'Laporan diverifikasi.',
            'data'    => $result,
        ]);
    }

    public function reject(Request $request, TaskReport $report): JsonResponse
    {
        $validatedData = $request->validate([
            'reason' => ['required', 'string', 'max:255'],
        ]);

        $result = $this->verificationService->reject($request->user(), $report, $validatedData['reason']);

        return response()->json([
            'message' => 'Laporan ditolak.',
            'data'    => $result,
        ]);
    }

    public function object(Request $request, TaskReport $report): JsonResponse
    {
        $validatedData = $request->validate([
            'note' => ['required', 'string', 'max:255'],
        ]);

        $result = $this->verificationService->object($request->user(), $report, $validatedData['note']);

        return response()->json([
            'message' => 'Keberatan diajukan.',
            'data'    => $result,
        ]);
    }
}
