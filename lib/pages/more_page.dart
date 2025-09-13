// lib/pages/more_page.dart

import 'package:flutter/material.dart';

class MorePage extends StatelessWidget {
  // Terima callback function dari parent 
  final VoidCallback onGoToHome;
    const MorePage({
    super.key,
    required this.onGoToHome,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lainnya'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(8.0),
        children: [
          _buildMenuTile(
            context,
            icon: Icons.calendar_today_outlined,
            title: 'Kalender Transaksi',
            onTap: () {
              // TODO: Implementasi navigasi ke halaman kalender
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Buka halaman kalender...')),
              );
            },
          ), 
          _buildMenuTile(
            context,
            icon: Icons.file_upload_outlined,
            title: 'Ekspor Data',
            onTap: () {
              // TODO: Implementasi fungsi ekspor data
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Mulai proses ekspor data...')),
              );
            },
          ),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.home_filled),
              label: const Text('Kembali ke Beranda'),
              onPressed: onGoToHome, // Panggil callback saat tombol ditekan
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget untuk membuat ListTile yang konsisten
  Widget _buildMenuTile(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: Colors.indigo),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}