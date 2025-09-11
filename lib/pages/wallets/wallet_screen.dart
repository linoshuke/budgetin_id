// wallet_screen.dart (REVISED)

import 'package:flutter/material.dart';
import 'widgets/models/wallet_model.dart';
import '/pages/account_router.dart';
import '/services/firestore_service.dart';
import 'package:provider/provider.dart';
import 'widgets/card_wallet.dart';

class WalletsScreen extends StatelessWidget {
  const WalletsScreen({super.key});

  // [REVISI] Dialog untuk menambah wallet baru sekarang lebih lengkap dan modern.
  void _showAddWalletDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    
    // Variabel untuk menampung nilai dari dropdown
    String? selectedCategory;
    String? selectedLocation;

    // Opsi default untuk dropdown
    final List<String> categories = ['Dana Pensiun', 'Uang Jajan', 'Investasi', 'Bisnis'];
    final List<String> locations = ['Bank', 'Kartu Kredit', 'Cash'];

    showDialog(
      context: context,
      builder: (context) {
        // StatefulBuilder digunakan agar UI di dalam dialog (seperti dropdown) bisa diperbarui.
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Tambah Dompet Baru"),
              content: Form(
                key: formKey,
                child: SingleChildScrollView( // Agar tidak overflow saat keyboard muncul
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: "Nama Dompet",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Nama tidak boleh kosong';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Kategori',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        value: selectedCategory,
                        hint: const Text('Pilih kategori'),
                        items: categories.map((String category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setDialogState(() {
                            selectedCategory = newValue;
                          });
                        },
                        validator: (value) => value == null ? 'Kategori harus dipilih' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Lokasi Penyimpanan',
                          border: OutlineInputBorder(),
                           prefixIcon: Icon(Icons.storage_outlined),
                        ),
                        value: selectedLocation,
                        hint: const Text('Pilih lokasi'),
                        items: locations.map((String location) {
                          return DropdownMenuItem<String>(
                            value: location,
                            child: Text(location),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setDialogState(() {
                            selectedLocation = newValue;
                          });
                        },
                        validator: (value) => value == null ? 'Lokasi harus dipilih' : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Batal"),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      context.read<FirestoreService>();
                      
                      if (formKey.currentState!.validate()) {
                     final firestoreService = context.read<FirestoreService>();
                        firestoreService.addWallet(
                        name: nameController.text.trim(),
                        category: selectedCategory!, // Nilai dari dropdown
                        location: selectedLocation!, // Nilai dari dropdown
    );
    
    Navigator.of(context).pop();
}

                      
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text("Simpan"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.watch<FirestoreService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Daftar Dompet Saya"), // Judul disesuaikan agar lebih personal
        actions: const [AccountRouter()],
      ),
      body: StreamBuilder<List<Wallet>>(
        stream: firestoreService.getWallets(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Terjadi kesalahan: ${snapshot.error}"));
          }
          // [REVISI] Memeriksa data dan membuat variabel lokal untuk menghilangkan `!`
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wallet_giftcard, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    "Anda belum punya dompet.",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Ayo buat satu untuk mulai mencatat!",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // [REVISI] Data aman untuk diakses di sini tanpa `!`
          final wallets = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: wallets.length,
            itemBuilder: (context, index) {
              final wallet = wallets[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: WalletCard(wallet: wallet),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddWalletDialog(context),
        tooltip: 'Tambah Wallet',
        child: const Icon(Icons.add),
      ),
    );
  }
}