<?php
namespace App\Http\Controllers\Api;
use App\Http\Controllers\Controller;
use Illuminate\Http\Request;

class FailureLogController extends Controller
{
    public function index(Request $request)
    {
        $logs = \App\Models\FailureLog::where('company_id', $request->user()->company_id)
            ->with('planting.land')
            ->latest()
            ->get();

        return response()->json(['message' => 'Data berhasil diambil', 'data' => $logs], 200);
    }
}