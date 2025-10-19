// lib/pages/home_page.dart 

import 'dart:async';
import 'package:budgetin_id/pages/account_screen.dart';
import 'package:budgetin_id/pages/more_screen.dart';
import 'package:budgetin_id/services/firestore_service.dart';
import 'package:budgetin_id/pages/wallets/widgets/models/wallet_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart'; 
import 'history_screen.dart';
import 'statistics_screen.dart';
import '/pages/wallets/wallet_screen.dart';

// ... (Widget HomePage & _HomePageState tidak berubah) ...
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  static final List<Widget> _widgetOptions = <Widget>[
    const HomeContent(),
    const HistoryPage(),
    const WalletsScreen(),
    const StatisticsPage(),
    MorePage(onGoToHome: () {}),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: BottomAppBar(
        elevation: 8.0,
        padding: EdgeInsets.zero,
        child: SizedBox(
          height: 60.0,
          child: Row(
            children: [
              Expanded(child: _buildNavItem(Icons.home_filled, 'Beranda', 0)),
              Expanded(child: _buildNavItem(Icons.receipt_long, 'Riwayat', 1)),
              Expanded(child: _buildNavItem(Icons.account_balance_wallet, 'Dompet', 2)),
              Expanded(child: _buildNavItem(Icons.bar_chart, 'Statistik', 3)),
              Expanded(child: _buildNavItem(Icons.more_horiz, 'Lainnya', 4)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    final color = isSelected ? Colors.indigo : Colors.grey.shade600;

    return InkWell(
        onTap: () => _onItemTapped(index),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
          child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              transform: Matrix4.translationValues(0, isSelected ? -12.0 : 0, 0),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: color, size: 26),
                    const SizedBox(height: 2),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label,
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ])),
        ));
  }
}


class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  List<Wallet> _allWallets = [];
  List<String> _selectedWalletIds = [];
  double _totalBalance = 0.0;
  bool _isLoading = true;
  StreamSubscription<List<Wallet>>? _walletSubscription;

  @override
  void initState() {
    super.initState();
    _listenToWallets();
  }

  @override
  void dispose() {
    _walletSubscription?.cancel();
    super.dispose();
  }

  void _listenToWallets() {
    final firestoreService = context.read<FirestoreService>();
    _walletSubscription = firestoreService.getWallets().listen((wallets) {
      if (mounted) {
        setState(() {
          _allWallets = wallets;
          _isLoading = false;
          _calculateTotalBalance();
        });
      }
    });
  }

  void _calculateTotalBalance() {
    double sum = 0;
    if (_selectedWalletIds.isEmpty) {
      sum = _allWallets.fold(0, (prev, wallet) => prev + wallet.balance);
    } else {
      sum = _allWallets
          .where((wallet) => _selectedWalletIds.contains(wallet.id))
          .fold(0, (prev, wallet) => prev + wallet.balance);
    }
    setState(() {
      _totalBalance = sum;
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
              title: const Text('Pilih Dompet'),
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
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedWalletIds = tempSelectedIds;
                    });
                    _calculateTotalBalance();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Beranda'),
        backgroundColor: Colors.white,
        actions: const [ AccountPage(), ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGreeting(),
              const SizedBox(height: 24),
              _buildTotalBalanceCard(),
              const SizedBox(height: 24),
              _buildMonthlySummaryCard(), // [NAMA FUNGSI DIUBAH]
              const SizedBox(height: 24),
              _buildMonthlyStatChart(), // [NAMA FUNGSI DIUBAH]
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreeting() {
    final user = context.watch<User?>();
    final userName = user?.displayName ?? 'Tamu';
    return Text(
      'Selamat Datang,\n$userName',
      style: const TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildTotalBalanceCard() {
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final String subtitle = _selectedWalletIds.isEmpty
        ? 'Total Saldo (Semua Dompet)'
        : 'Total Saldo (${_selectedWalletIds.length} Dompet Terpilih)';

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: _showWalletSelectionDialog,
        child: Container(
          height: 180,
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo.shade400, Colors.indigo.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 8),
              _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : Text(
                      currencyFormatter.format(_totalBalance),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
              const Spacer(),
              Align(
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.touch_app_outlined, color: Colors.white70, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Ketuk untuk memilih dompet',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget _buildDailySummaryCard() {
  //   final firestoreService = context.watch<FirestoreService>();
  //   final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       const Text('Ringkasan Hari Ini', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
  //       const SizedBox(height: 12),
  //       Card(
  //         elevation: 1,
  //         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //         child: Padding(
  //           padding: const EdgeInsets.symmetric(vertical: 16.0),
  //           child: StreamBuilder<Map<String, double>>(
  //             stream: firestoreService.getDailySummary(_selectedWalletIds),
  //             builder: (context, snapshot) {
  //               if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
  //                 return const Center(child: SizedBox(height: 78, child: CircularProgressIndicator()));
  //               }
  //               if (snapshot.hasError) {
  //                 return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text("Gagal memuat ringkasan.")));
  //               }

  //               final income = snapshot.data?['income'] ?? 0.0;
  //               final expense = snapshot.data?['expense'] ?? 0.0;
  //               final difference = snapshot.data?['difference'] ?? 0.0;

  //               return Row(
  //                 mainAxisAlignment: MainAxisAlignment.spaceAround,
  //                 children: [
  //                   _buildSummaryItem(Icons.arrow_downward, 'Masuk', currencyFormatter.format(income), Colors.green),
  //                   _buildSummaryItem(Icons.arrow_upward, 'Keluar', currencyFormatter.format(expense), Colors.red),
  //                   _buildSummaryItem(Icons.account_balance, 'Selisih', currencyFormatter.format(difference), Colors.blue),
  //                 ],
  //               );
  //             },
  //           ),
  //         ),
  //       ),
  //     ],
  //   );
  // }
   Widget _buildMonthlySummaryCard() {
    final firestoreService = context.watch<FirestoreService>();
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ringkasan Bulan Ini', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), // Judul diubah
        const SizedBox(height: 12),
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: StreamBuilder<Map<String, double>>(
              // Memanggil metode BARU untuk data bulanan
              stream: firestoreService.getMonthlySummary(_selectedWalletIds),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: SizedBox(height: 78, child: CircularProgressIndicator()));
                }
                if (snapshot.hasError) {
                  return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text("Gagal memuat ringkasan.")));
                }

                final income = snapshot.data?['income'] ?? 0.0;
                final expense = snapshot.data?['expense'] ?? 0.0;
                final difference = snapshot.data?['difference'] ?? 0.0;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem(Icons.arrow_downward, 'Masuk', currencyFormatter.format(income), Colors.green),
                    _buildSummaryItem(Icons.arrow_upward, 'Keluar', currencyFormatter.format(expense), Colors.red),
                    _buildSummaryItem(Icons.account_balance, 'Selisih', currencyFormatter.format(difference), Colors.blue),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(IconData icon, String title, String amount, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 4),
        Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  // [PERUBAHAN UTAMA] Mengganti placeholder dengan Pie Chart dinamis
   Widget _buildMonthlyStatChart() {
    final firestoreService = context.watch<FirestoreService>();
    final user = context.watch<User?>();

    if (user == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Statistik Bulan Ini', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), // Judul diubah
        const SizedBox(height: 12),
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            padding: const EdgeInsets.all(16),
            height: 200,
            width: double.infinity,
            child: StreamBuilder<Map<String, double>>(
              stream: firestoreService.getMonthlyExpenseByCategory(_selectedWalletIds),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('Belum ada data pengeluaran bulan ini.', style: TextStyle(color: Colors.grey)));
                }

                final data = snapshot.data!;
                final totalExpense = data.values.fold(0.0, (sum, item) => sum + item);
                int colorIndex = 0;
                final List<Color> chartColors = [Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple, Colors.teal];

                // Pie chart tidak perlu diubah, sudah benar
                return PieChart(
                  PieChartData(
                    startDegreeOffset: -90,
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: data.entries.map((entry) {
                      final color = chartColors[colorIndex++ % chartColors.length];
                      final percentage = (entry.value / totalExpense) * 100;
                      return PieChartSectionData(
                        color: color,
                        value: entry.value,
                        title: '${percentage.toStringAsFixed(1)}%',
                        radius: 50,
                        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}