<?php

namespace App\Http\Middleware;

use App\Models\User;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Kreait\Firebase\Auth as FirebaseAuth;
use Kreait\Firebase\Exception\Auth\RevokedIdToken; 
use Kreait\Firebase\Exception\InvalidArgumentException; 

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
            return response()->json(['message' => 'Token tidak disediakan.'], 401);
        }

        try {
            $verifiedIdToken = $this->firebaseAuth->verifyIdToken($token);
            $uid = $verifiedIdToken->claims()->get('sub');

            $user = User::firstOrCreate(
                ['id' => $uid],
                [
                    'email' => $verifiedIdToken->claims()->get('email'),
                    'displayName' => $verifiedIdToken->claims()->get('name', 'User'),
                    'photoURL' => $verifiedIdToken->claims()->get('picture'),
                ]
            );

            Auth::setUser($user);

        // [PERBAIKAN] Menangkap exception yang sesuai
        } catch (RevokedIdToken $e) {
            return response()->json(['message' => 'Token telah dicabut (revoked).'], 401);
        } catch (InvalidArgumentException $e) {
            // Exception ini akan menangkap token yang tidak valid atau kedaluwarsa
            return response()->json(['message' => 'Token tidak valid atau telah kedaluwarsa: ' . $e->getMessage()], 401);
        } catch (\Exception $e) {
            return response()->json(['message' => 'Terjadi kesalahan saat verifikasi token: ' . $e->getMessage()], 401);
        }

        return $next($request);
    }
}