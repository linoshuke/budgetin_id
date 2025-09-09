// lib/pages/auth/auth_wrapper.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '/pages/auth/login_screen.dart';
import '/pages/main_screen.dart';
import '/services/auth_service.dart';
import 'package:provider/provider.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          // Jika pengguna sudah login, tampilkan halaman utama
          return const MainScreen();
        } else {
          // Jika belum, tampilkan halaman login
          return const LoginScreen();
        }
      },
    );
  }
}