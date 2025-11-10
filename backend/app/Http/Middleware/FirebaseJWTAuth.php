<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Kreait\Firebase\Factory;
use Kreait\Firebase\Auth as FirebaseAuth;
use App\Models\User; // Pastikan model User Anda ada di sini
use Illuminate\Support\Facades\Auth;

class FirebaseJWTAuth
{
    protected $auth;

    public function __construct(FirebaseAuth $auth)
    {
        $this->auth = $auth;
    }

    public function handle(Request $request, Closure $next)
    {
        $token = $request->bearerToken();

        if (!$token) {
            return response()->json(['success' => false, 'message' => 'Token tidak ditemukan.'], 401);
        }

        try {
            $verifiedIdToken = $this->auth->verifyIdToken($token);
        } catch (\Exception $e) {
            // Jika token tidak valid (kadaluwarsa, format salah, dll.)
            return response()->json(['success' => false, 'message' => 'Token tidak valid: ' . $e->getMessage()], 401);
        }

        // Ambil UID dari token
        $uid = $verifiedIdToken->claims()->get('sub');

        // Cari atau buat user baru di database Laravel Anda
        // Sesuaikan 'firebase_uid' dengan nama kolom di tabel users Anda
        $user = User::firstOrCreate(
            ['firebase_uid' => $uid],
            [
                'name' => $verifiedIdToken->claims()->get('name', 'User'),
                'email' => $verifiedIdToken->claims()->get('email'),
                'password' => bcrypt(uniqid()), // Isi dengan password acak jika diperlukan
            ]
        );

        // Login-kan user untuk request ini
        Auth::setUser($user);

        return $next($request);
    }
}