<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Transaction;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class SummaryController extends Controller
{
    /**
     * Get daily summary (income/expense for today).
     */
    public function daily(Request $request): JsonResponse
    {
        $request->validate([
            'wallet_ids' => ['sometimes', 'array'],
            'wallet_ids.*' => ['integer', 'exists:wallets,id'],
        ]);

        try {
            $user = $request->user();
            $walletIds = $request->has('wallet_ids') 
                ? $request->wallet_ids 
                : $user->wallets()->pluck('id')->toArray();

            // Filter to only user's wallets
            $userWalletIds = $user->wallets()->pluck('id')->toArray();
            $walletIds = array_intersect($walletIds, $userWalletIds);

            $start = now()->startOfDay();
            $end = now()->endOfDay();

            $transactions = Transaction::whereIn('wallet_id', $walletIds)
                ->whereBetween('transactionDate', [$start, $end])
                ->get();

            $income = $transactions->where('type', 'income')->sum('amount');
            $expense = $transactions->where('type', 'expense')->sum('amount');

            return response()->json([
                'success' => true,
                'message' => 'Summary harian berhasil diambil.',
                'data' => [
                    'income' => (float) $income,
                    'expense' => (float) $expense,
                    'difference' => (float) ($income - $expense),
                    'date' => now()->toDateString(),
                ]
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
     * Get monthly summary (income/expense for this month).
     */
    public function monthly(Request $request): JsonResponse
    {
        $request->validate([
            'wallet_ids' => ['sometimes', 'array'],
            'wallet_ids.*' => ['integer', 'exists:wallets,id'],
            'year' => ['sometimes', 'integer', 'min:2000', 'max:2100'],
            'month' => ['sometimes', 'integer', 'min:1', 'max:12'],
        ]);

        try {
            $user = $request->user();
            $walletIds = $request->has('wallet_ids') 
                ? $request->wallet_ids 
                : $user->wallets()->pluck('id')->toArray();

            // Filter to only user's wallets
            $userWalletIds = $user->wallets()->pluck('id')->toArray();
            $walletIds = array_intersect($walletIds, $userWalletIds);

            $year = $request->get('year', now()->year);
            $month = $request->get('month', now()->month);

            $start = now()->setYear($year)->setMonth($month)->startOfMonth();
            $end = $start->copy()->endOfMonth();

            $transactions = Transaction::whereIn('wallet_id', $walletIds)
                ->whereBetween('transactionDate', [$start, $end])
                ->get();

            $income = $transactions->where('type', 'income')->sum('amount');
            $expense = $transactions->where('type', 'expense')->sum('amount');

            return response()->json([
                'success' => true,
                'message' => 'Summary bulanan berhasil diambil.',
                'data' => [
                    'income' => (float) $income,
                    'expense' => (float) $expense,
                    'difference' => (float) ($income - $expense),
                    'year' => $year,
                    'month' => $month,
                ]
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
     * Get expense breakdown by category for the current month.
     */
    public function category(Request $request): JsonResponse
    {
        $request->validate([
            'wallet_ids' => ['sometimes', 'array'],
            'wallet_ids.*' => ['integer', 'exists:wallets,id'],
            'year' => ['sometimes', 'integer', 'min:2000', 'max:2100'],
            'month' => ['sometimes', 'integer', 'min:1', 'max:12'],
        ]);

        try {
            $user = $request->user();
            $walletIds = $request->has('wallet_ids') 
                ? $request->wallet_ids 
                : $user->wallets()->pluck('id')->toArray();

            // Filter to only user's wallets
            $userWalletIds = $user->wallets()->pluck('id')->toArray();
            $walletIds = array_intersect($walletIds, $userWalletIds);

            $year = $request->get('year', now()->year);
            $month = $request->get('month', now()->month);

            $start = now()->setYear($year)->setMonth($month)->startOfMonth();
            $end = $start->copy()->endOfMonth();

            $transactions = Transaction::whereIn('wallet_id', $walletIds)
                ->where('type', 'expense')
                ->whereBetween('transactionDate', [$start, $end])
                ->get();

            // Group by description (category)
            $categoryExpenses = [];
            foreach ($transactions as $transaction) {
                $category = $transaction->description;
                if (!isset($categoryExpenses[$category])) {
                    $categoryExpenses[$category] = 0;
                }
                $categoryExpenses[$category] += (float) $transaction->amount;
            }

            // Sort by amount descending
            arsort($categoryExpenses);

            return response()->json([
                'success' => true,
                'message' => 'Breakdown kategori berhasil diambil.',
                'data' => [
                    'categories' => $categoryExpenses,
                    'total' => array_sum($categoryExpenses),
                    'year' => $year,
                    'month' => $month,
                ]
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
     * Get monthly transaction summary grouped by day.
     */
    public function monthlyByDay(Request $request): JsonResponse
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

            // Group by day with income/expense totals
            $dailyTotals = [];
            foreach ($transactions as $transaction) {
                $day = $transaction->transactionDate->day;
                if (!isset($dailyTotals[$day])) {
                    $dailyTotals[$day] = ['income' => 0.0, 'expense' => 0.0];
                }
                if ($transaction->type === 'income') {
                    $dailyTotals[$day]['income'] += (float) $transaction->amount;
                } else {
                    $dailyTotals[$day]['expense'] += (float) $transaction->amount;
                }
            }

            return response()->json([
                'success' => true,
                'message' => 'Summary bulanan per hari berhasil diambil.',
                'data' => [
                    'daily_totals' => $dailyTotals,
                    'year' => $year,
                    'month' => $month,
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
