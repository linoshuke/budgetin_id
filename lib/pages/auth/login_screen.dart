// lib/pages/login_screen.dart

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:budgetin_id/pages/auth/service/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:budgetin_id/pages/auth/signup_screen.dart';
import 'package:budgetin_id/pages/webviewscreen.dart'; // [BARU] Impor WebViewScreen

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

  // [BARU] Gesture recognizers untuk link
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
    // [BARU] Pastikan untuk dispose recognizer
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  // [BARU] Helper function untuk membuka WebView
  void _openWebView(BuildContext context, String title, String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WebViewScreen(title: title, url: url),
      ),
    );
  }
  
  // ... sisa logika _setLoading, _handleEmailSignIn, _handleGoogleSignIn, _handlePasswordReset tidak berubah ...
  void _setLoading(bool value) { if (mounted) { setState(() { _isLoading = value; }); } }
  Future<void> _handleEmailSignIn() async { if (!_formKey.currentState!.validate()) return; _setLoading(true); try { await _authService.signInWithEmailAndPassword(_emailController.text.trim(),_passwordController.text.trim(),); } on FirebaseAuthException catch (e) { String message; switch (e.code) { case 'user-not-found': case 'invalid-credential': case 'wrong-password': message = 'Email atau password yang Anda masukkan salah.'; break; default: message = 'Login gagal. Pastikan data Anda benar.'; } if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Theme.of(context).colorScheme.error,)); } } finally { _setLoading(false); } }
  Future<void> _handleGoogleSignIn() async { _setLoading(true); try { await _authService.signInWithGoogle(); } catch (e) { if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login dengan Google dibatalkan atau gagal.'))); } } finally { _setLoading(false); } }
  void _handlePasswordReset() { final emailResetController = TextEditingController(); showDialog(context: context, builder: (dialogContext) => AlertDialog(title: const Text("Reset Password"), content: Column(mainAxisSize: MainAxisSize.min, children: [ const Text( "Masukkan email Anda. Link untuk reset password akan dikirim."), const SizedBox(height: 16), TextFormField( controller: emailResetController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration( labelText: "Email", prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder(), ), autofocus: true, ), ]), actions: [ TextButton( onPressed: () => Navigator.of(dialogContext).pop(), child: const Text("Batal")), FilledButton( onPressed: () async { if (emailResetController.text.trim().isEmpty) return; final scaffoldMessenger = ScaffoldMessenger.of(context); Navigator.of(dialogContext).pop(); _setLoading(true); try { await _authService.sendPasswordResetEmail(emailResetController.text.trim()); scaffoldMessenger.showSnackBar( const SnackBar( content: Text( "Link reset telah dikirim. Periksa folder inbox & spam."), backgroundColor: Colors.green, ), ); } catch (e) { scaffoldMessenger.showSnackBar( const SnackBar( content: Text("Gagal mengirim. Pastikan email terdaftar."), backgroundColor: Colors.red, ), ); } finally { if (mounted) { _setLoading(false); } } }, child: const Text("Kirim"), ), ], ), ); }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      // [PERBAIKAN] Tambahkan AppBar dengan tombol kembali
      appBar: AppBar(
        title: const Text('Login Akun'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.account_balance_wallet_rounded,
                  size: 64, color: colorScheme.primary),
              const SizedBox(height: 24),
              Text('Selamat Datang!',
                  textAlign: TextAlign.center,
                  style: textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Login untuk melanjutkan mengelola keuanganmu.',
                  textAlign: TextAlign.center, style: textTheme.bodyLarge),
              const SizedBox(height: 40),
              // ... Form dan tombol login tetap sama
              Form( key: _formKey, child: Column( children: [ TextFormField( controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration( labelText: 'Email', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder()), validator: (value) => (value == null || value.isEmpty) ? 'Email tidak boleh kosong' : null), const SizedBox(height: 16), TextFormField( controller: _passwordController, obscureText: !_isPasswordVisible, decoration: InputDecoration( labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline), border: const OutlineInputBorder(), suffixIcon: IconButton( icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible))), validator: (value) => (value == null || value.isEmpty) ? 'Password tidak boleh kosong' : null), ], ), ),
              Align( alignment: Alignment.centerRight, child: TextButton( onPressed: _isLoading ? null : _handlePasswordReset, child: const Text('Lupa Password?'))), const SizedBox(height: 16), if (_isLoading) const Center(child: CircularProgressIndicator()) else Column( crossAxisAlignment: CrossAxisAlignment.stretch, children: [ FilledButton( onPressed: _handleEmailSignIn, style: FilledButton.styleFrom( padding: const EdgeInsets.symmetric(vertical: 16), ), child: const Text('Masuk', style: TextStyle(fontSize: 16)), ), const SizedBox(height: 16), Row(children: [ const Expanded(child: Divider()), Padding( padding: const EdgeInsets.symmetric(horizontal: 8.0), child: Text('ATAU', style: textTheme.bodySmall ?.copyWith(color: Colors.grey.shade600))), const Expanded(child: Divider()) ]), const SizedBox(height: 16), OutlinedButton.icon( icon: Image.asset('assets/icons/google.png', height: 22.0), label: const Text('Login dengan Google'), onPressed: _handleGoogleSignIn, style: OutlinedButton.styleFrom( padding: const EdgeInsets.symmetric(vertical: 12), ), ), ], ),
              
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text("Belum punya akun?"),
                TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => const SignUpScreen())),
                    child: const Text('Daftar di sini'))
              ]),
              
              const SizedBox(height: 24),
              // [PERBAIKAN] Mengganti tombol 'Kembali' dengan disclaimer
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                    children: [
                      const TextSpan(text: 'Dengan login, Anda menyetujui '),
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
    );
  }
}