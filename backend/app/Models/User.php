<?php

namespace App\Models;

// Impor class yang dibutuhkan untuk Filament
use Filament\Models\Contracts\FilamentUser;
use Filament\Panel;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;

// Implementasikan kontrak (interface) FilamentUser
class User extends Authenticatable implements FilamentUser
{
    use HasFactory, Notifiable;

    /**
     * =================================================================
     * BAGIAN UNTUK INTEGRASI DENGAN FILAMENT
     * =================================================================
     */

    /**
     * Metode ini wajib ada dari interface FilamentUser.
     * Fungsinya untuk menentukan apakah seorang user boleh mengakses
     * panel admin Filament atau tidak.
     */
    public function canAccessPanel(Panel $panel): bool
    {
        // Logika sederhana: hanya user dengan email 'admin@budgetin.com'
        // yang boleh masuk ke panel admin.
        return $this->email === 'admin@budgetin.com';
    }


    /**
     * =================================================================
     * BAGIAN UNTUK KOMPATIBILITAS DENGAN FIREBASE AUTH
     * =================================================================
     */

    /**
     * Memberitahu Laravel bahwa Primary Key (kolom 'id') kita
     * bukan angka yang bertambah otomatis (bukan auto-increment).
     *
     * @var bool
     */
    public $incrementing = false;

    /**
     * Memberitahu Laravel bahwa tipe data Primary Key kita adalah 'string',
     * karena kita akan mengisinya dengan UID dari Firebase.
     *
     * @var string
     */
    protected $keyType = 'string';


    /**
     * =================================================================
     * KONFIGURASI MODEL LARAVEL STANDAR
     * =================================================================
     */

    /**
     * Atribut yang boleh diisi secara massal (mass assignable).
     *
     * @var array<int, string>
     */
    protected $fillable = [
        'id',           // Wajib ada karena kita mengisinya manual (Firebase UID / ID admin)
        'displayName',
        'email',
        'photoURL',
        'password',     // Wajib ada agar user admin Filament bisa dibuat dan login
    ];

    /**
     * Atribut yang harus disembunyikan saat model diubah menjadi array atau JSON.
     * Penting untuk keamanan agar password hash tidak terekspos.
     *
     * @var array<int, string>
     */
    protected $hidden = [
        'password',
        'remember_token',
    ];

    /**
     * Atribut yang harus di-cast ke tipe data tertentu.
     * (Untuk saat ini tidak ada yang perlu di-cast secara khusus).
     *
     * @var array<string, string>
     */
    protected $casts = [
        // 'email_verified_at' => 'datetime', // Kita tidak pakai ini
    ];


    /**
     * =================================================================
     * RELASI ELOQUENT
     * =================================================================
     */

    /**
     * Mendefinisikan relasi "one-to-many": satu User memiliki banyak Wallet.
     */
    public function wallets()
    {
        return $this->hasMany(Wallet::class);
    }
}