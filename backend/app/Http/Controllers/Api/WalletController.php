<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class WalletController extends Controller
{
    /**
     * Mengambil semua wallet milik user yang sedang login.
     */
    public function index(Request $request): JsonResponse
    {
        try {
            $user = $request->user();
            $wallets = $user->wallets;

            return response()->json([
                'success' => true,
                'message' => 'Data wallets berhasil diambil.',
                'data'    => $wallets
            ], 200);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Terjadi kesalahan: ' . $e->getMessage(),
                'data'    => null
            ], 500);
        }
    }
}