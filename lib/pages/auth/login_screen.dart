// lib/pages/login_screen.dart

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:budgetin_id/pages/auth/service/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:budgetin_id/pages/auth/signup_screen.dart';
import 'package:budgetin_id/pages/webviewscreen.dart';
import 'package:budgetin_id/pages/usageservice.dart';
import 'package:budgetin_id/pages/home_screen.dart';

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

  late TapGestureRecognizer _termsRecognizer;
  late TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () {
        _openWebView(
          context,
          'Ketentuan Layanan',
          'https://budgetin-id.web.app/KetentuanLayanan/',
        );
      };
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () {
        _openWebView(
          context,
          'Kebijakan Privasi',
          'https://budgetin-id.web.app/KebijakanPrivacy/',
        );
      };
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  void _openWebView(BuildContext context, String title, String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WebViewScreen(title: title, url: url),
      ),
    );
  }

  void _setLoading(bool value) {
    if (mounted) {
      setState(() {
        _isLoading = value;
      });
    }
  }

  Future<void> _handleEmailSignIn() async {
    if (!_formKey.currentState!.validate() || !mounted) return;
    _setLoading(true);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      await _authService.signInWithEmailAndPassword(email, password);

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomePage()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'invalid-credential':
        case 'user-not-found':
        case 'wrong-password':
          message =
              'Jika Anda mendaftar via Google, silakan gunakan tombol "Masuk dengan Google".';
          break;
        case 'invalid-email':
          message = 'Format email tidak valid.';
          break;
        default:
          message = 'Masuk gagal. Pastikan data Anda benar.';
      }
      if (mounted) _showErrorSnackBar(message);
    } on UsageLimitExceededException catch (e) {
      if (mounted) _showErrorSnackBar(e.message, isWarning: true);
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Terjadi kesalahan yang tidak diketahui.');
      }
    } finally {
      _setLoading(false);
    }
  }

  // [LOGIC DIPERBARUI] Menangani exception baru untuk Google Sign In
  Future<void> _handleGoogleSignIn() async {
    _setLoading(true);
    try {
      final user = await _authService.signInWithGoogle();
      if (user != null && mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomePage()),
          (route) => false,
        );
      }
    } on GoogleSignUpNotAllowedException catch (e) {
      // Menangkap error spesifik jika akun belum terdaftar
      _showErrorSnackBar(e.message);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        _showErrorSnackBar(
          'Email ini sudah terdaftar dengan metode lain.',
        );
      } else {
        _showErrorSnackBar('Masuk dengan Google gagal: ${e.message}');
      }
    } catch (e) {
      if (mounted && e.toString().contains('PlatformException')) {
        if (!e.toString().toLowerCase().contains('canceled') &&
            !e.toString().toLowerCase().contains('dibatalkan')) {
          _showErrorSnackBar('Terjadi kesalahan saat login dengan Google.');
        }
      } else {
        _showErrorSnackBar('Terjadi kesalahan tak terduga.');
      }
    } finally {
      _setLoading(false);
    }
  }

  void _handlePasswordReset({String? prefilledEmail}) {
    final emailResetController = TextEditingController(
      text: prefilledEmail ?? '',
    );
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Reset Password"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Masukkan email Anda. Link untuk reset password akan dikirim.",
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: emailResetController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: "Email",
                prefixIcon: Icon(Icons.email_outlined),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text("Batal"),
          ),
          FilledButton(
            onPressed: () async {
              if (emailResetController.text.trim().isEmpty) return;
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final theme = Theme.of(context);
              Navigator.of(context);
              Navigator.of(dialogContext).pop();
              _setLoading(true);
              try {
                await _authService.sendPasswordResetEmail(
                  emailResetController.text.trim(),
                );
                if (!mounted) return;
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text(
                      "Jika email Anda terdaftar, link reset akan dikirim. Silakan periksa inbox & spam.",
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              } on FirebaseAuthException catch (e) {
                if (!mounted) return;
                String message = "Gagal mengirim permintaan. Coba lagi nanti.";
                if (e.code == 'invalid-email') {
                  message = "Format email yang Anda masukkan tidak valid.";
                } else if (e.code == 'user-not-found') {
                   // Logika ini sudah benar, tidak perlu diubah.
                   // Jika user tidak ditemukan, tawarkan untuk mendaftar.
                  _showErrorSnackBar("Email tidak terdaftar. Silakan buat akun baru.");
                  return;
                }
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(message),
                    backgroundColor: theme.colorScheme.error,
                  ),
                );
              } finally {
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
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: Theme.of(context).colorScheme.onSurface),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: AbsorbPointer(
            absorbing: _isLoading,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 64,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Selamat Datang!',
                  textAlign: TextAlign.center,
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Masuk untuk melanjutkan mengelola keuanganmu.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge,
                ),
                const SizedBox(height: 40),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'Email tidak boleh kosong'
                            : null,
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
                            onPressed: () => setState(
                              () => _isPasswordVisible = !_isPasswordVisible,
                            ),
                          ),
                        ),
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'Password tidak boleh kosong'
                            : null,
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading ? null : () => _handlePasswordReset(prefilledEmail: _emailController.text),
                    child: const Text('Lupa Password?'),
                  ),
                ),
                const SizedBox(height: 16),
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(48.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton(
                        onPressed: _handleEmailSignIn,
                        child: const Text(
                          'Masuk',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                            ),
                            child: Text(
                              'ATAU',
                              style: textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        icon: Image.asset(
                          'assets/icons/google.png',
                          height: 22.0,
                        ),
                        label: const Text('Masuk dengan Google'),
                        onPressed: _handleGoogleSignIn,
                      ),
                    ],
                  ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Belum punya akun?"),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const SignUpScreen(),
                              ),
                            ),
                      child: const Text('Daftar di sini'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                      children: [
                        const TextSpan(text: 'Dengan Masuk, Anda menyetujui '),
                        TextSpan(
                          text: 'Ketentuan Layanan',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: _termsRecognizer,
                        ),
                        const TextSpan(text: ' dan '),
                        TextSpan(
                          text: 'Kebijakan Privasi',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: _privacyRecognizer,
                        ),
                        const TextSpan(text: ' kami.'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}