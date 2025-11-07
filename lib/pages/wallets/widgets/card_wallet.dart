import 'package:budgetin_id/pages/wallets/widgets/detail_wallet.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/pages/wallets/widgets/models/wallet_model.dart';
import '/services/firestore_service.dart';
import 'package:provider/provider.dart';

class WalletCard extends StatefulWidget {
  final Wallet wallet;

  const WalletCard({super.key, required this.wallet});

  @override
  State<WalletCard> createState() => _WalletCardState();
}

class _WalletCardState extends State<WalletCard> {
  late Stream<Map<String, double>> _statsStream;

  @override
  void initState() {
    super.initState();
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );
    _statsStream = firestoreService.getWalletStatsStream(
      widget.wallet.id,
      widget.wallet.displayPreference,
    );
  }

  @override
  void didUpdateWidget(covariant WalletCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.wallet.displayPreference != oldWidget.wallet.displayPreference) {
      final firestoreService = Provider.of<FirestoreService>(
        context,
        listen: false,
      );
      setState(() {
        _statsStream = firestoreService.getWalletStatsStream(
          widget.wallet.id,
          widget.wallet.displayPreference,
        );
      });
    }
  }

  // Dialog untuk Ubah Nama
  void _showEditWalletDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController(
      text: widget.wallet.walletName,
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Ubah Nama Dompet"),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Nama Dompet"),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Nama tidak boleh kosong'
                  : null,
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
                  context.read<FirestoreService>().updateWalletName(
                    widget.wallet.id,
                    nameController.text.trim(),
                  );
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

  // Dialog untuk konfirmasi hapus dompet
  void _showDeleteConfirmationDialog(BuildContext context) {
    final TextEditingController confirmationController =
        TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isButtonEnabled = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Hapus Dompet?"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Tindakan ini tidak dapat diurungkan dan akan menghapus semua transaksi di dalamnya.\n\nUntuk konfirmasi, ketik \"${widget.wallet.walletName}\" di bawah ini.",
                  ),
                  const SizedBox(height: 16),
                  Form(
                    key: formKey,
                    child: TextFormField(
                      controller: confirmationController,
                      decoration: InputDecoration(
                        labelText: 'Ketik nama dompet',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          isButtonEnabled = (value == widget.wallet.walletName);
                        });
                      },
                      validator: (value) {
                        if (value != widget.wallet.walletName) {
                          return 'Nama tidak cocok';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Batal"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: !isButtonEnabled
                      ? null
                      : () {
                          if (formKey.currentState!.validate()) {
                            context.read<FirestoreService>().deleteWallet(
                              widget.wallet.id,
                            );
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Dompet "${widget.wallet.walletName}" telah dihapus.',
                                ),
                              ),
                            );
                          }
                        },
                  child: const Text(
                    "Hapus",
                    style: TextStyle(color: Colors.white),
                  ),
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
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => WalletDetailScreen(walletId: widget.wallet.id),
          ),
        );
      },
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          // [PERUBAHAN] Gunakan warna dari themeExtension
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
                      widget.wallet.walletName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showEditWalletDialog(context);
                      } else if (value == 'delete') {
                        _showDeleteConfirmationDialog(context);
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                          const PopupMenuItem<String>(
                            value: 'edit',
                            child: ListTile(
                              leading: Icon(Icons.edit),
                              title: Text('Ubah Nama'),
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: ListTile(
                              leading: Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              title: Text(
                                'Hapus Dompet',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ),
                        ],
                    icon: const Icon(Icons.more_vert, color: Colors.white70),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Total Saldo",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    currencyFormatter.format(widget.wallet.balance),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              StreamBuilder<Map<String, double>>(
                stream: _statsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return const Center(
                      child: Icon(
                        Icons.error_outline,
                        color: Colors.white70,
                        size: 20,
                      ),
                    );
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
                          _buildStatItem(
                            Icons.arrow_upward,
                            Colors.greenAccent,
                            "Pemasukan",
                            currencyFormatter.format(income),
                          ),
                          _buildStatItem(
                            Icons.arrow_downward,
                            Colors.redAccent,
                            "Pengeluaran",
                            currencyFormatter.format(expense.abs()),
                          ),
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

  Widget _buildStatItem(
    IconData icon,
    Color color,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}