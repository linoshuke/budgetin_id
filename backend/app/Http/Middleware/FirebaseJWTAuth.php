<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Kreait\Firebase\Auth as FirebaseAuth;
use App\Models\User;
use Illuminate\Support\Facades\Auth;

class FirebaseJWTAuth
{
    protected $firebaseAuth;

    public function __construct(FirebaseAuth $firebaseAuth)
    {
        $this->firebaseAuth = $firebaseAuth;
    }

    public function handle(Request $request, Closure $next)
    {
        $token = $request->bearerToken();

        if (!$token) {
            return response()->json(['message' => 'Token not provided.'], 401);
        }

        try {
            $verifiedIdToken = $this->firebaseAuth->verifyIdToken($token);
            $uid = $verifiedIdToken->claims()->get('sub');

            // Cari user di database lokal, atau buat baru jika belum ada
            $user = User::firstOrCreate(
                ['id' => $uid],
                [
                    'email' => $verifiedIdToken->claims()->get('email'),
                    'displayName' => $verifiedIdToken->claims()->get('name', 'User'),
                    // Anda bisa menambahkan photoURL jika ada di token
                    // 'photoURL' => $verifiedIdToken->claims()->get('picture'), 
                ]
            );

            // Login-kan user di sistem auth Laravel
            Auth::login($user);

        } catch (\Exception $e) {
            return response()->json(['message' => 'Invalid token: ' . $e->getMessage()], 401);
        }

        return $next($request);
    }
}