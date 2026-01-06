<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Transaction;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class TransactionController extends Controller
{
    /**
     * Get all transactions with optional filters.
     */
    public function index(Request $request): JsonResponse
    {
        $request->validate([
            'wallet_id' => ['sometimes', 'integer', 'exists:wallets,id'],
            'wallet_ids' => ['sometimes', 'array'],
            'wallet_ids.*' => ['integer', 'exists:wallets,id'],
            'start_date' => ['sometimes', 'date'],
            'end_date' => ['sometimes', 'date', 'after_or_equal:start_date'],
            'type' => ['sometimes', 'string', 'in:income,expense'],
        ]);

        try {
            $user = $request->user();
            $walletIds = $user->wallets()->pluck('id');

            $query = Transaction::whereIn('wallet_id', $walletIds);

            // Filter by specific wallet
            if ($request->has('wallet_id')) {
                $query->where('wallet_id', $request->wallet_id);
            }

            // Filter by multiple wallets
            if ($request->has('wallet_ids')) {
                $query->whereIn('wallet_id', $request->wallet_ids);
            }

            // Filter by date range
            if ($request->has('start_date') && $request->has('end_date')) {
                $query->whereBetween('transactionDate', [
                    $request->start_date . ' 00:00:00',
                    $request->end_date . ' 23:59:59'
                ]);
            }

            // Filter by type
            if ($request->has('type')) {
                $query->where('type', $request->type);
            }

            $transactions = $query->orderBy('transactionDate', 'desc')->get();

            return response()->json([
                'success' => true,
                'message' => 'Data transaksi berhasil diambil.',
                'data' => $transactions
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
     * Create a new transaction.
     */
    public function store(Request $request): JsonResponse
    {
        $request->validate([
            'wallet_id' => ['required', 'integer', 'exists:wallets,id'],
            'description' => ['required', 'string', 'max:255'],
            'amount' => ['required', 'numeric', 'min:0.01'],
            'type' => ['required', 'string', 'in:income,expense'],
            'transactionDate' => ['sometimes', 'date'],
        ]);

        try {
            $user = $request->user();
            $wallet = $user->wallets()->findOrFail($request->wallet_id);

            // Create transaction
            $transaction = Transaction::create([
                'wallet_id' => $wallet->id,
                'description' => $request->description,
                'amount' => $request->amount,
                'type' => $request->type,
                'transactionDate' => $request->transactionDate ?? now(),
            ]);

            // Update wallet balance
            $amountChange = $request->type === 'income' 
                ? $request->amount 
                : -$request->amount;
            $wallet->balance += $amountChange;
            $wallet->save();

            return response()->json([
                'success' => true,
                'message' => 'Transaksi berhasil ditambahkan.',
                'data' => [
                    'transaction' => $transaction,
                    'wallet_balance' => $wallet->balance,
                ]
            ], 201);
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
     * Get a specific transaction.
     */
    public function show(Request $request, int $id): JsonResponse
    {
        try {
            $user = $request->user();
            $walletIds = $user->wallets()->pluck('id');

            $transaction = Transaction::whereIn('wallet_id', $walletIds)
                ->findOrFail($id);

            return response()->json([
                'success' => true,
                'message' => 'Data transaksi berhasil diambil.',
                'data' => $transaction
            ], 200);
        } catch (\Illuminate\Database\Eloquent\ModelNotFoundException $e) {
            return response()->json([
                'success' => false,
                'message' => 'Transaksi tidak ditemukan.',
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
     * Delete a transaction.
     */
    public function destroy(Request $request, int $id): JsonResponse
    {
        try {
            $user = $request->user();
            $walletIds = $user->wallets()->pluck('id');

            $transaction = Transaction::whereIn('wallet_id', $walletIds)
                ->findOrFail($id);

            // Revert wallet balance
            $wallet = $transaction->wallet;
            $amountChange = $transaction->type === 'income' 
                ? -$transaction->amount 
                : $transaction->amount;
            $wallet->balance += $amountChange;
            $wallet->save();

            $transaction->delete();

            return response()->json([
                'success' => true,
                'message' => 'Transaksi berhasil dihapus.',
                'data' => [
                    'wallet_balance' => $wallet->balance,
                ]
            ], 200);
        } catch (\Illuminate\Database\Eloquent\ModelNotFoundException $e) {
            return response()->json([
                'success' => false,
                'message' => 'Transaksi tidak ditemukan.',
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
     * Get transactions grouped by day for a specific wallet and month.
     */
    public function groupedByDay(Request $request): JsonResponse
    {
        $request->validate([
            'wallet_id' => ['required', 'integer', 'exists:wallets,id'],
            'year' => ['sometimes', 'integer', 'min:2000', 'max:2100'],
            'month' => ['sometimes', 'integer', 'min:1', 'max:12'],
        ]);

        try {
            $user = $request->user();
            $wallet = $user->wallets()->findOrFail($request->wallet_id);

            $year = $request->get('year', now()->year);
            $month = $request->get('month', now()->month);

            $start = now()->setYear($year)->setMonth($month)->startOfMonth();
            $end = $start->copy()->endOfMonth();

            $transactions = $wallet->transactions()
                ->whereBetween('transactionDate', [$start, $end])
                ->orderBy('transactionDate')
                ->get();

            // Group by day
            $grouped = [];
            foreach ($transactions as $transaction) {
                $day = $transaction->transactionDate->day;
                if (!isset($grouped[$day])) {
                    $grouped[$day] = [];
                }
                $grouped[$day][] = $transaction;
            }

            return response()->json([
                'success' => true,
                'message' => 'Data transaksi berhasil diambil.',
                'data' => $grouped
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