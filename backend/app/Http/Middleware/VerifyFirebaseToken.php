<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Kreait\Firebase\Contract\Auth as FirebaseAuth;
use App\Models\User;
use Illuminate\Support\Facades\Auth;

class VerifyFirebaseToken
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
            return response()->json(['message' => 'Authentication token not provided.'], 401);
        }

        try {
            $verifiedIdToken = $this->firebaseAuth->verifyIdToken($token);
            $uid = $verifiedIdToken->claims()->get('sub');

            // Cari user di database kita berdasarkan firebase_uid
            $user = User::where('firebase_uid', $uid)->first();

            if ($user) {
                // Masukkan user ini sebagai user yang terotentikasi untuk request ini
                Auth::login($user);
                return $next($request);
            }

            return response()->json(['message' => 'User not found in our database.'], 404);

        } catch (\Exception $e) {
            return response()->json(['message' => 'Invalid or expired authentication token.', 'error' => $e->getMessage()], 401);
        }
    }
}