import 'dart:async';
import 'package:flutter/material.dart';
import 'auth/service/auth_service.dart';

class VerifyEmailScreen extends StatefulWidget {
  // Tambahkan callback untuk memberi tahu induknya jika sudah terverifikasi
  final VoidCallback onVerified;
  
  const VerifyEmailScreen({super.key, required this.onVerified});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  bool _isEmailVerified = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _isEmailVerified = _authService.currentUser?.emailVerified ?? false;

    if (!_isEmailVerified) {
      _authService.currentUser?.sendEmailVerification();
      _timer = Timer.periodic(const Duration(seconds: 3), (_) => _checkEmailVerified());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkEmailVerified();
    }
  }

  Future<void> _checkEmailVerified() async {
    await _authService.currentUser?.reload();
    
    // Periksa ulang status setelah reload
    final isVerifiedNow = _authService.currentUser?.emailVerified ?? false;

    if (isVerifiedNow) {
      _timer?.cancel();
      // Panggil callback untuk memicu navigasi di widget induk
      widget.onVerified();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tampilan screen tidak perlu menampilkan loading lagi, karena navigasi akan segera terjadi.
    // Namun, kita tetap bisa menampilkannya sebagai fallback.
    return Scaffold(
      appBar: AppBar(title: const Text('Verifikasi Email Anda')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.mark_email_read_outlined, size: 80, color: Colors.indigo),
              const SizedBox(height: 24),
              const Text('Verifikasi Email Anda', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text(
                'Link verifikasi telah dikirim ke:\n${_authService.currentUser?.email}\n\nSilakan periksa inbox atau folder spam Anda untuk melanjutkan.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 32),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 24),
              const Text(
                'Menunggu verifikasi... Anda akan diarahkan secara otomatis.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.send_rounded),
                label: const Text('Kirim Ulang Email'),
                onPressed: () {
                  _authService.currentUser?.sendEmailVerification();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Email verifikasi telah dikirim ulang.")));
                },
              ),
              TextButton(
                onPressed: () => _authService.signOut(),
                child: const Text('Batal / Salah Email?', style: TextStyle(color: Colors.red)),
              )
            ],
          ),
        ),
      ),
    );
  }
}