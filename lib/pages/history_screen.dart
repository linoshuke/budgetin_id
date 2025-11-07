// lib/pages/history_page.dart
import 'dart:async';
import 'package:budgetin_id/pages/auth/service/lock.dart';
import 'package:budgetin_id/pages/wallets/widgets/models/transaction_model.dart';
import 'package:budgetin_id/pages/wallets/widgets/models/wallet_model.dart';
import 'package:budgetin_id/services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'account_screen.dart';

enum DisplayPeriod { daily, monthly }

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  // State untuk filter
  DisplayPeriod _selectedPeriod = DisplayPeriod.monthly;
  late DateTime _selectedMonth;
  late DateTimeRange _currentDateRange;
  
  // State untuk filter dompet
  List<Wallet> _allWallets = [];
  List<String> _selectedWalletIds = [];
  StreamSubscription? _walletSubscription;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now();
    _updateDateRange();
    _listenToWallets();
  }
  
  @override
  void dispose() {
    _walletSubscription?.cancel();
    super.dispose();
  }

  void _listenToWallets() {
    // Ambil daftar dompet untuk ditampilkan di dialog filter
    final firestoreService = context.read<FirestoreService>();
    _walletSubscription = firestoreService.getWallets().listen((wallets) {
      if (mounted) {
        setState(() {
          _allWallets = wallets;
        });
      }
    });
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
    if (nextMonth.isAfter(now)) return;
    setState(() {
      _selectedMonth = nextMonth;
      _updateDateRange();
    });
  }

  Future<void> _showWalletSelectionDialog() async {
    final List<String> tempSelectedIds = List.from(_selectedWalletIds);
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Filter Dompet'),
              content: SizedBox(
                width: double.maxFinite,
                child: _allWallets.isEmpty
                    ? const Center(child: Text("Anda belum memiliki dompet."))
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _allWallets.length,
                        itemBuilder: (context, index) {
                          final wallet = _allWallets[index];
                          final isSelected = tempSelectedIds.contains(wallet.id);
                          return CheckboxListTile(
                            title: Text(wallet.walletName),
                            value: isSelected,
                            onChanged: (bool? value) {
                              setDialogState(() {
                                if (value == true) {
                                  tempSelectedIds.add(wallet.id);
                                } else {
                                  tempSelectedIds.remove(wallet.id);
                                }
                              });
                            },
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(onPressed: () => setState(() => _selectedWalletIds = []), child: const Text("Reset")),
                ElevatedButton(
                  onPressed: () {
                    setState(() { _selectedWalletIds = tempSelectedIds; });
                    Navigator.of(context).pop();
                  },
                  child: const Text('Terapkan'),
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
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final user = context.watch<User?>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat'),
        actions: const [AccountPage()],
      ),
      body: user == null
        ? const LockWidget(
            featureName: "Riwayat",
            featureIcon: Icons.receipt_long_rounded,
          )
        : Column(
            children: [
              _buildPeriodFilter(),
              if (_selectedPeriod == DisplayPeriod.monthly) _buildMonthNavigator(),
              _buildWalletFilterChip(),
              Expanded(
                child: StreamBuilder<List<Transaction>>(
                  stream: firestoreService.getFilteredTransactions(
                    dateRange: _currentDateRange,
                    walletIds: _selectedWalletIds,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return const Center(child: Text("Terjadi kesalahan."));
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Text(
                          "Belum ada transaksi pada periode ini.",
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    final transactions = snapshot.data!;
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        final transaction = transactions[index];
                        final isIncome = transaction.type == TransactionType.income;
                        final wallet = _allWallets.firstWhere((w) => w.id == transaction.walletId, orElse: () => Wallet(id: '', walletName: 'N/A', createdAt: DateTime.now(), category: '', location: ''));

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: (isIncome ? Colors.green : Colors.red).withValues(alpha: 0.1),
                              child: Icon(
                                isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                color: isIncome ? Colors.green : Colors.red,
                              ),
                            ),
                            title: Text(transaction.description),
                            subtitle: Text("${wallet.walletName}\n${DateFormat.yMMMMEEEEd('id_ID').add_Hm().format(transaction.transactionDate)}"),
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
    );
  }

  Widget _buildPeriodFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: SegmentedButton<DisplayPeriod>(
        segments: const <ButtonSegment<DisplayPeriod>>[
          ButtonSegment<DisplayPeriod>(value: DisplayPeriod.daily, label: Text('Harian'), icon: Icon(Icons.today)),
          ButtonSegment<DisplayPeriod>(value: DisplayPeriod.monthly, label: Text('Bulanan'), icon: Icon(Icons.calendar_month)),
        ],
        selected: <DisplayPeriod>{_selectedPeriod},
        onSelectionChanged: (Set<DisplayPeriod> newSelection) {
          setState(() {
            _selectedPeriod = newSelection.first;
            if (_selectedPeriod == DisplayPeriod.monthly) {
              _selectedMonth = DateTime.now();
            }
            _updateDateRange();
          });
        },
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
          Text(DateFormat.yMMMM('id_ID').format(_selectedMonth), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: (DateTime(_selectedMonth.year, _selectedMonth.month + 1).isAfter(DateTime.now())) ? null : _goToNextMonth,
          ),
        ],
      ),
    );
  }

  Widget _buildWalletFilterChip() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ActionChip(
          avatar: const Icon(Icons.filter_list),
          label: Text(_selectedWalletIds.isEmpty ? 'Semua Dompet' : '${_selectedWalletIds.length} Dompet Dipilih'),
          onPressed: _showWalletSelectionDialog,
        ),
      ),
    );
  }
}