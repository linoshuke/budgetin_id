<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\WalletController;

Route::middleware(['auth:sanctum'])->get('/user', function (Request $request) {
    return $request->user();
    
});

Route::middleware(['auth:sanctum', 'verified'])->get('/wallets', [WalletController::class, 'index']);

