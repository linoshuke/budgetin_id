import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/models/wallet_model.dart';
import '/services/firestore_service.dart';
import 'package:provider/provider.dart';
import '/pages/wallets/widgets/wallet_detail.dart';

class WalletCard extends StatelessWidget {
  final Wallet wallet;

  const WalletCard({super.key, required this.wallet});

  void _showEditWalletDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController(text: wallet.walletName);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Ubah Nama Wallet"),
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
                  firestoreService.updateWalletName(wallet.id, nameController.text.trim());
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
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => WalletDetailScreen(walletId: wallet.id),
        ));
      },
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [Colors.blue.shade700, Colors.blue.shade900],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: Text(
                      wallet.walletName,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showEditWalletDialog(context),
                    child: const Icon(Icons.edit, size: 22, color: Colors.white70),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Total Saldo", style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14)),
                  Text(
                    currencyFormatter.format(wallet.balance),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 1.2),
                  ),
                ],
              ),
              StreamBuilder<Map<String, double>>(
                stream: firestoreService.getWalletStatsStream(wallet.id, wallet.displayPreference),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)));
                  }

                  final income = snapshot.data?['income'] ?? 0;
                  final expense = snapshot.data?['expense'] ?? 0;

                  return Column(
                    children: [
                      const Divider(color: Colors.white30, height: 1),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatItem(Icons.arrow_upward, Colors.greenAccent, "Pemasukan", currencyFormatter.format(income)),
                          _buildStatItem(Icons.arrow_downward, Colors.redAccent, "Pengeluaran", currencyFormatter.format(expense.abs())),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, Color color, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
            Text(value, style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        )
      ],
    );
  }
}