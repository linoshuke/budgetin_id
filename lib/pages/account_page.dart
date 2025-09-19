import 'package:budgetin_id/pages/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../Providers/setting/setting_provider.dart';
import 'auth/service/auth_service.dart';

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
                  backgroundImage: user.photoURL != null
                      ? NetworkImage(user.photoURL!)
                      : null,
                  child: user.photoURL == null
                      ? Icon(
                          Icons.person,
                          size: 20,
                          color: Colors.grey.shade600,
                        )
                      : null,
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
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final user = provider.user;
            if (user == null) {
              return const Center(child: Text('Sesi tidak ditemukan.'));
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
    final displayName = provider.isAnonymous
        ? "Pengguna Tamu"
        : (user.displayName ?? 'Tanpa Nama');

    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundImage: user.photoURL != null
              ? NetworkImage(user.photoURL!)
              : null,
          child: user.photoURL == null
              ? Icon(Icons.person, size: 50, color: Colors.grey.shade400)
              : null,
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

  Widget _buildAccountManagementSection(
    BuildContext context,
    SettingsProvider provider,
  ) {
    if (provider.isAnonymous) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Manajemen Akun', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Logout'),
          onTap: () async {
            await provider.signOut();
            if (context.mounted) {
              Navigator.popUntil(context, (route) => route.isFirst);
            }
          },
        ),
      ],
    );
  }

  Widget _buildDangerZone(BuildContext context, SettingsProvider provider) {
    if (provider.isAnonymous) {
      return const SizedBox.shrink();
    }

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
          subtitle: const Text('Tindakan ini tidak dapat dibatalkan'),
          onTap: () => _showDeleteAccountDialog(context, provider),
        ),
      ],
    );
  }

  void _showDeleteAccountDialog(
    BuildContext context,
    SettingsProvider provider,
  ) {
    final confirmationController = TextEditingController();
    const String confirmationPhrase = "hapus akun saya";

    showDialog<void>(
      context: context,
      barrierDismissible: false, // Mencegah dialog ditutup saat loading
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isProviderLoading = context
                .watch<SettingsProvider>()
                .isLoading;
            return AlertDialog(
              title: const Text('Hapus Akun Permanen?'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    const Text(
                      'Tindakan ini tidak dapat diurungkan. Semua data Anda akan dihapus secara permanen.',
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Untuk melanjutkan, ketik frasa berikut di bawah ini:',
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          confirmationPhrase,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: confirmationController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Ketik konfirmasi di sini',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => setDialogState(() {}),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: isProviderLoading
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Batal'),
                ),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        confirmationController.text == confirmationPhrase
                        ? Theme.of(context).colorScheme.errorContainer
                        : Colors.grey.shade300,
                    foregroundColor:
                        confirmationController.text == confirmationPhrase
                        ? Theme.of(context).colorScheme.onErrorContainer
                        : Colors.grey.shade600,
                  ),
                  // [PERBAIKAN UTAMA] Logika penanganan error ada di sini
                  onPressed:
                      confirmationController.text == confirmationPhrase &&
                          !isProviderLoading
                      ? () async {
                          // Gunakan `context.read` karena kita di dalam callback
                          final provider = context.read<SettingsProvider>();
                          final messenger = ScaffoldMessenger.of(context);

                          try {
                            await provider.deleteAccount();
                            // Jika berhasil, dialog ini akan ditutup dan AuthWrapper akan handle navigasi
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                          } on RequiresRecentLoginException {
                            // TANGKAP EXCEPTION CUSTOM DI SINI!
                            if (!dialogContext.mounted) return;
                            Navigator.of(
                              dialogContext,
                            ).pop(); // Tutup dialog saat ini
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Sesi Anda telah berakhir. Silakan verifikasi ulang untuk melanjutkan.',
                                ),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            // Panggil dialog re-autentikasi
                            await _showReauthenticationDialog(
                              context,
                              provider,
                            );
                          } on FirebaseAuthException catch (e) {
                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext).pop();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Gagal menghapus akun: ${e.message}',
                                ),
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.error,
                              ),
                            );
                          } catch (e) {
                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext).pop();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Terjadi kesalahan tidak terduga: ${e.toString()}',
                                ),
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.error,
                              ),
                            );
                          }
                        }
                      : null,
                  child: isProviderLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Ya, Hapus Permanen'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showReauthenticationDialog(
    BuildContext context,
    SettingsProvider provider,
  ) async {
    // Implementasi _showReauthenticationDialog Anda sudah benar, tidak perlu diubah.
    // ... (salin kode _showReauthenticationDialog Anda dari prompt sebelumnya ke sini) ...
    final user = provider.user;
    if (user == null || !context.mounted) return;

    final providerId = user.providerData.first.providerId;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context, rootNavigator: true);

    if (providerId == 'password') {
      final passwordController = TextEditingController();
      return showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Verifikasi Identitas'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Untuk keamanan, masukkan kembali password Anda untuk menghapus akun.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
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
                  await provider.reauthenticateAndDelete(
                    password: passwordController.text,
                  );
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Akun berhasil dihapus.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } on FirebaseAuthException catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        e.code == 'wrong-password' ||
                                e.code == 'invalid-credential'
                            ? 'Password yang Anda masukkan salah.'
                            : 'Gagal verifikasi: ${e.message}',
                      ),
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
          content: const Text(
            'Untuk keamanan, Anda perlu login ulang dengan akun Google Anda untuk menghapus akun.',
          ),
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
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Akun berhasil dihapus.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'Gagal verifikasi dengan Google: ${e.toString()}',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      );
    }
  }

  void _showEditNameDialog(BuildContext context, SettingsProvider provider) {
    // ... (salin kode _showEditNameDialog Anda dari prompt sebelumnya ke sini) ...
    final nameController = TextEditingController(
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
}
