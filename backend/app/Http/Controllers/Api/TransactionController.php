<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Transaction;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class TransactionController extends Controller
{
    /**
     * Mengambil semua transaksi dari semua wallet milik user yang login.
     */
    public function index(Request $request): JsonResponse
    {
        try {
            $user = $request->user();

            // Ambil semua ID wallet milik user ini
            $walletIds = $user->wallets()->pluck('id');

            // Ambil semua transaksi yang terkait dengan wallet-wallet tersebut
            $transactions = Transaction::whereIn('wallet_id', $walletIds)
                                ->orderBy('transactionDate', 'desc')
                                ->get();

            return response()->json([
                'success' => true,
                'message' => 'Data transaksi berhasil diambil.',
                'data'    => $transactions
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