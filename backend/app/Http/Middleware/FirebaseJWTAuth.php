<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Kreait\Firebase\Contract\Auth as FirebaseAuthContract;
use App\Models\User;
use Illuminate\Support\Facades\Auth;

class FirebaseJWTAuth
{
    protected $auth;
    public function __construct(FirebaseAuthContract $auth)
    {
        $this->auth = $auth;
    }

    public function handle(Request $request, Closure $next)
{
    $token = 'eyJhbGciOiJSUzI1NiIsImtpZCI6IjRmZWI0NGYwZjdhN2UyN2M3YzQwMzM3OWFmZjIwYWY1YzhjZjUyZGMiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FjY291bnRzLmdvb2dsZS5jb20iLCJhenAiOiI0MTI4ODEwODI3NDktaTRkOW9tYW02c24xc2VlbDA2M2w4dmJzOGFvcmE1cW4uYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJhdWQiOiI0MTI4ODEwODI3NDktZnI2Z2lkbDBtMmdibzVlcjNicGtwdGZ2cW43OWgxYjguYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJzdWIiOiIxMDE2NzIyNTY1MjYwMTc5NzgyMTYiLCJlbWFpbCI6ImRlZGVpY2hzYW4ucjE1QGdtYWlsLmNvbSIsImVtYWlsX3ZlcmlmaWVkIjp0cnVlLCJuYW1lIjoiRGVkZSBJY2hzYW4gUiIsInBpY3R1cmUiOiJodHRwczovL2xoMy5nb29nbGV1c2VyY29udGVudC5jb20vYS9BQ2c4b2NKd0hmZnhOa2ltUDJtZnRkNUJ1TVg0MThJWFNkTkx3cGoxekd6SWRuc01LVXdiVGMxQz1zOTYtYyIsImdpdmVuX25hbWUiOiJEZWRlIiwiZmFtaWx5X25hbWUiOiJJY2hzYW4gUiIsImlhdCI6MTc2MjkxODYzNiwiZXhwIjoxNzYyOTIyMjM2fQ.pH6_APFTWvZYQRmgdcupH7YhLWn5-3R5lpEGpZR3ltvESUvrJ0KxAB_1h-eNXLbIccwbpWuGkUBoqAwuzhqYjcC_xq27GikTyf7rrGQ33_A46B_p_LlltNN9yJizCMZaAOxDjw0lhRjzbELOTsqSUzDBQDG0q3bXqjALnKcK-H2kwBPynMQsmOEVLPnmhu7h7XXedp57J4MguS-ekFANfqCQEPZcwvC9W_92tA0ebuGZBn4zKykL5uV3zLEED';

    if (!$token) {
        return response()->json(['success' => false, 'message' => 'Token autentikasi tidak ditemukan.'], 401);
    }

    try {
        $verifiedIdToken = $this->auth->verifyIdToken($token);
    } catch (\Exception $e) {
        // Jika tes ini masih gagal, errornya akan sangat spesifik (misal: token expired)
        return response()->json(['success' => false, 'message' => 'Verifikasi GAGAL bahkan dengan hardcode: ' . $e->getMessage()], 401);
    }

        $uid = $verifiedIdToken->claims()->get('sub');

        $user = User::firstOrCreate(
            ['firebase_uid' => $uid],
            [
                'name' => $verifiedIdToken->claims()->get('name', 'User'),
                'email' => $verifiedIdToken->claims()->get('email'),
                'password' => bcrypt(uniqid()),
            ]
        );

        Auth::login($user); // Gunakan Auth::login($user) agar state login lebih konsisten

        return $next($request);
    }
}
