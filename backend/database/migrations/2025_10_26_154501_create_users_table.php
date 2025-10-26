<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('users', function (Blueprint $table) {
            // Kita gunakan UID dari Firebase sebagai Primary Key
            $table->string('id')->primary(); 
            $table->string('displayName');
            $table->string('email')->unique();
            $table->text('photoURL')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('users');
    }
};