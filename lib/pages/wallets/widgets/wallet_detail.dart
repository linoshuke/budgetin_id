// wallet_detail.dart (REVISED)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '/models/transaction_model.dart';
import 'models/wallet_model.dart';
import '/services/firestore_service.dart';
import '../thousand_formatter.dart';
import 'package:provider/provider.dart';

enum DisplayPeriod { monthly, daily }

class WalletDetailScreen extends StatefulWidget {
  final String walletId;

  const WalletDetailScreen({super.key, required this.walletId});

  @override
  State<WalletDetailScreen> createState() => _WalletDetailScreenState();
}

class _WalletDetailScreenState extends State<WalletDetailScreen> {
  late DateTime _selectedMonth;
  late DateTimeRange _currentDateRange;
  DisplayPeriod _selectedPeriod = DisplayPeriod.monthly;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now();
    _updateDateRange();
  }

  void _updateDateRange() {
    setState(() {
      if (_selectedPeriod == DisplayPeriod.monthly) {
        final firstDay = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
        final lastDay = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0, 23, 59, 59);
        _currentDateRange = DateTimeRange(start: firstDay, end: lastDay);
      } else {
        final now = DateTime.now();
        final startOfDay = DateTime(now.year, now.month, now.day);
        final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
        _currentDateRange = DateTimeRange(start: startOfDay, end: endOfDay);
      }
    });
  }

  void _goToPreviousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
      _updateDateRange();
    });
  }

  void _goToNextMonth() {
    final now = DateTime.now();
    final nextMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    if (nextMonth.isAfter(now)) return; // Mencegah navigasi ke masa depan
    setState(() {
      _selectedMonth = nextMonth;
      _updateDateRange();
    });
  }

  void _showAddTransactionDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    TransactionType type = TransactionType.expense;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Tambah Transaksi"),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: descriptionController,
                      decoration: const InputDecoration(labelText: "Deskripsi"),
                      validator: (val) => val!.isEmpty ? "Tidak boleh kosong" : null,
                    ),
                    TextFormField(
                      controller: amountController,
                      decoration: const InputDecoration(labelText: "Jumlah", prefixText: "Rp "),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        ThousandsSeparatorInputFormatter(),
                      ],
                      validator: (val) => val!.isEmpty ? "Tidak boleh kosong" : null,
                    ),
                    const SizedBox(height: 20),
                    ToggleButtons(
                      isSelected: [type == TransactionType.expense, type == TransactionType.income],
                      onPressed: (index) {
                        setDialogState(() {
                          type = index == 0 ? TransactionType.expense : TransactionType.income;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      selectedColor: Colors.white,
                      fillColor: type == TransactionType.expense ? Colors.red : Colors.green,
                      children: const [
                        Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text("Pengeluaran")),
                        Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text("Pemasukan")),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      final firestoreService = context.read<FirestoreService>();
                      final cleanAmount = amountController.text.replaceAll('.', '');
                      firestoreService.addTransaction(
                        walletId: widget.walletId,
                        description: descriptionController.text,
                        amount: double.parse(cleanAmount),
                        type: type,
                      );
                      Navigator.pop(context);
                    }
                  },
                  child: const Text("Simpan"),
                )
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
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return StreamBuilder<Wallet>(
      stream: firestoreService.getWallet(widget.walletId),
      builder: (context, walletSnapshot) {
        if (!walletSnapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final wallet = walletSnapshot.data!;

        return Scaffold(
          appBar: AppBar(title: Text(wallet.walletName)),
          body: Column(
            children: [
              _buildHeader(context, wallet, currencyFormatter, firestoreService),
              _buildTransactionFilter(),
              if (_selectedPeriod == DisplayPeriod.monthly) _buildMonthNavigator(),
              const Padding(
                padding: EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
                child: Row(
                  children: [
                    Icon(Icons.history, color: Colors.grey),
                    SizedBox(width: 8),
                    Text("Riwayat Transaksi", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<List<Transaction>>(
                  stream: firestoreService.getTransactions(widget.walletId, _currentDateRange),
                  builder: (context, transactionSnapshot) {
                    if (transactionSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    // KRUSIAL: Tambahkan penanganan error
                    if (transactionSnapshot.hasError) {
                      debugPrint("Error fetching transactions: ${transactionSnapshot.error}");
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            "Terjadi kesalahan saat memuat transaksi. Kemungkinan Anda perlu membuat index di Firestore. Cek log untuk detail.",
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    
                    if (!transactionSnapshot.hasData || transactionSnapshot.data!.isEmpty) {
                      return const Center(child: Text("Belum ada transaksi pada periode ini."));
                    }
                    final transactions = transactionSnapshot.data!;
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        final transaction = transactions[index];
                        final isIncome = transaction.type == TransactionType.income;
                        return ListTile(
                          leading: Icon(
                            isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                            color: isIncome ? Colors.green : Colors.red,
                          ),
                          title: Text(transaction.description),
                          subtitle: Text(DateFormat.yMMMMEEEEd('id_ID').add_Hm().format(transaction.transactionDate)),
                          trailing: Text(
                            "${isIncome ? '+' : '-'} ${currencyFormatter.format(transaction.amount)}",
                            style: TextStyle(
                              color: isIncome ? Colors.green : Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddTransactionDialog(context),
            tooltip: "Tambah Transaksi",
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, Wallet wallet, NumberFormat currencyFormatter, FirestoreService firestoreService) {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Total Saldo Saat Ini", style: TextStyle(color: Colors.grey)),
            Text(
              currencyFormatter.format(wallet.balance),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text("Tampilkan Statistik di Kartu", style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            ToggleButtons(
              isSelected: [wallet.displayPreference == 'daily', wallet.displayPreference == 'monthly'],
              onPressed: (index) {
                final newPreference = index == 0 ? 'daily' : 'monthly';
                firestoreService.updateWalletPreference(widget.walletId, newPreference);
              },
              borderRadius: BorderRadius.circular(8),
              constraints: BoxConstraints(minHeight: 40.0, minWidth: (MediaQuery.of(context).size.width - 80) / 2),
              children: const [Text("Harian"), Text("Bulanan")],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SegmentedButton<DisplayPeriod>(
        segments: const [
          ButtonSegment(value: DisplayPeriod.monthly, label: Text("Bulanan"), icon: Icon(Icons.calendar_month)),
          ButtonSegment(value: DisplayPeriod.daily, label: Text("Harian"), icon: Icon(Icons.today)),
        ],
        selected: {_selectedPeriod},
        onSelectionChanged: (newSelection) {
          setState(() {
            _selectedPeriod = newSelection.first;
            _updateDateRange();
          });
        },
        style: SegmentedButton.styleFrom(
          fixedSize: Size(MediaQuery.of(context).size.width, 40),
        ),
      ),
    );
  }

  Widget _buildMonthNavigator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: _goToPreviousMonth),
          Text(
            DateFormat.yMMMM('id_ID').format(_selectedMonth),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: (DateTime(_selectedMonth.year, _selectedMonth.month + 1).isAfter(DateTime.now()))
                ? null // Menonaktifkan tombol jika bulan berikutnya di masa depan
                : _goToNextMonth,
          ),
        ],
      ),
    );
  }
}