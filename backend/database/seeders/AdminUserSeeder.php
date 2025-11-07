<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash; // <-- Pastikan ini di-import
use App\Models\User;
use Illuminate\Support\Str;

class AdminUserSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        User::updateOrCreate(
            ['email' => 'admin@budgetin.com'],
            [
                'id' => 'admin-local-01', 
                'displayName' => 'Admin Budgetin',
                'password' => Hash::make('password'), 
            ]
        );
    }
}