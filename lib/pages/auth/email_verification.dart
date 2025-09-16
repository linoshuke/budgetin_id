// lib/pages/auth/email_verification_screen.dart (FIXED TIMER LOGIC)

import 'dart:async';
import 'package:budgetin_id/pages/auth/service/auth_service.dart'; // Pastikan path benar
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final int _resendCooldown = 30; // Durasi cooldown dalam detik
  
  // [REVISI] Variabel untuk mengelola state cooldown
  Timer? _checkVerificationTimer;
  Timer? _uiUpdateTimer;
  DateTime? _resendAvailableTime;

  @override
  void initState() {
    super.initState();
    _startCooldown();

    // Timer ini hanya untuk memeriksa status verifikasi email
    _checkVerificationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      FirebaseAuth.instance.currentUser?.reload();
      final user = FirebaseAuth.instance.currentUser;
      
      if (user?.emailVerified ?? false) {
        timer.cancel();
        _uiUpdateTimer?.cancel();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verifikasi berhasil! Selamat datang.'),
              backgroundColor: Colors.green,
            ),
          );
        }
        // AuthWrapper di main.dart akan menangani navigasi secara otomatis
      }
    });
  }

  // [REVISI] Logika untuk memulai cooldown dan memperbarui UI
  void _startCooldown() {
    _uiUpdateTimer?.cancel(); // Batalkan timer UI sebelumnya jika ada
    
    setState(() {
      // Set waktu kapan tombol bisa ditekan lagi
      _resendAvailableTime = DateTime.now().add(Duration(seconds: _resendCooldown));
    });

    // Timer ini hanya untuk memperbarui tampilan setiap detik
    _uiUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Panggil setState untuk me-render ulang widget dengan sisa waktu yang baru
      if (mounted) {
        setState(() {});
      } else {
        timer.cancel();
      }
      
      // Jika waktu cooldown sudah habis, hentikan timer ini
      final remaining = _resendAvailableTime?.difference(DateTime.now()).inSeconds ?? 0;
      if (remaining <= 0) {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _checkVerificationTimer?.cancel();
    _uiUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _resendVerificationEmail() async {
    final remainingSeconds = _resendAvailableTime?.difference(DateTime.now()).inSeconds ?? 0;
    if (remainingSeconds > 0) return; // Keluar jika masih dalam cooldown

    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link verifikasi baru telah dikirim.'),
            backgroundColor: Colors.blue,
          ),
        );
        _startCooldown(); // Mulai cooldown lagi dari awal
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
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? 'email Anda';

    // [REVISI] Hitung sisa waktu pada setiap build
    final remainingSeconds = _resendAvailableTime?.difference(DateTime.now()).inSeconds ?? 0;
    final bool canResend = remainingSeconds <= 0;

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
                // [REVISI] Teks dan state tombol berdasarkan sisa waktu
                label: Text(canResend
                    ? 'Kirim Ulang Email' 
                    : 'Kirim Ulang dalam $remainingSeconds detik'),
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