// lib/pages/account_page.dart

import 'package:budgetin_id/Providers/setting/setting_provider.dart';
import 'package:budgetin_id/pages/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'auth/service/auth_service.dart';

// ... (Bagian atas file tetap sama, tidak perlu diubah)
class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: context.watch<AuthService>().authStateChanges,
      builder: (context, snapshot) {
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

        if (user != null && !user.isAnonymous) {
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
                  child: user.photoURL == null ? Icon(Icons.person, size: 20, color: Colors.grey.shade600) : null,
                ),
              ),
            ),
          );
        } else {
          return IconButton(
            icon: const Icon(Icons.login, size: 28),
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
            final user = provider.user;
            if (user == null) {
              return const Center(child: CircularProgressIndicator());
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
    Widget _buildProfileSection(BuildContext context, SettingsProvider provider) {
    final user = provider.user!;
    final displayName = provider.isAnonymous ? "Pengguna Tamu" : (user.displayName ?? 'Tanpa Nama');
    
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
              child: user.photoURL == null ? Icon(Icons.person, size: 50, color: Colors.grey.shade400) : null,
            ),
            if(!provider.isAnonymous)
            SizedBox(
              height: 36,
              width: 36,
              child: FittedBox(
                child: FloatingActionButton(
                  onPressed: () => provider.pickAndUploadProfileImage(),
                  tooltip: 'Ubah Foto Profil',
                  elevation: 1,
                  child: provider.isLoading ? const CircularProgressIndicator(strokeWidth: 2) : const Icon(Icons.camera_alt, size: 20),
                ),
              ),
            )
          ],
        ),
        const SizedBox(height: 16),
        Text(displayName, style: Theme.of(context).textTheme.headlineSmall),
        if (!provider.isAnonymous)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(user.email ?? 'Email tidak tersedia'),
          ),
        
        if (!provider.isAnonymous)
          TextButton.icon(
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Ubah Nama'),
            onPressed: () => _showEditNameDialog(context, provider),
          ),
      ],
    );
  }

  Widget _buildAccountManagementSection(BuildContext context, SettingsProvider provider) {
    if (provider.isAnonymous) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Manajemen Akun', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Logout'),
          onTap: () async => await provider.signOut(),
        ),
      ],
    );
  }

  Widget _buildDangerZone(BuildContext context, SettingsProvider provider) {
    if (provider.isAnonymous) return const SizedBox.shrink();
    
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
          subtitle: const Text('Tindakan ini tidak dapat dibatalkan'),
          onTap: () => _showDeleteAccountDialog(context),
        ),
      ],
    );
  }

  void _showDeleteAccountDialog(BuildContext pageContext) {
    final confirmationController = TextEditingController();
    final passwordController = TextEditingController();
    const String confirmationPhrase = "hapus akun saya";
    final provider = pageContext.read<SettingsProvider>();
    
    // [PERBAIKAN] Menggunakan .any() untuk cek yang lebih andal.
    final isPasswordProvider = provider.user?.providerData.any((p) => p.providerId == 'password') ?? false;

    showDialog<void>(
      context: pageContext,
      barrierDismissible: false,
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final isProviderLoading = dialogContext.watch<SettingsProvider>().isLoading;
            final isConfirmationValid = confirmationController.text == confirmationPhrase;
            final isPasswordEntered = !isPasswordProvider || passwordController.text.isNotEmpty;
            final canDelete = isConfirmationValid && isPasswordEntered && !isProviderLoading;

            return AlertDialog(
              title: const Text('Hapus Akun Permanen?'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    const Text('Tindakan ini akan menghapus semua data Anda secara permanen.'),
                    const SizedBox(height: 16),
                    const Text('Ketik frasa berikut untuk konfirmasi:'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                      child: const Center(child: Text(confirmationPhrase, style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'))),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: confirmationController,
                      autofocus: true,
                      decoration: const InputDecoration(labelText: 'Ketik konfirmasi di sini'),
                      onChanged: (value) => setDialogState(() {}),
                    ),
                    if (isPasswordProvider) ...[
                      const SizedBox(height: 16),
                      Text('Untuk keamanan, masukkan kembali password Anda:', style: Theme.of(dialogContext).textTheme.bodyMedium),
                      const SizedBox(height: 8),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Password'),
                        onChanged: (value) => setDialogState(() {}),
                      ),
                    ],
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: isProviderLoading ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Batal'),
                ),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: canDelete ? Theme.of(dialogContext).colorScheme.errorContainer : Colors.grey.shade300,
                    foregroundColor: canDelete ? Theme.of(dialogContext).colorScheme.onErrorContainer : Colors.grey.shade600,
                  ),
                  onPressed: canDelete ? () async {
                    final messenger = ScaffoldMessenger.of(pageContext);
                    
                    try {
                      await provider.deleteAccountWithVerification(password: passwordController.text);
                      
                      if (pageContext.mounted) {
                        Navigator.of(dialogContext).pop(); 
                        Navigator.of(pageContext).pop(); 
                      }
                      
                    } catch (e) {
                      if (!pageContext.mounted) return;
                      
                      Navigator.of(dialogContext).pop();

                      String errorMessage = 'Terjadi kesalahan.';
                      if (e is FirebaseAuthException) {
                        if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
                          errorMessage = 'Password yang Anda masukkan salah.';
                        } else {
                          errorMessage = 'Gagal menghapus akun: ${e.message}';
                        }
                      }
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(errorMessage),
                          backgroundColor: Theme.of(dialogContext).colorScheme.error,
                        ),
                      );
                    }
                  } : null,
                  child: isProviderLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Ya, Hapus Permanen'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showEditNameDialog(BuildContext context, SettingsProvider provider) {
    final nameController = TextEditingController(text: provider.user?.displayName);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ubah Nama Pengguna'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nama Baru'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                provider.updateDisplayName(nameController.text.trim());
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}