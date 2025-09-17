// lib/pages/auth/email_verification_screen.dart (FIXED NAVIGATION LOGIC)

import 'dart:async';
import 'package:budgetin_id/pages/home_page.dart'; // <-- [BARU] Impor HomePage
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
  final int _resendCooldown = 30;
  Timer? _checkVerificationTimer;
  Timer? _uiUpdateTimer;
  DateTime? _resendAvailableTime;

  @override
  void initState() {
    super.initState();
    _startCooldown();

    // Timer untuk memeriksa status verifikasi email secara berkala
    _checkVerificationTimer =
        Timer.periodic(const Duration(seconds: 3), (timer) async {
      // Selalu reload user object untuk mendapatkan status terbaru dari server
      await FirebaseAuth.instance.currentUser?.reload();
      final user = FirebaseAuth.instance.currentUser;

      // [PERBAIKAN KRUSIAL] Logika navigasi setelah verifikasi berhasil
      if (user?.emailVerified ?? false) {
        timer.cancel(); // Hentikan timer pemeriksa
        _uiUpdateTimer?.cancel(); // Hentikan juga timer UI

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
            (Route<dynamic> route) => false, // Predikat ini menghapus semua route
          );
        }
      }
    });
  }
  
  // Sisa kode di bawah ini (dispose, _startCooldown, _resendVerificationEmail, build)
  // sudah benar dan tidak perlu diubah.
  
  void _startCooldown() {
    _uiUpdateTimer?.cancel(); 
    
    setState(() {
      _resendAvailableTime = DateTime.now().add(Duration(seconds: _resendCooldown));
    });

    _uiUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      } else {
        timer.cancel();
      }
      
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
    if (remainingSeconds > 0) return;

    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link verifikasi baru telah dikirim.'),
            backgroundColor: Colors.blue,
          ),
        );
        _startCooldown(); 
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