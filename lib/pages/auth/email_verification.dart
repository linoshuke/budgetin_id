// lib/pages/auth/email_verification_screen.dart (FIXED)

import 'dart:async';
import 'package:budgetin_id/pages/auth/service/auth_service.dart'; // Pastikan path benar
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// [FIX] Constructor diubah menjadi tidak memerlukan parameter 'user'
class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key, });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  Timer? _timer;
  bool _canResendEmail = false;
  final int _resendCooldown = 30;
  int _cooldownTimer = 30;

  @override
  void initState() {
    super.initState();
    _startCooldown();

    // Mulai timer untuk memeriksa status verifikasi secara berkala
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      // Selalu reload user terbaru dari Firebase untuk mendapatkan status emailVerified
      FirebaseAuth.instance.currentUser?.reload();
      final user = FirebaseAuth.instance.currentUser;
      
      // AuthWrapper di main.dart akan menangani navigasi otomatis
      // ketika status emailVerified berubah, jadi halaman ini tidak perlu navigasi.
      if (user?.emailVerified ?? false) {
        timer.cancel();
        // Tampilkan pesan sukses sebelum AuthWrapper memindahkan halaman
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verifikasi berhasil! Selamat datang.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    });
  }

  void _startCooldown() {
    setState(() {
      _cooldownTimer = _resendCooldown;
      _canResendEmail = false;
    });
    
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_cooldownTimer > 0) {
        setState(() {
          _cooldownTimer--;
        });
      } else {
        setState(() {
          _canResendEmail = true;
        });
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _resendVerificationEmail() async {
    if (!_canResendEmail) return;

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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim email: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mengambil email user dengan aman dari instance FirebaseAuth
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? 'email Anda';

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
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey.shade700, height: 1.5
                      ),
                  children: [
                    const TextSpan(text: 'Kami telah mengirimkan link verifikasi ke\n'),
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
                label: Text(_canResendEmail 
                    ? 'Kirim Ulang Email' 
                    : 'Kirim Ulang dalam $_cooldownTimer detik'),
                onPressed: _resendVerificationEmail,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Batal & Logout'),
                onPressed: () async {
                  // Cukup panggil signOut, AuthWrapper akan menangani sisanya
                  await context.read<AuthService>().signOut();
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}