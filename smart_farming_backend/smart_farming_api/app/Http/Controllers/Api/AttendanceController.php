<?php

namespace App\Http\Controllers\Api;

use App\Enums\AttendanceStatus;
use App\Http\Controllers\Controller;
use App\Models\Attendance;
use App\Services\AttendanceService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class AttendanceController extends Controller
{
    public function __construct(
        protected AttendanceService $attendanceService
    ) {}

    private function rangeRules(): array
    {
        return [
            'from' => ['nullable', 'date_format:Y-m-d'],
            'to'   => ['nullable', 'date_format:Y-m-d', 'after_or_equal:from'],
        ];
    }

    public function today(Request $request): JsonResponse
    {
        return response()->json([
            'data' => $this->attendanceService->today($request->user()),
        ]);
    }

    public function checkIn(Request $request): JsonResponse
    {
        $attendance = $this->attendanceService->checkIn($request->user());

        return response()->json([
            'message' => 'Absen masuk tercatat.',
            'data'    => $attendance,
        ], 201);
    }

    public function checkOut(Request $request): JsonResponse
    {
        $attendance = $this->attendanceService->checkOut($request->user());

        return response()->json([
            'message' => 'Absen pulang tercatat.',
            'data'    => $attendance,
        ]);
    }

    public function mine(Request $request): JsonResponse
    {
        $filters = $request->validate($this->rangeRules());

        return response()->json([
            'data' => $this->attendanceService->mine($request->user(), $filters),
        ]);
    }

    public function index(Request $request): JsonResponse
    {
        $filters = $request->validate($this->rangeRules() + [
            'user_id' => ['nullable', 'integer'],
            'status'  => ['nullable', Rule::in(array_column(AttendanceStatus::cases(), 'value'))],
        ]);

        return response()->json([
            'data' => $this->attendanceService->history($request->user(), $filters),
        ]);
    }

    public function queue(Request $request): JsonResponse
    {
        return response()->json([
            'data' => $this->attendanceService->reviewQueue($request->user()),
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $validatedData = $request->validate([
            'user_id'        => ['required', 'integer'],
            'work_date'      => ['required', 'date_format:Y-m-d'],
            'check_in_time'  => ['required', 'date_format:H:i'],
            'check_out_time' => ['nullable', 'date_format:H:i'],
        ]);

        $attendance = $this->attendanceService->record($request->user(), $validatedData);

        return response()->json([
            'message' => 'Absensi berhasil dicatat.',
            'data'    => $attendance,
        ], 201);
    }

    public function verify(Request $request, Attendance $attendance): JsonResponse
    {
        $result = $this->attendanceService->verify($request->user(), $attendance);

        return response()->json([
            'message' => 'Absensi diverifikasi.',
            'data'    => $result,
        ]);
    }

    public function reject(Request $request, Attendance $attendance): JsonResponse
    {
        $validatedData = $request->validate([
            'reason' => ['required', 'string', 'max:255'],
        ]);

        $result = $this->attendanceService->reject($request->user(), $attendance, $validatedData['reason']);

        return response()->json([
            'message' => 'Absensi ditolak.',
            'data'    => $result,
        ]);
    }

    public function object(Request $request, Attendance $attendance): JsonResponse
    {
        $validatedData = $request->validate([
            'note' => ['required', 'string', 'max:255'],
        ]);

        $result = $this->attendanceService->object($request->user(), $attendance, $validatedData['note']);

        return response()->json([
            'message' => 'Keberatan diajukan.',
            'data'    => $result,
        ]);
    }
}
