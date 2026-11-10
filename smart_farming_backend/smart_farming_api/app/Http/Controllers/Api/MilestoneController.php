<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\Land;
use App\Models\Milestone;

class MilestoneController extends Controller
{
    public function index(Request $request, $landId)
    {
        $milestones = Milestone::where('company_id', $request->user()->company_id)
            ->where('milestoneable_type', Land::class)
            ->where('milestoneable_id', $landId)
            ->latest()
            ->get();

        return response()->json(['data' => $milestones], 200);
    }

    public function store(Request $request, $landId)
    {
        $request->validate([
            'title' => 'required|string|max:255',
            'target_value' => 'required|numeric|min:1',
            'deadline' => 'required|date',
        ]);

        $land = Land::where('company_id', $request->user()->company_id)->findOrFail($landId);

        $milestone = $land->milestones()->make([
            'title' => $request->title,
            'target_value' => $request->target_value,
            'current_value' => 0,
            'deadline' => $request->deadline,
        ]);
        
        $milestone->company_id = $request->user()->company_id;
        $milestone->save();

        return response()->json(['message' => 'Milestone ditambahkan', 'data' => $milestone], 201);
    }

    public function update(Request $request, \App\Models\Milestone $milestone)
    {
        abort_if($milestone->company_id !== $request->user()->company_id, 403);

        $request->validate([
            'title' => 'required|string|max:255',
            'target_value' => 'required|numeric|min:1',
            'deadline' => 'required|date',
        ]);

        $milestone->update([
            'title' => $request->title,
            'target_value' => $request->target_value,
            'deadline' => $request->deadline,
        ]);

        return response()->json(['message' => 'Milestone diperbarui', 'data' => $milestone], 200);
    }

    public function updateProgress(Request $request, \App\Models\Milestone $milestone)
    {
        abort_if($milestone->company_id !== $request->user()->company_id, 403);

        $request->validate(['current_value' => 'required|numeric|min:0']);
        $milestone->update(['current_value' => $request->current_value]);

        return response()->json(['message' => 'Progres diperbarui', 'data' => $milestone], 200);
    }

    public function destroy(Request $request, \App\Models\Milestone $milestone)
    {
        abort_if($milestone->company_id !== $request->user()->company_id, 403);
        
        $milestone->delete();
        return response()->json(['message' => 'Milestone dihapus'], 200);
    }
}