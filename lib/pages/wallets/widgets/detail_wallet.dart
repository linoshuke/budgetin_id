// lib/pages/wallets/widgets/detail_wallet.dart (REVISED)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import './models/transaction_model.dart';
import './models/wallet_model.dart';
import '../../../services/firestore_service.dart';
import '../service/thousand_formatter.dart';


// Enum untuk pilihan periode tampilan
enum DisplayPeriod { daily, monthly }

class WalletDetailScreen extends StatefulWidget {
  final String walletId;

  const WalletDetailScreen({super.key, required this.walletId});

  @override
  State<WalletDetailScreen> createState() => _WalletDetailScreenState();
}

class _WalletDetailScreenState extends State<WalletDetailScreen> {
  late DateTime _selectedMonth;
  late DateTimeRange _currentDateRange;
  // Menginisialisasi periode default ke bulanan
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
      } else { // Logika untuk filter harian
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
    if (nextMonth.isAfter(now)) return;
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
          appBar: AppBar(
            title: Text(wallet.walletName),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: Column(
            children: [
              _buildHeader(context, wallet, currencyFormatter),
              // Menampilkan navigasi bulan hanya jika filter bulanan aktif
              if (_selectedPeriod == DisplayPeriod.monthly) _buildMonthNavigator(),
              const Padding(
                padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0),
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
                    if (transactionSnapshot.hasError) {
                      debugPrint("Error fetching transactions: ${transactionSnapshot.error}");
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            "Terjadi kesalahan saat memuat transaksi. Anda mungkin perlu membuat index komposit di Firestore. Cek log untuk detail.",
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    if (!transactionSnapshot.hasData || transactionSnapshot.data!.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text(
                            "Belum ada transaksi pada periode ini.",
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    final transactions = transactionSnapshot.data!;
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        final transaction = transactions[index];
                        final isIncome = transaction.type == TransactionType.income;
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: (isIncome ? Colors.green : Colors.red).withOpacity(0.1),
                              child: Icon(
                                isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                color: isIncome ? Colors.green : Colors.red,
                              ),
                            ),
                            title: Text(transaction.description),
                            subtitle: Text(DateFormat.yMMMMEEEEd('id_ID').add_Hm().format(transaction.transactionDate)),
                            trailing: Text(
                              "${isIncome ? '+' : '-'} ${currencyFormatter.format(transaction.amount)}",
                              style: TextStyle(
                                color: isIncome ? Colors.green.shade700 : Colors.red.shade700,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
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
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddTransactionDialog(context),
            tooltip: "Tambah Transaksi",
            icon: const Icon(Icons.add),
            label: const Text("Transaksi"),
          ),
        );
      },
    );
  }

  // [PERUBAHAN UTAMA] Card dibuat lebih ringkas dan ToggleButtons di dalamnya
  // kini berfungsi sebagai filter riwayat transaksi.
  Widget _buildHeader(BuildContext context, Wallet wallet, NumberFormat currencyFormatter) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0), // Padding vertikal dikurangi
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.blue.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade900.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Total Saldo Saat Ini",
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            currencyFormatter.format(wallet.balance),
            style: const TextStyle(
              fontSize: 30, // Ukuran font saldo sedikit dikurangi
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 16), // Jarak dikurangi
          Center(
            child: ToggleButtons(
              isSelected: [
                _selectedPeriod == DisplayPeriod.daily,
                _selectedPeriod == DisplayPeriod.monthly,
              ],
              onPressed: (index) {
                setState(() {
                  _selectedPeriod = index == 0 ? DisplayPeriod.daily : DisplayPeriod.monthly;
                  // Reset ke bulan ini jika user memilih filter bulanan
                  if (_selectedPeriod == DisplayPeriod.monthly) {
                    _selectedMonth = DateTime.now();
                  }
                  _updateDateRange();
                });
              },
              // Styling sesuai permintaan Anda
              borderRadius: BorderRadius.circular(8),
              color: Colors.white70,
              selectedColor: Colors.blue.shade800,
              fillColor: Colors.white,
              splashColor: Colors.white.withOpacity(0.2),
              constraints: BoxConstraints(minHeight: 40.0, minWidth: (MediaQuery.of(context).size.width - 82) / 2),
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.today, size: 18),
                      SizedBox(width: 8),
                      Text("Harian"),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_month, size: 18),
                      SizedBox(width: 8),
                      Text("Bulanan"),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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