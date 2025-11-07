<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;

class WalletController extends Controller
{
    /**
     * Mengambil semua wallet milik user yang sedang login.
     */
    public function index(Request $request)
    {
        $user = $request->user();
        return response()->json($user->wallets);
    }
}