<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Wallet;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class WalletController extends Controller
{
    /**
     * Get all wallets for the authenticated user.
     */
    public function index(Request $request): JsonResponse
    {
        try {
            $wallets = $request->user()->wallets()
                ->orderBy('created_at', 'asc')
                ->get();

            return response()->json([
                'success' => true,
                'message' => 'Data wallets berhasil diambil.',
                'data' => $wallets
            ], 200);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Terjadi kesalahan: ' . $e->getMessage(),
                'data' => null
            ], 500);
        }
    }

    /**
     * Create a new wallet.
     */
    public function store(Request $request): JsonResponse
    {
        $request->validate([
            'walletName' => ['required', 'string', 'max:255'],
            'category' => ['required', 'string', 'max:255'],
            'location' => ['required', 'string', 'max:255'],
        ]);

        try {
            $wallet = Wallet::create([
                'user_id' => $request->user()->id,
                'walletName' => $request->walletName,
                'category' => $request->category,
                'location' => $request->location,
                'balance' => 0.00,
                'displayPreference' => 'monthly',
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Wallet berhasil dibuat.',
                'data' => $wallet
            ], 201);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Terjadi kesalahan: ' . $e->getMessage(),
                'data' => null
            ], 500);
        }
    }

    /**
     * Get a specific wallet.
     */
    public function show(Request $request, int $id): JsonResponse
    {
        try {
            $wallet = $request->user()->wallets()->findOrFail($id);

            return response()->json([
                'success' => true,
                'message' => 'Data wallet berhasil diambil.',
                'data' => $wallet
            ], 200);
        } catch (\Illuminate\Database\Eloquent\ModelNotFoundException $e) {
            return response()->json([
                'success' => false,
                'message' => 'Wallet tidak ditemukan.',
                'data' => null
            ], 404);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Terjadi kesalahan: ' . $e->getMessage(),
                'data' => null
            ], 500);
        }
    }

    /**
     * Update a wallet.
     */
    public function update(Request $request, int $id): JsonResponse
    {
        $request->validate([
            'walletName' => ['sometimes', 'string', 'max:255'],
            'category' => ['sometimes', 'string', 'max:255'],
            'location' => ['sometimes', 'string', 'max:255'],
            'displayPreference' => ['sometimes', 'string', 'in:daily,monthly'],
        ]);

        try {
            $wallet = $request->user()->wallets()->findOrFail($id);

            if ($request->has('walletName')) {
                $wallet->walletName = $request->walletName;
            }
            if ($request->has('category')) {
                $wallet->category = $request->category;
            }
            if ($request->has('location')) {
                $wallet->location = $request->location;
            }
            if ($request->has('displayPreference')) {
                $wallet->displayPreference = $request->displayPreference;
            }

            $wallet->save();

            return response()->json([
                'success' => true,
                'message' => 'Wallet berhasil diperbarui.',
                'data' => $wallet
            ], 200);
        } catch (\Illuminate\Database\Eloquent\ModelNotFoundException $e) {
            return response()->json([
                'success' => false,
                'message' => 'Wallet tidak ditemukan.',
                'data' => null
            ], 404);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Terjadi kesalahan: ' . $e->getMessage(),
                'data' => null
            ], 500);
        }
    }

    /**
     * Delete a wallet and its transactions.
     */
    public function destroy(Request $request, int $id): JsonResponse
    {
        try {
            $wallet = $request->user()->wallets()->findOrFail($id);
            
            // Transactions will be deleted via cascade
            $wallet->delete();

            return response()->json([
                'success' => true,
                'message' => 'Wallet berhasil dihapus.',
                'data' => null
            ], 200);
        } catch (\Illuminate\Database\Eloquent\ModelNotFoundException $e) {
            return response()->json([
                'success' => false,
                'message' => 'Wallet tidak ditemukan.',
                'data' => null
            ], 404);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Terjadi kesalahan: ' . $e->getMessage(),
                'data' => null
            ], 500);
        }
    }

    /**
     * Create default wallets for the user.
     */
    public function createDefaults(Request $request): JsonResponse
    {
        try {
            $user = $request->user();
            
            // Check if user already has wallets
            if ($user->wallets()->count() > 0) {
                return response()->json([
                    'success' => false,
                    'message' => 'User sudah memiliki wallet.',
                    'data' => null
                ], 400);
            }

            $defaultWallets = [
                ['walletName' => 'Dompet Tunai', 'category' => 'Uang Fisik', 'location' => 'Cash'],
                ['walletName' => 'GoPay', 'category' => 'E-Wallet', 'location' => 'Qris'],
                ['walletName' => 'Rekening Bank', 'category' => 'Tabungan', 'location' => 'Bank'],
            ];

            $createdWallets = [];
            foreach ($defaultWallets as $walletData) {
                $createdWallets[] = Wallet::create([
                    'user_id' => $user->id,
                    'walletName' => $walletData['walletName'],
                    'category' => $walletData['category'],
                    'location' => $walletData['location'],
                    'balance' => 0.00,
                    'displayPreference' => 'monthly',
                ]);
            }

            return response()->json([
                'success' => true,
                'message' => 'Default wallets berhasil dibuat.',
                'data' => $createdWallets
            ], 201);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Terjadi kesalahan: ' . $e->getMessage(),
                'data' => null
            ], 500);
        }
    }

    /**
     * Get wallet statistics (income/expense for the period).
     */
    public function stats(Request $request, int $id): JsonResponse
    {
        $request->validate([
            'preference' => ['sometimes', 'string', 'in:daily,monthly'],
        ]);

        try {
            $wallet = $request->user()->wallets()->findOrFail($id);
            $preference = $request->get('preference', $wallet->displayPreference);

            $now = now();
            if ($preference === 'daily') {
                $start = $now->copy()->startOfDay();
                $end = $now->copy()->endOfDay();
            } else {
                $start = $now->copy()->startOfMonth();
                $end = $now->copy()->endOfMonth();
            }

            $transactions = $wallet->transactions()
                ->whereBetween('transactionDate', [$start, $end])
                ->get();

            $income = $transactions->where('type', 'income')->sum('amount');
            $expense = $transactions->where('type', 'expense')->sum('amount');

            return response()->json([
                'success' => true,
                'message' => 'Statistik wallet berhasil diambil.',
                'data' => [
                    'income' => (float) $income,
                    'expense' => (float) $expense,
                    'balance' => (float) $wallet->balance,
                ]
            ], 200);
        } catch (\Illuminate\Database\Eloquent\ModelNotFoundException $e) {
            return response()->json([
                'success' => false,
                'message' => 'Wallet tidak ditemukan.',
                'data' => null
            ], 404);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Terjadi kesalahan: ' . $e->getMessage(),
                'data' => null
            ], 500);
        }
    }
}