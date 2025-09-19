// lib/pages/statistics_page.dart
import 'package:budgetin_id/pages/account_page.dart';
import 'package:budgetin_id/pages/auth/service/auth_service.dart';
import 'package:budgetin_id/pages/auth/service/lock.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: context.read<AuthService>().authStateChanges,
      builder: (context, authSnapshot) {
        final bool isLoggedIn = authSnapshot.hasData && authSnapshot.data != null;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Statistik'),
            actions: const [AccountPage()],
          ),
          body: isLoggedIn
              // [KONTEN ASLI] Tampilkan konten jika sudah login
              ? const Center(
                  child: Text('Halaman Statistik & Grafik'),
                )
              // [KONTEN PENGGANTI] Tampilkan prompt jika belum login
              : const LockWidget(
                  featureName: "Statistik",
                  featureIcon: Icons.bar_chart_rounded,
                ),
        );
      },
    );
  }
}