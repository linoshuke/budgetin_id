<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\WalletController;
use App\Http\Controllers\Api\TransactionController;
use App\Models\User;


Route::post('/sync-user', function (Request $request) {
    $firebaseAuth = app('firebase.auth');
    $token = $request->input('token');

    try {
        $verifiedIdToken = $firebaseAuth->verifyIdToken($token);
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

        return response()->json($user, 200);
    } catch (\Exception $e) {
        return response()->json(['message' => 'Failed to sync user', 'error' => $e->getMessage()], 400);
    }
});


// Grup semua rute yang membutuhkan user untuk login
Route::middleware(['auth:sanctum', 'auth.firebase'])->group(function () {
    // Route untuk mendapatkan user yang sedang login
    Route::get('/user', function (Request $request) {
        return $request->user();
    });

    // Routes untuk Wallet
    Route::get('/wallets', [WalletController::class, 'index']);
    Route::post('/wallets', [WalletController::class, 'store']);
    Route::put('/wallets/{wallet}', [WalletController::class, 'update']);
    Route::delete('/wallets/{wallet}', [WalletController::class, 'destroy']);

    // Routes untuk Transaction
    Route::get('/wallets/{wallet}/transactions', [TransactionController::class, 'index']);
    Route::post('/transactions', [TransactionController::class, 'store']);
    // Tambahkan update/delete untuk transaksi jika perlu
});