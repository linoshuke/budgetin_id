// lib/config/app_config.dart

/// Konfigurasi aplikasi Budgetin
class AppConfig {
  /// Set ke `true` untuk menggunakan Laravel API
  /// Set ke `false` untuk menggunakan Firebase
  static const bool useLaravelApi = true;
  
  /// Base URL untuk Laravel API
  /// Untuk Android Emulator: http://10.0.2.2:8000/api
  /// Untuk iOS Simulator: http://localhost:8000/api  
  /// Untuk device fisik: gunakan IP address komputer Anda, contoh: http://192.168.1.100:8000/api
  static const String laravelApiBaseUrl = 'http://10.0.2.2:8000/api';
}
