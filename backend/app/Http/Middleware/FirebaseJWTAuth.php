<?php

namespace App\Http\Middleware;

use App\Models\User;
use Closure;
use Illuminate\Http\Request;
use Kreait\Firebase\Auth as FirebaseAuth;
use Kreait\Firebase\Exception\Auth\IdTokenExpired;
use Kreait\Firebase\Exception\Auth\InvalidIdToken;

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

            // Cari user di database lokal berdasarkan 'id', atau buat baru jika belum ada.
            // Kode ini sudah benar sesuai dengan skema database Anda.
            $user = User::firstOrCreate(
                ['id' => $uid],
                [
                    'email' => $verifiedIdToken->claims()->get('email'),
                    'displayName' => $verifiedIdToken->claims()->get('name', 'User'),
                    'photoURL' => $verifiedIdToken->claims()->get('picture'),
                ]
            );

            // Mengatur user yang terautentikasi untuk request ini.
            // Ini adalah cara yang lebih disukai untuk API stateless.
            auth()->setUser($user);

        } catch (IdTokenExpired $e) {
            return response()->json(['message' => 'Token telah kedaluwarsa.'], 401);
        } catch (InvalidIdToken $e) {
            return response()->json(['message' => 'Token tidak valid.'], 401);
        } catch (\Exception $e) {
            return response()->json(['message' => 'Terjadi kesalahan saat verifikasi token: ' . $e->getMessage()], 401);
        }

        return $next($request);
    }
}