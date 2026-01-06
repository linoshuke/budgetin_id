<?php

namespace App\Providers;

use Illuminate\Support\ServiceProvider;
use Kreait\Firebase\Factory;
use Kreait\Firebase\Contract\Auth as FirebaseAuthContract;

class FirebaseServiceProvider extends ServiceProvider
{
    /**
     * Register services.
     */
    public function register(): void
    {
        $this->app->singleton(FirebaseAuthContract::class, function ($app) {
            // Ambil path relatif dari file config
            $credentialsRelativePath = config('services.firebase.credentials');

            if (!$credentialsRelativePath) {
                throw new \InvalidArgumentException('Path kredensial Firebase belum diatur di config/services.php atau file .env.');
            }
            $credentialsAbsolutePath = base_path($credentialsRelativePath);
            if (!file_exists($credentialsAbsolutePath)) {
                throw new \InvalidArgumentException("File kredensial Firebase tidak ditemukan di path: " . $credentialsAbsolutePath);
            }

            $factory = (new Factory)->withServiceAccount($credentialsAbsolutePath);

            return $factory->createAuth();
        });
        $this->app->alias(FirebaseAuthContract::class, 'firebase.auth');
    }
    public function boot(): void
    {
        //
    }
}