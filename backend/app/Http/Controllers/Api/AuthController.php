<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\Wallet;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Validation\Rules;
use Illuminate\Validation\ValidationException;
use Kreait\Firebase\Factory;
use Kreait\Firebase\Auth as FirebaseAuth;
use Kreait\Firebase\Exception\Auth\FailedToVerifyToken;

class AuthController extends Controller
{
    /**
     * Register a new user.
     */
    public function register(Request $request): JsonResponse
    {
        $request->validate([
            'displayName' => ['required', 'string', 'max:255'],
            'email' => ['required', 'string', 'email', 'max:255', 'unique:users'],
            'password' => ['required', 'confirmed', Rules\Password::defaults()],
        ]);

        $user = User::create([
            'id' => Str::uuid()->toString(),
            'displayName' => $request->displayName,
            'email' => $request->email,
            'password' => Hash::make($request->password),
        ]);

        // Create default wallets for new user
        $this->createDefaultWallets($user);

        // Create token for the user
        $token = $user->createToken('auth_token')->plainTextToken;

        return response()->json([
            'success' => true,
            'message' => 'Registrasi berhasil.',
            'data' => [
                'user' => $user,
                'token' => $token,
            ]
        ], 201);
    }

    /**
     * Login user and return token.
     */
    public function login(Request $request): JsonResponse
    {
        $request->validate([
            'email' => ['required', 'string', 'email'],
            'password' => ['required', 'string'],
        ]);

        $user = User::where('email', $request->email)->first();

        if (!$user || !Hash::check($request->password, $user->password)) {
            throw ValidationException::withMessages([
                'email' => ['Email atau password salah.'],
            ]);
        }

        // Revoke previous tokens
        $user->tokens()->delete();

        // Create new token
        $token = $user->createToken('auth_token')->plainTextToken;

        return response()->json([
            'success' => true,
            'message' => 'Login berhasil.',
            'data' => [
                'user' => $user,
                'token' => $token,
            ]
        ], 200);
    }

    public function loginWithFirebase(Request $request): JsonResponse
    {
        $request->validate([
            'firebase_token' => ['required', 'string'],
        ]);

        try {
            // Get Firebase credentials path
            $credentialsPath = config('firebase.projects.app.credentials');
            
            if (!$credentialsPath || !file_exists($credentialsPath)) {
                return response()->json([
                    'success' => false,
                    'message' => 'Firebase credentials tidak ditemukan. Pastikan file service account sudah dikonfigurasi.',
                    'data' => null
                ], 500);
            }

            // Initialize Firebase Auth
            $factory = (new Factory)->withServiceAccount($credentialsPath);
            $auth = $factory->createAuth();

            // Verify the ID Token
            $verifiedIdToken = $auth->verifyIdToken($request->firebase_token);
            
            // Get user data from token
            $firebaseUid = $verifiedIdToken->claims()->get('sub');
            $email = $verifiedIdToken->claims()->get('email');
            $name = $verifiedIdToken->claims()->get('name') ?? $verifiedIdToken->claims()->get('email');
            $picture = $verifiedIdToken->claims()->get('picture');

            // Find or create user
            $user = User::where('id', $firebaseUid)->first();
            
            if (!$user) {
                // Check if email already exists with different ID
                $existingUser = User::where('email', $email)->first();
                
                if ($existingUser) {
                    // Link Firebase UID to existing user
                    $existingUser->id = $firebaseUid;
                    if ($picture && !$existingUser->photoURL) {
                        $existingUser->photoURL = $picture;
                    }
                    $existingUser->save();
                    $user = $existingUser;
                } else {
                    // Create new user
                    $user = User::create([
                        'id' => $firebaseUid,
                        'displayName' => $name,
                        'email' => $email,
                        'photoURL' => $picture,
                        'password' => null, // No password for Firebase users
                    ]);

                    // Create default wallets for new user
                    $this->createDefaultWallets($user);
                }
            } else {
                // Update user data if changed
                $updated = false;
                if ($picture && $user->photoURL !== $picture) {
                    $user->photoURL = $picture;
                    $updated = true;
                }
                if ($name && $user->displayName !== $name) {
                    $user->displayName = $name;
                    $updated = true;
                }
                if ($updated) {
                    $user->save();
                }
            }

            // Revoke previous tokens
            $user->tokens()->delete();

            // Create new Sanctum token
            $token = $user->createToken('firebase_auth')->plainTextToken;

            return response()->json([
                'success' => true,
                'message' => 'Login dengan Google berhasil.',
                'data' => [
                    'user' => $user,
                    'token' => $token,
                    'is_new_user' => $user->wasRecentlyCreated,
                ]
            ], 200);

        } catch (FailedToVerifyToken $e) {
            return response()->json([
                'success' => false,
                'message' => 'Token Firebase tidak valid atau sudah kadaluarsa.',
                'data' => null
            ], 401);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Terjadi kesalahan: ' . $e->getMessage(),
                'data' => null
            ], 500);
        }
    }

    /**
     * Logout user (revoke token).
     */
    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json([
            'success' => true,
            'message' => 'Logout berhasil.',
            'data' => null
        ], 200);
    }

    /**
     * Get current authenticated user.
     */
    public function user(Request $request): JsonResponse
    {
        return response()->json([
            'success' => true,
            'message' => 'Data user berhasil diambil.',
            'data' => $request->user()
        ], 200);
    }

    /**
     * Update user profile.
     */
    public function updateProfile(Request $request): JsonResponse
    {
        $request->validate([
            'displayName' => ['sometimes', 'string', 'max:255'],
        ]);

        $user = $request->user();
        
        if ($request->has('displayName')) {
            $user->displayName = $request->displayName;
        }

        $user->save();

        return response()->json([
            'success' => true,
            'message' => 'Profil berhasil diperbarui.',
            'data' => $user
        ], 200);
    }

    /**
     * Upload profile photo.
     */
    public function uploadPhoto(Request $request): JsonResponse
    {
        $request->validate([
            'photo' => ['required', 'image', 'max:2048'], // Max 2MB
        ]);

        $user = $request->user();

        // Delete old photo if exists
        if ($user->photoURL && str_starts_with($user->photoURL, '/storage/')) {
            $oldPath = str_replace('/storage/', '', $user->photoURL);
            Storage::disk('public')->delete($oldPath);
        }

        // Store new photo
        $path = $request->file('photo')->store('profile_pictures', 'public');
        $user->photoURL = '/storage/' . $path;
        $user->save();

        return response()->json([
            'success' => true,
            'message' => 'Foto profil berhasil diupload.',
            'data' => [
                'photoURL' => $user->photoURL
            ]
        ], 200);
    }

    /**
     * Delete user account and all related data.
     */
    public function deleteAccount(Request $request): JsonResponse
    {
        $user = $request->user();

        // Delete profile photo if exists (only if stored locally)
        if ($user->photoURL && str_starts_with($user->photoURL, '/storage/')) {
            $path = str_replace('/storage/', '', $user->photoURL);
            Storage::disk('public')->delete($path);
        }

        // Delete all tokens
        $user->tokens()->delete();

        // Delete user (cascades to wallets and transactions)
        $user->delete();

        return response()->json([
            'success' => true,
            'message' => 'Akun berhasil dihapus.',
            'data' => null
        ], 200);
    }

    /**
     * Create default wallets for a new user.
     */
    private function createDefaultWallets(User $user): void
    {
        $defaultWallets = [
            ['walletName' => 'Dompet Tunai', 'category' => 'Uang Fisik', 'location' => 'Cash'],
            ['walletName' => 'GoPay', 'category' => 'E-Wallet', 'location' => 'Qris'],
            ['walletName' => 'Rekening Bank', 'category' => 'Tabungan', 'location' => 'Bank'],
        ];

        foreach ($defaultWallets as $walletData) {
            Wallet::create([
                'user_id' => $user->id,
                'walletName' => $walletData['walletName'],
                'category' => $walletData['category'],
                'location' => $walletData['location'],
                'balance' => 0.00,
                'displayPreference' => 'monthly',
            ]);
        }
    }
}

