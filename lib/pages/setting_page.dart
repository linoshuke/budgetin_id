import 'package:flutter/material.dart';
import '../Providers/setting/setting_provider.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SettingsProvider(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Pengaturan Akun')),
        body: Consumer<SettingsProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final user = provider.user;
            if (user == null) {
              return const Center(
                child: Text('Pengguna tidak ditemukan. Silakan login kembali.'),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildProfileSection(context, provider),
                const SizedBox(height: 24),
                const Divider(),
                _buildAccountManagementSection(context, provider),
                const SizedBox(height: 24),
                const Divider(),
                _buildDangerZone(context, provider),
              ],
            );
          },
        ),
      ),
    );
  }

  // Widget untuk bagian profil
  Widget _buildProfileSection(BuildContext context, SettingsProvider provider) {
    final user = provider.user!;
    return Column(
      children: [
        GestureDetector(
          onTap: () => provider.pickAndUploadProfileImage(),
          child: Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundImage: user.photoURL != null
                    ? NetworkImage(user.photoURL!)
                    : null,
                child: user.photoURL == null
                    ? const Icon(Icons.person, size: 50)
                    : null,
              ),
              const Positioned(
                bottom: 0,
                right: 0,
                child: CircleAvatar(
                  radius: 15,
                  child: Icon(Icons.edit, size: 15),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          user.displayName ?? 'Tanpa Nama',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text(user.email ?? 'Email tidak tersedia'),
        TextButton.icon(
          icon: const Icon(Icons.edit, size: 16),
          label: const Text('Ubah Nama'),
          onPressed: () => _showEditNameDialog(context, provider),
        ),
      ],
    );
  }

  // Widget untuk manajemen akun 
  Widget _buildAccountManagementSection(
    BuildContext context,
    SettingsProvider provider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Manajemen Akun', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Logout'),
          onTap: () async {
            await context.read<SettingsProvider>().signOut();
            if (context.mounted) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          },
        ),
      ],
    );
  }

  // Widget untuk area berbahaya
  Widget _buildDangerZone(BuildContext context, SettingsProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Zona Berbahaya',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: Colors.red),
        ),
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.delete_forever, color: Colors.red),
          title: const Text('Hapus Akun', style: TextStyle(color: Colors.red)),
          subtitle: const Text(
            'Tindakan ini tidak dapat dibatalkan dan akan menghapus semua data Anda',
          ),
          // Tambahkan Konfirmasi sebelum menghapus akun
          onTap: () => _showDeleteAccountDialog(context, provider),
        ),
      ],
    );
  }

  // Dialog untuk mengubah nama
  void _showEditNameDialog(BuildContext context, SettingsProvider provider) {
    final TextEditingController nameController = TextEditingController(
      text: provider.user?.displayName,
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ubah Nama Pengguna'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nama Baru'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              provider.updateDisplayName(nameController.text);
              Navigator.pop(context);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  // Dialog konfirmasi untuk hapus akun (Tidak Berubah)
  void _showDeleteAccountDialog(
    BuildContext context,
    SettingsProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apakah Anda Yakin?'),
        content: const Text(
          'Semua data Anda akan dihapus secara permanen. Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await provider.deleteAccount();
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Akun berhasil dihapus.')),
                );
              }
            },
            child: const Text('Ya, Hapus Akun Saya'),
          ),
        ],
      ),
    );
  }
}
