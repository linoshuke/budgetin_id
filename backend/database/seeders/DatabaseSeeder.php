<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        // Panggil seeder admin di sini
        $this->call([
            AdminUserSeeder::class,
        ]);
    }
}