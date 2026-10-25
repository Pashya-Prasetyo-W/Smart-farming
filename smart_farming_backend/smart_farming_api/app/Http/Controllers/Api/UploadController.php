<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class UploadController extends Controller
{
    public function upload(Request $request)
    {
        $request->validate([
            'file' => 'required|file|mimes:jpeg,png,jpg,mp4|max:10240',
        ]);

        if ($request->hasFile('file')) {
            $path = $request->file('file')->store('reports', 'public');
            
            $url = asset('storage/' . $path);

            return response()->json([
                'message' => 'File berhasil diunggah.',
                'url' => $url,
            ], 200);
        }

        return response()->json(['message' => 'File tidak ditemukan.'], 400);
    }
}