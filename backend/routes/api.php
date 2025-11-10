<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\TransactionController;
use App\Http\Controllers\Api\WalletController;

// Endpoint yang memerlukan autentikasi Firebase
Route::middleware('firebase.auth')->group(function () {

    Route::get('/user', function (Request $request) {
        return $request->user();
    });

    Route::get('/wallets', [WalletController::class, 'index']);

    Route::get('/transactions', [TransactionController::class, 'index']);
});