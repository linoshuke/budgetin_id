// wallet_screen.dart (NO CHANGES NEEDED)
import 'package:flutter/material.dart';
import 'widgets/models/wallet_model.dart';
import '/pages/account_router.dart';
import '/services/firestore_service.dart';
import 'package:provider/provider.dart';
import '/pages/wallets/widgets/wallet_card.dart';

class WalletsScreen extends StatelessWidget {
  const WalletsScreen({super.key});

  void _showAddWalletDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Tambah Wallet Baru"),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Nama Wallet"),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Nama tidak boleh kosong';
                }
                return null;
              },
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
                  final firestoreService = context.read<FirestoreService>();
                  firestoreService.addWallet(nameController.text.trim());
                  Navigator.of(context).pop();
                }
              },
              child: const Text("Simpan"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.watch<FirestoreService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Daftar Wallet"),
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
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text("Anda belum punya wallet.\nAyo buat satu!"),
            );
          }

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
