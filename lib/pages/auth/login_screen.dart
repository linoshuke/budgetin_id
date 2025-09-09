// lib/pages/login_screen.dart

import 'package:flutter/material.dart';
import '/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/pages/auth/signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _setLoading(bool value) {
    if (mounted) {
      setState(() {
        _isLoading = value;
      });
    }
  }

  // Fungsi login sekarang akan menutup halaman setelah berhasil
  Future<void> _handleEmailSignIn() async {
    if (!_formKey.currentState!.validate()) return;
    _setLoading(true);
    try {
      await _authService.signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      // Jika berhasil, tutup layar login
      if (mounted) Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
        case 'invalid-credential':
        case 'wrong-password':
          message = 'Email atau password yang Anda masukkan salah.';
          break;
        default:
          message = 'Login gagal. Pastikan data Anda benar.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
      }
    } finally {
      _setLoading(false);
    }
  }

  // Fungsi login Google juga akan menutup halaman setelah berhasil
  Future<void> _handleGoogleSignIn() async {
    _setLoading(true);
    try {
      await _authService.signInWithGoogle();
      // Jika berhasil, tutup layar login
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login dengan Google dibatalkan atau gagal.')));
      }
    } finally {
      _setLoading(false);
    }
  }

  void _handlePasswordReset() {
  final emailResetController = TextEditingController();

  // Konteks dialog ini hanya untuk membangun dialog itu sendiri.
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog( // Menggunakan nama variabel baru 'dialogContext' agar lebih jelas
      title: const Text("Reset Password"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text("Masukkan email Anda. Link untuk reset password akan dikirim."),
        const SizedBox(height: 16),
        TextField(controller: emailResetController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: "Email")),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text("Batal")),
        ElevatedButton(
          onPressed: () async {
            if (emailResetController.text.trim().isEmpty) {
              return; // Keluar jika email kosong
            }
            Navigator.of(context);
            final scaffoldMessenger = ScaffoldMessenger.of(context);
            Navigator.of(dialogContext).pop(); 

            _setLoading(true);

            try {
              // --- Ini adalah 'async gap' ---
              await _authService.sendPasswordResetEmail(emailResetController.text.trim());
              // --- Akhir dari 'async gap' ---
              if (mounted) {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text("Link reset telah dikirim. MOHON PERIKSA FOLDER INBOX & SPAM."),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 7),
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text("Gagal mengirim. Pastikan email terdaftar."),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            } finally {
              // Pastikan untuk selalu memeriksa 'mounted' sebelum memanggil setState.
              if (mounted) {
                _setLoading(false);
              }
            }
          },
          child: const Text("Kirim"),
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.account_balance_wallet_rounded, size: 80, color: Colors.indigo),
              const SizedBox(height: 24),
              const Text('Selamat Datang!', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Login untuk melanjutkan mengelola keuanganmu.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 32),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))), validator: (value) => (value == null || value.isEmpty) ? 'Email tidak boleh kosong' : null),
                    const SizedBox(height: 16),
                    TextFormField(controller: _passwordController, obscureText: !_isPasswordVisible, decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline), border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))), suffixIcon: IconButton(icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible))), validator: (value) => (value == null || value.isEmpty) ? 'Password tidak boleh kosong' : null),
                  ],
                ),
              ),
              Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _isLoading ? null : _handlePasswordReset, child: const Text('Lupa Password?'))),
              const SizedBox(height: 10),
              if (_isLoading) const Center(child: CircularProgressIndicator()) else Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(onPressed: _handleEmailSignIn, style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Masuk', style: TextStyle(fontSize: 16))),
                  const SizedBox(height: 16),
                  const Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 8.0), child: Text('ATAU', style: TextStyle(color: Colors.grey))), Expanded(child: Divider())]),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: Image.asset('assets/icons/google.png', height: 22.0),
                    label: const Text('Login dengan Google'),
                    onPressed: _handleGoogleSignIn,
                    style: ElevatedButton.styleFrom(foregroundColor: Colors.black87, backgroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.grey))),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Text("Belum punya akun?"), TextButton(onPressed: _isLoading ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SignUpScreen())), child: const Text('Daftar di sini'))]),
              
              // [BARU] Tombol untuk kembali ke beranda tanpa login
              const SizedBox(height: 8),
              TextButton(
                onPressed: _isLoading ? null : () => Navigator.of(context).pop(), 
                child: const Text('Kembali ke Beranda'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}   