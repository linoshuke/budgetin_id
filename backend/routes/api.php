<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\WalletController;
use App\Http\Controllers\Api\TransactionController;
use App\Http\Controllers\Api\SummaryController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
*/

// Public routes (no authentication required)
Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);
Route::post('/login/firebase', [AuthController::class, 'loginWithFirebase']);

// Protected routes (authentication required)
Route::middleware('auth:sanctum')->group(function () {
    // Auth routes
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/user', [AuthController::class, 'user']);
    Route::put('/user', [AuthController::class, 'updateProfile']);
    Route::post('/user/photo', [AuthController::class, 'uploadPhoto']);
    Route::delete('/user', [AuthController::class, 'deleteAccount']);

    // Wallet routes
    Route::get('/wallets', [WalletController::class, 'index']);
    Route::post('/wallets', [WalletController::class, 'store']);
    Route::get('/wallets/{id}', [WalletController::class, 'show']);
    Route::put('/wallets/{id}', [WalletController::class, 'update']);
    Route::delete('/wallets/{id}', [WalletController::class, 'destroy']);
    Route::post('/wallets/default', [WalletController::class, 'createDefaults']);
    Route::get('/wallets/{id}/stats', [WalletController::class, 'stats']);

    // Transaction routes
    Route::get('/transactions', [TransactionController::class, 'index']);
    Route::post('/transactions', [TransactionController::class, 'store']);
    Route::get('/transactions/{id}', [TransactionController::class, 'show']);
    Route::delete('/transactions/{id}', [TransactionController::class, 'destroy']);
    Route::get('/transactions/grouped/day', [TransactionController::class, 'groupedByDay']);

    // Summary routes
    Route::get('/summary/daily', [SummaryController::class, 'daily']);
    Route::get('/summary/monthly', [SummaryController::class, 'monthly']);
    Route::get('/summary/category', [SummaryController::class, 'category']);
    Route::get('/summary/monthly-by-day', [SummaryController::class, 'monthlyByDay']);
});
