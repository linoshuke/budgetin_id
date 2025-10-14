// lib/pages/auth/email_verification_screen.dart (MERGED & OPTIMIZED)

import 'dart:async';
import 'package:budgetin_id/pages/home_screen.dart';
import 'package:budgetin_id/pages/auth/service/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

// Menggabungkan logika efisien dari WidgetsBindingObserver dengan UI yang lebih baik
class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with WidgetsBindingObserver {
  final int _resendCooldown = 60; // Cooldown 60 detik untuk mencegah spam
  Timer? _checkVerificationTimer;
  Timer? _cooldownTimer;
  int _remainingCooldown = 0;

  @override
  void initState() {
    super.initState();
    // Daftarkan observer untuk memantau siklus hidup aplikasi
    WidgetsBinding.instance.addObserver(this);

    // Kirim email verifikasi saat halaman pertama kali dibuka, jika diperlukan
    if (!(FirebaseAuth.instance.currentUser?.emailVerified ?? false)) {
      FirebaseAuth.instance.currentUser?.sendEmailVerification();
      _startCooldown();
    }

    // Timer ini berfungsi sebagai fallback jika pengecekan saat resume gagal
    _checkVerificationTimer =
        Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkEmailVerified(isFromTimer: true);
    });
  }

  @override
  void dispose() {
    // Pastikan untuk menghapus observer dan membatalkan semua timer
    WidgetsBinding.instance.removeObserver(this);
    _checkVerificationTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  /// [OPTIMASI UTAMA]
  /// Fungsi ini dipanggil setiap kali state aplikasi berubah (misal: dari background ke foreground).
  /// Ini adalah momen terbaik untuk memeriksa status verifikasi setelah pengguna mengklik link di email.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint("App resumed. Checking email verification status...");
      _checkEmailVerified();
    }
  }

  /// Memeriksa status verifikasi email pengguna.
  Future<void> _checkEmailVerified({bool isFromTimer = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    // Panggil reload() untuk mendapatkan status user terbaru dari server Firebase.
    await user?.reload();

    // Jika dipanggil dari timer dan email belum terverifikasi, jangan lakukan apa-apa.
    if (isFromTimer && !(user?.emailVerified ?? false)) return;

    if (user?.emailVerified ?? false) {
      // Hentikan semua timer jika verifikasi berhasil
      _checkVerificationTimer?.cancel();
      _cooldownTimer?.cancel();

      // Pastikan widget masih ada di tree sebelum menavigasi
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verifikasi berhasil! Selamat datang.'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigasi ke HomePage dan hapus semua halaman sebelumnya (login, signup, verify)
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomePage()),
          (Route<dynamic> route) => false,
        );
      }
    }
  }

  /// Memulai timer cooldown untuk tombol kirim ulang email.
  void _startCooldown() {
    _remainingCooldown = _resendCooldown;
    _cooldownTimer?.cancel(); // Batalkan timer lama jika ada
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      if (_remainingCooldown > 0) {
        setState(() => _remainingCooldown--);
      } else {
        timer.cancel();
        setState(() {});
      }
    });
  }

  /// Mengirim ulang email verifikasi.
  Future<void> _resendVerificationEmail() async {
    if (_remainingCooldown > 0) return;

    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link verifikasi baru telah dikirim.'),
            backgroundColor: Colors.blue,
          ),
        );
        _startCooldown(); // Mulai cooldown lagi
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim email: ${e.message}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? 'email Anda';
    final bool canResend = _remainingCooldown <= 0;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.mark_email_read_outlined,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Verifikasi Email Anda',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Text.rich(
                TextSpan(
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: Colors.grey.shade700, height: 1.5),
                  children: [
                    const TextSpan(
                        text: 'Kami telah mengirimkan link verifikasi ke\n'),
                    TextSpan(
                      text: userEmail,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Silakan periksa folder inbox atau spam Anda.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                icon: const Icon(Icons.send_rounded),
                label: Text(canResend
                    ? 'Kirim Ulang Email'
                    : 'Kirim Ulang dalam $_remainingCooldown detik'),
                onPressed: canResend ? _resendVerificationEmail : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Batal & Logout'),
                onPressed: () async {
                  await context.read<AuthService>().signOut();
                },
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}