<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureAccountActive
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if ($user && ! $user->is_active) {
            return response()->json([
                'message' => 'Akun Anda dinonaktifkan. Hubungi atasan Anda.',
                'code'    => 'account_inactive',
            ], 403);
        }

        if (
            $user
            && $user->must_change_password
            && ! $request->routeIs('auth.change-password', 'auth.logout', 'user.show')
        ) {
            return response()->json([
                'message' => 'Anda harus mengganti password terlebih dahulu.',
                'code'    => 'password_change_required',
            ], 403);
        }

        return $next($request);
    }
}
