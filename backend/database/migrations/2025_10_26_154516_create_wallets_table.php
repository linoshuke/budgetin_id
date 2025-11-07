<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('wallets', function (Blueprint $table) {
            $table->id();
            // Foreign key yang mengarah ke tabel users
            $table->string('user_id'); 
            $table->foreign('user_id')->references('id')->on('users')->onDelete('cascade');

            $table->string('walletName');
            $table->string('category');
            $table->string('location');
            $table->decimal('balance', 15, 2)->default(0.00);
            $table->string('displayPreference')->default('monthly');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('wallets');
    }
};