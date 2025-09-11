// lib/pages/setting_page.dart (REVISED & FIXED)

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../Providers/setting/setting_provider.dart';

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
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (Navigator.canPop(context)) Navigator.of(context).pop();
              });
              return const Center(child: Text('Pengguna tidak ditemukan.'));
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

  // Dialog untuk re-autentikasi 
  Future<void> _showReauthenticationDialog(
      BuildContext context, SettingsProvider provider) async {
    final user = provider.user;
    if (user == null || !context.mounted) return;

    final providerId = user.providerData.first.providerId;
    final messenger = ScaffoldMessenger.of(context);
    final rootNavigator = Navigator.of(context);

    if (providerId == 'password') {
      final passwordController = TextEditingController();
      return showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Verifikasi Identitas'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Untuk melanjutkan, silakan masukkan kembali password Anda.'),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Batal'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            FilledButton(
              child: const Text('Konfirmasi & Hapus'),
              onPressed: () async {
                if (passwordController.text.isEmpty) return;
                Navigator.of(dialogContext).pop();
                try {
                  await provider.reauthenticateAndDelete(password: passwordController.text);
                  if (!rootNavigator.mounted) return;
                  rootNavigator.popUntil((route) => route.isFirst);
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Akun berhasil diverifikasi dan dihapus.'), backgroundColor: Colors.green),
                  );
                } on FirebaseAuthException catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(e.code == 'wrong-password' || e.code == 'invalid-credential' ? 'Password yang Anda masukkan salah.' : 'Gagal verifikasi: ${e.message}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      );
    } else if (providerId == 'google.com') {
      return showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Verifikasi Identitas'),
          content: const Text('Untuk melanjutkan, Anda perlu login ulang dengan akun Google Anda.'),
          actions: [
            TextButton(
              child: const Text('Batal'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            FilledButton(
              child: const Text('Lanjutkan dengan Google'),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                try {
                  await provider.reauthenticateAndDelete();
                  if (!rootNavigator.mounted) return;
                  rootNavigator.popUntil((route) => route.isFirst);
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Akun berhasil diverifikasi dan dihapus.'), backgroundColor: Colors.green),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Gagal verifikasi dengan Google: ${e.toString()}'), backgroundColor: Colors.red),
                  );
                }
              },
            ),
          ],
        ),
      );
    }
  }

  // Dialog konfirmasi hapus akun
  void _showDeleteAccountDialog(BuildContext context, SettingsProvider provider) {
    final user = provider.user;
    if (user == null) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        // [SOLUSI] Gunakan StatefulWidget kustom untuk mengelola state dialog
        return _DeleteConfirmationDialog(
          user: user,
          onConfirm: () async {
            // Tutup dialog konfirmasi terlebih dahulu
            Navigator.of(dialogContext).pop();

            try {
              await provider.deleteAccount();
              // Jika berhasil, AuthWrapper akan menangani navigasi.
            } on FirebaseAuthException catch (e) {
              if (e.code == 'requires-recent-login') {
                // Panggil dialog re-autentikasi jika diperlukan
                if (context.mounted) {
                  await _showReauthenticationDialog(context, provider);
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gagal menghapus akun: ${e.message}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            }
          },
        );
      },
    );
  }
  
  // --- Widget lainnya (tidak ada perubahan) ---
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
                backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                child: user.photoURL == null ? const Icon(Icons.person, size: 50) : null,
              ),
              const Positioned(
                bottom: 0,
                right: 0,
                child: CircleAvatar(radius: 15, child: Icon(Icons.edit, size: 15)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(user.displayName ?? 'Tanpa Nama', style: Theme.of(context).textTheme.headlineSmall),
        Text(user.email ?? 'Email tidak tersedia'),
        TextButton.icon(
          icon: const Icon(Icons.edit, size: 16),
          label: const Text('Ubah Nama'),
          onPressed: () => _showEditNameDialog(context, provider),
        ),
      ],
    );
  }

  Widget _buildAccountManagementSection(BuildContext context, SettingsProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Manajemen Akun', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Logout'),
          onTap: () async {
            final navigator = Navigator.of(context);
            await provider.signOut();
            navigator.popUntil((route) => route.isFirst);
          },
        ),
      ],
    );
  }

  Widget _buildDangerZone(BuildContext context, SettingsProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Zona Berbahaya',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.red),
        ),
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.delete_forever, color: Colors.red),
          title: const Text('Hapus Akun', style: TextStyle(color: Colors.red)),
          subtitle: const Text('Tindakan ini tidak dapat dibatalkan dan akan menghapus semua data Anda'),
          onTap: () => _showDeleteAccountDialog(context, provider),
        ),
      ],
    );
  }

  void _showEditNameDialog(BuildContext context, SettingsProvider provider) {
    final nameController = TextEditingController(text: provider.user?.displayName);
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
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
}

// [BARU] Widget stateful untuk konten dialog penghapusan
class _DeleteConfirmationDialog extends StatefulWidget {
  const _DeleteConfirmationDialog({
    required this.user,
    required this.onConfirm,
  });

  final User user;
  final VoidCallback onConfirm;

  @override
  State<_DeleteConfirmationDialog> createState() => _DeleteConfirmationDialogState();
}

class _DeleteConfirmationDialogState extends State<_DeleteConfirmationDialog> {
  late final TextEditingController _controller;
  late final ValueNotifier<bool> _isButtonEnabled;
  late final String _confirmationText;

  @override
  void initState() {
    super.initState();
    final userName = widget.user.displayName?.toLowerCase() ?? widget.user.email?.split('@').first ?? 'saya';
    _confirmationText = 'hapus akun $userName';
    _controller = TextEditingController();
    _isButtonEnabled = ValueNotifier<bool>(false);

    _controller.addListener(() {
      _isButtonEnabled.value = _controller.text == _confirmationText;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _isButtonEnabled.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Hapus Akun Permanen?'),
      content: SingleChildScrollView(
        child: ListBody(
          children: <Widget>[
            const Text('Tindakan ini tidak dapat diurungkan. Semua data Anda akan dihapus secara permanen.'),
            const SizedBox(height: 16),
            Text(
              'Untuk konfirmasi, ketik teks di bawah ini:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.maxFinite,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _confirmationText,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Ketik konfirmasi di sini', border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Batal'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: _isButtonEnabled,
          builder: (context, isEnabled, child) {
            return FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: isEnabled ? Colors.red : Colors.grey.shade400,
              ),
              onPressed: isEnabled ? widget.onConfirm : null,
              child: const Text('Hapus Permanen'),
            );
          },
        ),
      ],
    );
  }
}