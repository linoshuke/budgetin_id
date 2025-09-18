// lib/pages/auth/signup_screen.dart (FIXED)

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:budgetin_id/pages/auth/email_verification.dart'; 
import 'package:budgetin_id/pages/auth/service/auth_service.dart';
import 'package:budgetin_id/pages/usageservice.dart'; 

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  // [BARU] State untuk visibilitas konfirmasi password
  bool _isConfirmPasswordVisible = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ... (Fungsi _setLoading dan _handleSignUp tetap sama, tidak perlu diubah)
  void _setLoading(bool value) {
    if (mounted) {
      setState(() {
        _isLoading = value;
      });
    }
  }
  
   Future<void> _handleSignUp() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    _setLoading(true);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final username = _usernameController.text.trim();

    try {
      final User? user = await _authService.signUpWithEmailAndPassword(
        email,
        password,
        username,
      );

      if (mounted && user != null) {
        // Pendaftaran berhasil sepenuhnya, lanjutkan seperti biasa
        _navigateToVerification();
      }
    } on FirebaseAuthException catch (e) {
      // Jika errornya adalah karena terlalu banyak request (blokir keamanan)
      if (e.code == 'too-many-requests' && mounted) {
        // Kita curiga user sudah dibuat tapi respons diblokir.
        // Mari kita coba login untuk memverifikasi.
        await _trySignInAfterSignUpFailure(email, password);
      } else {
        // Untuk error lain (email sudah ada, password lemah, dll), tampilkan pesan seperti biasa
        String message;
        switch (e.code) {
          case 'weak-password':
            message = 'Password yang dimasukkan terlalu lemah.';
            break;
          case 'email-already-in-use':
            message = 'Email ini sudah terdaftar. Silakan login.';
            break;
          case 'invalid-email':
            message = 'Format email tidak valid.';
            break;
          default:
            message = 'Registrasi gagal: ${e.message}';
        }
        _showErrorSnackBar(message);
      }
    } on UsageLimitExceededException catch (e) {
      _showErrorSnackBar(e.message, isWarning: true);
    } finally {
      _setLoading(false);
    }
  }

 Future<void> _trySignInAfterSignUpFailure(String email, String password) async {
    try {
      // Coba login dengan kredensial yang sama
      final user = await _authService.signInWithEmailAndPassword(email, password);
      if (user != null && mounted) {
        // Jika login berhasil, berarti user memang sudah dibuat.
        // Lanjutkan alur ke verifikasi email. Masalah teratasi!
        _navigateToVerification();
      }
    } catch (_) {
      // Jika login juga gagal, berarti memang ada masalah.
      // Tampilkan pesan error yang lebih relevan kepada user.
      _showErrorSnackBar(
        "Registrasi diblokir karena aktivitas tidak wajar. Silakan coba lagi nanti."
      );
    }
  }

  void _navigateToVerification() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const EmailVerificationScreen(),
      ),
    );
  }

  void _showErrorSnackBar(String message, {bool isWarning = false}) {
     if (!mounted) return;
     ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isWarning 
            ? Colors.orange.shade700 
            : Theme.of(context).colorScheme.error,
        ),
      );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.person_add_alt_1_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Buat Akun Baru',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Daftar untuk mulai mengelola keuanganmu.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
              const SizedBox(height: 32),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _usernameController,
                      keyboardType: TextInputType.name,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().length < 3) {
                          return 'Username minimal harus 3 karakter';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        if (value == null ||
                            value.isEmpty ||
                            !value.contains('@')) {
                          return 'Masukkan email yang valid';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'Password minimal harus 6 karakter';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      // [REVISI] Menggunakan state-nya sendiri
                      obscureText: !_isConfirmPasswordVisible,
                      decoration: InputDecoration( // [REVISI] Menambahkan decoration
                        labelText: 'Konfirmasi Password',
                        prefixIcon: const Icon(Icons.lock_person_outlined),
                        // [BARU] Menambahkan suffixIcon untuk toggle visibilitas
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isConfirmPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return 'Password tidak cocok';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // ... (Sisa widget build tetap sama)
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                FilledButton(
                  onPressed: _handleSignUp,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Daftar', style: TextStyle(fontSize: 16)),
                ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Sudah punya akun?"),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Login di sini'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}