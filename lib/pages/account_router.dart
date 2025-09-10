import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '/pages/auth/login_screen.dart';
import '/pages/setting_page.dart';
import 'auth/service/auth_service.dart';

class AccountRouter extends StatelessWidget {
  const AccountRouter ({super.key});

  @override
  Widget build(BuildContext context) {
    // Gunakan StreamBuilder untuk merespons perubahan status login secara real-time
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        // Tampilkan placeholder kecil saat sedang memuat
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2.0),
            ),
          );
        }

        final user = snapshot.data;

        // Jika user sudah login
        if (user != null) {
          return Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
              },
              child: Tooltip(
                message: 'Pengaturan Akun',
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey.shade300,
                  backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                  child: user.photoURL == null
                      ? Icon(Icons.person, size: 20, color: Colors.grey.shade600)
                      : null,
                ),
              ),
            ),
          );
        }
        
        // Jika user belum login
        else {
          return IconButton(
            icon: const Icon(Icons.person_outline, size: 28),
            tooltip: 'Login atau Daftar',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          );
        }
      },
    );
  }
}