// lib/pages/history_page.dart
import 'package:flutter/material.dart';
import '/pages/account_router.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat'),
        actions: const [
          AccountActionButton(), // Tambahkan ini
        ],
      ),
      body: const Center(
        child: Text('Halaman Riwayat Transaksi'),
      ),
    );
  }
}