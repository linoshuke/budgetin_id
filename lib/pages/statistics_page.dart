import 'package:flutter/material.dart';
import '/pages/account_router.dart';

class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistik'),
      actions: const [
          AccountActionButton(), // Tambahkan widget aksi akun
        ],
      ),
      body: const Center(
        child: Text('Halaman Statistik & Grafik'),
      ),
    );
  }
}