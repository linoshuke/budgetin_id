<?php

use App\Http\Controllers\Api\TransactionController;
use App\Http\Controllers\Api\WalletController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

// Semua rute di dalam grup ini akan dilindungi oleh middleware Firebase.
Route::middleware('firebase.auth')->group(function () {
    
    // Rute untuk mendapatkan data user yang sedang login
    Route::get('/user', function (Request $request) {
        return $request->user();
    });

    // Rute untuk mendapatkan data wallet milik user
    Route::get('/wallets', [WalletController::class, 'index']);

    // Rute untuk mendapatkan data transaksi milik user
    Route::get('/transactions', [TransactionController::class, 'index']);

});