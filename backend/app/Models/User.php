<?php

namespace App\Models;

use Filament\Models\Contracts\FilamentUser;
use Filament\Models\Contracts\HasName; 
use Filament\Panel;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;


class User extends Authenticatable implements FilamentUser, HasName 
{
    use HasApiTokens, HasFactory, Notifiable;
    public function getFilamentName(): string
    {
        return $this->displayName;
    }
    public function canAccessPanel(Panel $panel): bool
    {
        return $this->email === 'admin@budgetin.com';
    }

    public $incrementing = false;

    protected $keyType = 'string';

    protected $fillable = [
        'id',
        'displayName',
        'email',
        'photoURL',
        'password',
    ];
    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected $casts = [
    ];

    public function wallets()
    {
        return $this->hasMany(Wallet::class);
    }
}