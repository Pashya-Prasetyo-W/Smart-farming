<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Cloudinary\Configuration\Configuration;
use Cloudinary\Api\Upload\UploadApi;

class UploadController extends Controller
{
    public function upload(Request $request)
    {
        $request->validate([
            'file' => 'required|file|mimes:jpeg,png,jpg,mp4|max:10240',
        ]);

        if ($request->hasFile('file')) {
            try {
                Configuration::instance([
                    'cloud' => [
                        'cloud_name' => env('CLOUDINARY_CLOUD_NAME'),
                        'api_key'    => env('CLOUDINARY_API_KEY'),
                        'api_secret' => env('CLOUDINARY_API_SECRET'),
                    ],
                    'url' => [
                        'secure' => true
                    ]
                ]);

                $upload = (new UploadApi())->upload(
                    $request->file('file')->getRealPath(),
                    ['folder' => 'tani_pintar_reports']
                );

                return response()->json([
                    'message' => 'File berhasil diunggah ke Cloudinary.',
                    'url' => $upload['secure_url'],
                ], 200);

            } catch (\Exception $e) {
                return response()->json([
                    'message' => 'Gagal upload: ' . $e->getMessage()
                ], 500);
            }
        }

        return response()->json(['message' => 'File tidak ditemukan.'], 400);
    }
}