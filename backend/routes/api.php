<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Models\User;
use Kreait\Firebase\Contract\Auth as FirebaseAuth;

Route::post('/sync-user', function (Request $request, FirebaseAuth $firebaseAuth) {
    $request->validate([
        'token' => 'required|string',
    ]);

    try {
        $verifiedIdToken = $firebaseAuth->verifyIdToken($request->token);
    } catch (\Exception $e) {
        return response()->json(['message' => 'Invalid Firebase token'], 401);
    }

    $uid = $verifiedIdToken->claims()->get('sub');
    $firebaseUser = $firebaseAuth->getUser($uid);

    $user = User::updateOrCreate(
        ['firebase_uid' => $uid],
        [
            'name' => $firebaseUser->displayName ?? 'User',
            'email' => $firebaseUser->email,
            'photo_url' => $firebaseUser->photoUrl,
        ]
    );

    return response()->json([
        'message' => 'User synced successfully',
        'user' => $user,
    ]);
});