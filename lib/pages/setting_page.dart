import 'package:budgetin_id/pages/auth/login_screen.dart'; // [BARU] Import LoginScreen
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../Providers/setting/setting_provider.dart'; // Sesuaikan path jika perlu

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
              // Seharusnya tidak terjadi karena ada AuthWrapper, tapi sebagai fallback
              return const Center(child: Text('Sesi tidak ditemukan.'));
            }

            return ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Bagian profil tetap sama untuk semua user
                _buildProfileSection(context, provider),
                const SizedBox(height: 24),
                const Divider(),

                // Bagian ini akan berubah tergantung status user
                _buildAccountManagementSection(context, provider),
                const SizedBox(height: 24),
                const Divider(),
                
                // Zona berbahaya hanya untuk user permanen
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
    // Untuk user anonim, tampilkan nama default
    final displayName = provider.isAnonymous ? "Pengguna Tamu" : (user.displayName ?? 'Tanpa Nama');
    
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          // User anonim tidak punya photoURL
          backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
          child: user.photoURL == null ? Icon(Icons.person, size: 50, color: Colors.grey.shade400) : null,
        ),
        const SizedBox(height: 16),
        Text(displayName, style: Theme.of(context).textTheme.headlineSmall),
        if (!provider.isAnonymous) // Hanya tampilkan email jika bukan anonim
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(user.email ?? 'Email tidak tersedia'),
          ),
        
        // Sembunyikan tombol edit nama untuk user anonim
        if (!provider.isAnonymous)
          TextButton.icon(
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Ubah Nama'),
            onPressed: () => _showEditNameDialog(context, provider),
          ),
      ],
    );
  }

  // Logika manajemen akun
  Widget _buildAccountManagementSection(BuildContext context, SettingsProvider provider) {
    // Tampilan untuk PENGGUNA ANONIM
    if (provider.isAnonymous) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Simpan Progres Anda', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'Tautkan akun Anda untuk menyimpan data secara permanen dan mengaksesnya dari perangkat lain.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: Image.asset('assets/icons/google.png', height: 22.0, color: Colors.white),
            label: const Text('Lanjutkan dengan Google'),
            onPressed: () => _handleLinkWithGoogle(context, provider),
            style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.email_outlined),
            label: const Text('Lanjutkan dengan Email'),
            onPressed: () => _showLinkWithEmailDialog(context, provider), // [FIX] Memanggil fungsi di sini
            style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Sudah punya akun?"),
              TextButton(
                child: const Text('Login di sini'),
                onPressed: () {
                  // Inilah peran baru LoginScreen
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                },
              )
            ],
          ),
        ],
      );
    }
    
    // Tampilan untuk PENGGUNA PERMANEN
    else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Manajemen Akun', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              // Setelah logout, AuthWrapper akan membuat sesi anonim baru
              await provider.signOut();
              if (context.mounted) Navigator.popUntil(context, (route) => route.isFirst);
            },
          ),
        ],
      );
    }
  }

  Widget _buildDangerZone(BuildContext context, SettingsProvider provider) {
    if (provider.isAnonymous) {
      return const SizedBox.shrink(); // Widget kosong
    }
    
    // ... (kode _buildDangerZone Anda yang sudah ada, tidak perlu diubah)
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
          onTap: () => _showDeleteAccountDialog(context, provider),
        ),
      ],
    );
  }

  // Wrapper untuk handle linking Google agar ada feedback
  Future<void> _handleLinkWithGoogle(BuildContext context, SettingsProvider provider) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await provider.linkWithGoogle();
      messenger.showSnackBar(
        const SnackBar(content: Text('Akun berhasil ditautkan dengan Google!'), backgroundColor: Colors.green),
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Gagal menautkan akun.';
      if (e.code == 'credential-already-in-use') {
        message = 'Akun Google ini sudah digunakan oleh pengguna lain.';
      }
      messenger.showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  // [TETAP] Dialog untuk menautkan akun dengan email
  void _showLinkWithEmailDialog(BuildContext context, SettingsProvider provider) {
    // ... (kode dialog ini dari respons sebelumnya sudah benar, tidak perlu diubah)
    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tautkan dengan Email'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: emailController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Email Baru'),
                validator: (val) => val!.isEmpty ? 'Email tidak boleh kosong' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: passwordController,
                decoration: const InputDecoration(labelText: 'Password Baru'),
                obscureText: true,
                validator: (val) => val!.length < 6 ? 'Password minimal 6 karakter' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);
                try {
                  await provider.linkWithEmail(emailController.text.trim(), passwordController.text.trim());
                  navigator.pop();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Akun berhasil ditautkan!'), backgroundColor: Colors.green),
                  );
                } on FirebaseAuthException catch(e) {
                  String message = 'Gagal menautkan akun.';
                  if (e.code == 'email-already-in-use') {
                    message = 'Email ini sudah digunakan oleh akun lain.';
                  } else if (e.code == 'credential-already-in-use') {
                    message = 'Akun ini sudah tertaut.';
                  }
                  messenger.showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
                }
              }
            },
            child: const Text('Tautkan'),
          ),
        ],
      ),
    );
  }
  // [PERBAIKAN] Dialog konfirmasi hapus akun disederhanakan
  void _showDeleteAccountDialog(BuildContext context, SettingsProvider provider) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Hapus Akun Permanen?'),
          content: const Text(
            'Tindakan ini tidak dapat diurungkan. Semua data Anda, termasuk transaksi dan dompet, akan dihapus secara permanen.\n\nApakah Anda yakin ingin melanjutkan?',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Batal'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            // Gunakan FilledButton.tonal dengan warna error untuk penekanan
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
              ),
              child: const Text('Ya, Hapus Permanen'),
              onPressed: () async {
                // Tutup dialog konfirmasi ini terlebih dahulu
                Navigator.of(dialogContext).pop();
                
                try {
                  // Coba hapus akun
                  await provider.deleteAccount();
                  // Jika berhasil, AuthWrapper akan menangani navigasi secara otomatis.
                } on FirebaseAuthException catch (e) {
                  // Jika Firebase meminta login ulang karena sesi sudah lama
                  if (e.code == 'requires-recent-login' && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sesi Anda telah berakhir. Silakan verifikasi ulang untuk melanjutkan.'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    // Panggil dialog re-autentikasi
                    await _showReauthenticationDialog(context, provider);
                  } else {
                    // Tangani error lain
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Gagal menghapus akun: ${e.message}'),
                          backgroundColor: Theme.of(context).colorScheme.error,
                        ),
                      );
                    }
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  // [TETAP] Fungsi untuk re-autentikasi tidak perlu diubah, logikanya sudah benar.
  Future<void> _showReauthenticationDialog(
      BuildContext context, SettingsProvider provider) async {
    // ... (kode _showReauthenticationDialog Anda yang sudah ada, tidak perlu diubah)
     final user = provider.user;
    if (user == null || !context.mounted) return;

    final providerId = user.providerData.first.providerId;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context, rootNavigator: true); // Gunakan rootNavigator

    // Jika login dengan password
    if (providerId == 'password') {
      final passwordController = TextEditingController();
      return showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Verifikasi Identitas'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Untuk keamanan, masukkan kembali password Anda untuk menghapus akun.'),
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
                Navigator.of(dialogContext).pop(); // Tutup dialog sebelum proses
                try {
                  await provider.reauthenticateAndDelete(password: passwordController.text);
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Akun berhasil dihapus.'), backgroundColor: Colors.green),
                  );
                  // AuthWrapper akan menangani navigasi keluar
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
    } 
    // Jika login dengan Google
    else if (providerId == 'google.com') {
      return showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Verifikasi Identitas'),
          content: const Text('Untuk keamanan, Anda perlu login ulang dengan akun Google Anda untuk menghapus akun.'),
          actions: [
            TextButton(
              child: const Text('Batal'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            FilledButton(
              child: const Text('Lanjutkan dengan Google'),
              onPressed: () async {
                Navigator.of(dialogContext).pop(); // Tutup dialog sebelum proses
                try {
                  await provider.reauthenticateAndDelete();
                   messenger.showSnackBar(
                    const SnackBar(content: Text('Akun berhasil dihapus.'), backgroundColor: Colors.green),
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