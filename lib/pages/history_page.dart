// lib/pages/history_page.dart
import 'package:budgetin_id/pages/auth/service/auth_service.dart';
import 'package:budgetin_id/pages/auth/service/lock.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'account_page.dart';
import 'package:provider/provider.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: context.read<AuthService>().authStateChanges,
      builder: (context, authSnapshot) {
        final bool isLoggedIn =
            authSnapshot.hasData && authSnapshot.data != null;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Riwayat'),
            actions: const [AccountPage()],
          ),
          body: isLoggedIn
              ? const Center(child: Text('Halaman Riwayat Transaksi'))
                : const LockWidget(
                  featureName: "Riwayat",
                  featureIcon: Icons.receipt_long_rounded,
                ),
        );
      },
    );
  }
}
