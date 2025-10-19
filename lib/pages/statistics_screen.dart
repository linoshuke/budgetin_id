// lib/pages/statistics_page.dart

import 'package:budgetin_id/pages/auth/service/lock.dart';
import 'package:budgetin_id/pages/wallets/widgets/models/transaction_model.dart';
import 'package:budgetin_id/pages/wallets/widgets/models/wallet_model.dart';
import 'package:budgetin_id/services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page?.round() ?? 0;
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<User?>();
    final firestoreService = context.watch<FirestoreService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistik Bulanan'),
      ),
      body: user == null
        ? const LockWidget(
            featureName: "Statistik",
            featureIcon: Icons.bar_chart_rounded,
          )
        : StreamBuilder<List<Wallet>>(
            stream: firestoreService.getWallets(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final wallets = snapshot.data!;
              if (wallets.isEmpty) return const Center(child: Text("Anda belum memiliki dompet."));
              
              return Column(
                children: [
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: wallets.length,
                      itemBuilder: (context, index) {
                        return _WalletStatPage(
                          key: ValueKey(wallets[index].id),
                          wallet: wallets[index],
                        );
                      },
                    ),
                  ),
                  if (wallets.length > 1) ...[
                    const SizedBox(height: 8),
                    _buildPageIndicator(wallets.length),
                    const SizedBox(height: 16),
                  ]
                ],
              );
            },
          ),
    );
  }

  Widget _buildPageIndicator(int pageCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(pageCount, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          height: 8.0,
          width: _currentPage == index ? 24.0 : 8.0,
          decoration: BoxDecoration(
            color: _currentPage == index ? Theme.of(context).primaryColor : Colors.grey.shade400,
            borderRadius: BorderRadius.circular(12),
          ),
        );
      }),
    );
  }
}

class _WalletStatPage extends StatelessWidget {
  final Wallet wallet;
  const _WalletStatPage({super.key, required this.wallet});

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();
    final monthName = DateFormat.yMMMM('id_ID').format(DateTime.now());

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(wallet.walletName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text('Ringkasan transaksi bulan $monthName', style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                child: StreamBuilder<Map<int, List<Transaction>>>(
                  stream: firestoreService.getMonthlyTransactionsGroupedByDay(wallet.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("Belum ada data transaksi bulan ini.", style: TextStyle(color: Colors.grey)));
                    
                    return _buildSideBySideBarChart(context, snapshot.data!);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // [PERUBAHAN UTAMA] Menggunakan dua batang terpisah (side-by-side)
  Widget _buildSideBySideBarChart(BuildContext context, Map<int, List<Transaction>> data) {
    final currencyFormatter = NumberFormat.compact(locale: 'id_ID');
    final detailCurrencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    double maxY = 0;
    data.forEach((day, transactions) {
      double dailyIncome = transactions.where((t) => t.type == TransactionType.income).fold(0, (sum, item) => sum + item.amount);
      double dailyExpense = transactions.where((t) => t.type == TransactionType.expense).fold(0, (sum, item) => sum + item.amount);
      if (dailyIncome > maxY) maxY = dailyIncome;
      if (dailyExpense > maxY) maxY = dailyExpense;
    });
    if (maxY == 0) maxY = 100000;
    maxY = maxY * 1.2;

    return BarChart(
      BarChartData(
        maxY: maxY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final day = group.x.toInt();
              final isIncome = rod.color == Colors.green;
              final transactionsForDay = data[day]!;

              final relevantTransactions = transactionsForDay
                  .where((t) => isIncome ? t.type == TransactionType.income : t.type == TransactionType.expense)
                  .toList();
              
              if (relevantTransactions.isEmpty) return null;

              final title = '${isIncome ? 'Pemasukan' : 'Pengeluaran'} (Tgl $day)';
              final details = relevantTransactions
                  .map((t) => '${t.description}\n${detailCurrencyFormatter.format(t.amount)}')
                  .join('\n\n');

              return BarTooltipItem(
                '$title\n',
                TextStyle(color: isIncome ? Colors.greenAccent : Colors.orangeAccent, fontWeight: FontWeight.bold),
                children: [TextSpan(text: details, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.normal))],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) => Padding(padding: const EdgeInsets.only(top: 4.0), child: Text('Tgl ${value.toInt()}')),
              interval: 5,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: maxY / 4,
              getTitlesWidget: (value, meta) => Text(currencyFormatter.format(value)),
              reservedSize: 40,
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxY / 4),
        barGroups: data.entries.map((entry) {
          final day = entry.key;
          final transactions = entry.value;

          final totalIncome = transactions.where((t) => t.type == TransactionType.income).fold(0.0, (sum, item) => sum + item.amount);
          final totalExpense = transactions.where((t) => t.type == TransactionType.expense).fold(0.0, (sum, item) => sum + item.amount);

          return BarChartGroupData(
            x: day,
            barRods: [
              // Batang Pemasukan (Hijau)
              BarChartRodData(toY: totalIncome, color: Colors.green, width: 6, borderRadius: BorderRadius.circular(4)),
              // Batang Pengeluaran (Merah)
              BarChartRodData(toY: totalExpense, color: Colors.red, width: 6, borderRadius: BorderRadius.circular(4)),
            ],
          );
        }).toList(),
      ),
    );
  }
}