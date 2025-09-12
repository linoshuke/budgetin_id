// lib/pages/auth/auth_wrapper.dart
import 'package:budgetin_id/pages/home_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'service/auth_service.dart'; // Pastikan path benar
import 'package:provider/provider.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // Saat sedang memeriksa status auth
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Jika ada user (baik anonim maupun permanen)
        if (snapshot.hasData) {
          return const HomePage();
        } 
        
        // Jika TIDAK ada user, otomatis login sebagai anonim
        else {
          return FutureBuilder<User?>(
            future: authService.signInAnonymously(),
            builder: (context, futureSnapshot) {
              // Jika login anonim gagal, tampilkan pesan error
              if (futureSnapshot.hasError) {
                return const Scaffold(
                  body: Center(
                    child: Text('Gagal memulai sesi. Silakan coba lagi nanti.'),
                  ),
                );
              }
              // Selama proses login anonim, tampilkan loading
              // Setelah berhasil, StreamBuilder di atas akan dipicu lagi dan
              // akan menampilkan HomePage.
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            },
          );
        }
      },
    );
  }
}