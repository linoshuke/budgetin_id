// lib/pages/account_page.dart

import 'package:budgetin_id/Providers/setting/setting_provider.dart';
import 'package:budgetin_id/pages/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
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
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if(Navigator.canPop(context)) Navigator.pop(context);
              });
              return const Center(child: Text("Anda telah logout."));
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
    // ... (kode ini tidak berubah)
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
                  onPressed: provider.isLoading ? null : () => provider.pickAndUploadProfileImage(),
                  tooltip: 'Ubah Foto Profil',
                  elevation: 1,
                  child: provider.isLoading ? const CircularProgressIndicator(strokeWidth: 2, color: Colors.white) : const Icon(Icons.camera_alt, size: 20),
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
    // ... (kode ini tidak berubah)
    if (provider.isAnonymous) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Manajemen Akun', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (!provider.hasGoogleProvider)
          ListTile(
            leading: Image.asset('assets/icons/google.png', height: 24.0),
            title: const Text('Kaitkan dengan Akun Google'),
            subtitle: const Text('Login lebih cepat dengan akun Google Anda.'),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              final theme = Theme.of(context);
              try {
                await provider.linkGoogleAccount();
                if(!context.mounted) return;
                messenger.showSnackBar(const SnackBar(content: Text('Akun Google berhasil ditautkan!'), backgroundColor: Colors.green,));
              } catch (e) {
                if(!context.mounted) return;
                messenger.showSnackBar(SnackBar(content: Text('Gagal menautkan: ${e.toString()}'), backgroundColor: theme.colorScheme.error,));
              }
            },
          ),
        
        if (!provider.hasPasswordProvider)
          ListTile(
            leading: const Icon(Icons.password_outlined),
            title: const Text('Tambahkan Login dengan Password'),
            subtitle: Text('Buat password untuk email ${provider.user?.email ?? ""}'),
            onTap: () => _showAddPasswordDialog(context, provider),
          ),

        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Logout'),
          onTap: () async {
            await provider.signOut();
          },
        ),
      ],
    );
  }

  Widget _buildDangerZone(BuildContext context, SettingsProvider provider) {
    // ... (kode ini tidak berubah)
    if (provider.isAnonymous) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Zona Berbahaya',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.error),
        ),
        const SizedBox(height: 8),
        ListTile(
          leading: Icon(Icons.delete_forever, color: Theme.of(context).colorScheme.error),
          title: Text('Hapus Akun', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          subtitle: const Text('Tindakan ini tidak dapat dibatalkan'),
          onTap: () => _showDeleteAccountDialog(context),
        ),
      ],
    );
  }

  void _showDeleteAccountDialog(BuildContext pageContext) {
    // ... (kode ini tidak berubah)
    final confirmationController = TextEditingController();
    final passwordController = TextEditingController();
    const String confirmationPhrase = "hapus akun saya";
    final provider = pageContext.read<SettingsProvider>();
    final isPasswordProvider = provider.user?.providerData.any((p) => p.providerId == 'password') ?? false;

    showDialog<void>(
      context: pageContext,
      barrierDismissible: false,
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            bool isPasswordVisible = false;
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
                        obscureText: !isPasswordVisible,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          suffixIcon: IconButton(
                            icon: Icon(isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                            onPressed: () {
                              setDialogState(() {
                                isPasswordVisible = !isPasswordVisible;
                              });
                            },
                          )
                        ),
                        onChanged: (value) => setDialogState(() {}),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          // [PERBAIKAN] Warning 'BuildContext' diperbaiki di sini
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(pageContext);
                            final theme = Theme.of(pageContext);
                            try {
                              await provider.sendPasswordResetEmailForCurrentUser();
                              if (!pageContext.mounted) return;
                              messenger.showSnackBar(const SnackBar(content: Text('Link reset password telah dikirim ke email Anda.'), backgroundColor: Colors.green,));
                            } catch (e) {
                               if (!pageContext.mounted) return;
                               messenger.showSnackBar(SnackBar(content: Text('Gagal mengirim email: ${e.toString()}'), backgroundColor: theme.colorScheme.error,));
                            }
                          },
                          child: const Text('Lupa Password?'),
                        ),
                      ),
                    ],
                     if (!isPasswordProvider) ...[
                      const SizedBox(height: 16),
                      Text('Anda akan diminta untuk login ulang dengan Google untuk melanjutkan.', style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
                    ]
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
                    Navigator.of(dialogContext).pop(); 

                    try {
                      await provider.deleteAccountWithVerification(password: passwordController.text);
                    } catch (e) {
                      if (!pageContext.mounted) return;
                      String errorMessage = 'Terjadi kesalahan.';
                      if (e is FirebaseAuthException) {
                         if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
                          errorMessage = 'Password yang Anda masukkan salah.';
                        } else if(e.code == 'requires-recent-login'){
                          errorMessage = 'Login ulang diperlukan. Silakan logout dan login kembali untuk melanjutkan.';
                        } else {
                          errorMessage = 'Gagal menghapus akun: ${e.message}';
                        }
                      }
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(errorMessage),
                          backgroundColor: Theme.of(pageContext).colorScheme.error,
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
    // ... (kode ini tidak berubah)
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

  void _showAddPasswordDialog(BuildContext context, SettingsProvider provider) {
    // ... (kode ini tidak berubah)
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Buat Password Baru'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password Baru'),
                validator: (value) {
                  if (value == null || value.length < 6) {
                    return 'Password minimal 6 karakter';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Konfirmasi Password'),
                validator: (value) {
                  if (value != passwordController.text) {
                    return 'Password tidak cocok';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final messenger = ScaffoldMessenger.of(context);
                final theme = Theme.of(context);
                Navigator.pop(dialogContext);
                try {
                  await provider.addPasswordToAccount(passwordController.text);
                  if (!context.mounted) return;
                  messenger.showSnackBar(const SnackBar(content: Text('Password berhasil ditambahkan!'), backgroundColor: Colors.green,));
                } catch (e) {
                  if (!context.mounted) return;
                  messenger.showSnackBar(SnackBar(content: Text('Gagal: ${e.toString()}'), backgroundColor: theme.colorScheme.error,));
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}
