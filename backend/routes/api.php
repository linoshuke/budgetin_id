<?php

// routes/api.php
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

Route::middleware('firebase.auth')->group(function () {
    // Semua rute di sini akan dilindungi
    Route::get('/user', function (Request $request) {
        return $request->user();
    });

    // Contoh rute untuk mengambil data wallet
    Route::get('/wallets', function (Request $request) {
        return $request->user()->wallets;
    });
});