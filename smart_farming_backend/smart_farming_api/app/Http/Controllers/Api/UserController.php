<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;

class UserController extends Controller
{
    public function show(Request $request)
    {
        $user = $request->user()->load('company');

        return response()->json([
            'message' => 'Data profil berhasil diambil.',
            'data'    => $user,
        ], 200);
    }
}