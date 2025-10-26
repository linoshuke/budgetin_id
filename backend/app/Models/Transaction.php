<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Transaction extends Model
{
    use HasFactory;

    protected $fillable = [
        'wallet_id',
        'description',
        'amount',
        'type',
        'transactionDate',
    ];

    /**
     * Sebuah Transaction dimiliki oleh satu Wallet.
     */
    public function wallet()
    {
        return $this->belongsTo(Wallet::class);
    }
}