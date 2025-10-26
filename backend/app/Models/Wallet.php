<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Wallet extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'walletName',
        'category',
        'location',
        'balance',
        'displayPreference',
    ];

    /**
     * Sebuah Wallet dimiliki oleh satu User.
     */
    public function user()
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Sebuah Wallet memiliki banyak Transaction.
     */
    public function transactions()
    {
        return $this->hasMany(Transaction::class);
    }
}