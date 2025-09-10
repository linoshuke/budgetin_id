// lib/pages/home_page.dart (REVISED)

import 'dart:async'; // Diperlukan untuk StreamSubscription
import 'package:budgetin_id/pages/more_page.dart';
import 'package:budgetin_id/services/firestore_service.dart'; // Pastikan path ini benar
import 'package:budgetin_id/pages/wallets/widgets/models/wallet_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Untuk format mata uang
import 'package:provider/provider.dart'; // Untuk mengakses FirestoreService
import 'auth/service/auth_service.dart';
import '/pages/account_router.dart';
import '/pages/history_page.dart';
import '/pages/statistics_page.dart';
import '/pages/wallets/wallet_screen.dart';

// HomePage tetap sama, tidak perlu diubah
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  // Navigasi ke halaman 'Lainnya' akan dihandle di sini

  static final List<Widget> _widgetOptions = <Widget>[
    const HomeContent(),
    const HistoryPage(),
    const WalletsScreen(),
    const StatisticsPage(),
    MorePage(onGoToHome: () {
      // Fungsi ini belum diimplementasikan, tapi strukturnya sudah benar
    }),
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

// [REVISI] HomeContent diubah menjadi StatefulWidget
class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  // State untuk menyimpan daftar dompet dan pilihan pengguna
  List<Wallet> _allWallets = [];
  List<String> _selectedWalletIds = []; // Jika kosong, berarti "semua dompet"
  double _totalBalance = 0.0;
  bool _isLoading = true;

  // StreamSubscription untuk mendengarkan perubahan pada dompet
  StreamSubscription<List<Wallet>>? _walletSubscription;

  @override
  void initState() {
    super.initState();
    _listenToWallets();
  }
  
  @override
  void dispose() {
    // Batalkan subscription untuk mencegah memory leak
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
      // Jika tidak ada yang dipilih, hitung semua
      for (var wallet in _allWallets) {
        sum += wallet.balance;
      }
    } else {
      // Jika ada yang dipilih, hanya hitung yang terpilih
      for (var wallet in _allWallets) {
        if (_selectedWalletIds.contains(wallet.id)) {
          sum += wallet.balance;
        }
      }
    }
    setState(() {
      _totalBalance = sum;
    });
  }
  
  // [BARU] Fungsi untuk menampilkan dialog pemilihan dompet
  Future<void> _showWalletSelectionDialog() async {
    // Salin daftar ID yang sudah terpilih ke variabel sementara
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
                    // Update state utama dengan pilihan dari dialog
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
        actions: const [
          AccountRouter(),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGreeting(),
              const SizedBox(height: 24),
              _buildTotalBalanceCard(), // Widget ini sekarang dinamis
              const SizedBox(height: 24),
              _buildDailySummaryCard(),
              const SizedBox(height: 24),
              _buildMiniChart(),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreeting() {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        final userName = snapshot.data?.displayName ?? 'Tamu';
        return Text(
          'Selamat Datang,\n$userName',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        );
      },
    );
  }

  // [REVISI] Kartu total saldo sekarang interaktif
  Widget _buildTotalBalanceCard() {
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final String subtitle = _selectedWalletIds.isEmpty
        ? 'Semua Dompet'
        : '${_selectedWalletIds.length} Dompet Terpilih';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell( // Dibungkus dengan InkWell agar bisa diklik
        onTap: _showWalletSelectionDialog,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [Colors.indigo.shade400, Colors.indigo.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Subtitle dinamis
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 8),
              // Tampilkan loading atau total saldo
              _isLoading
                  ? const SizedBox(height: 38, child: Center(child: CircularProgressIndicator(color: Colors.white)))
                  : Text(
                      currencyFormatter.format(_totalBalance),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDailySummaryCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ringkasan Hari Ini', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(Icons.arrow_downward, 'Masuk', 'Rp 0', Colors.green),
                _buildSummaryItem(Icons.arrow_upward, 'Keluar', 'Rp 0', Colors.red),
                _buildSummaryItem(Icons.account_balance, 'Selisih', 'Rp 0', Colors.blue),
              ],
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

  Widget _buildMiniChart() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Pengeluaran Bulan Ini', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            padding: const EdgeInsets.all(16),
            height: 200,
            width: double.infinity,
            child: const Center(
              child: Text(
                'Placeholder Grafik Mini',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
        ),
      ],
    );
  }
}