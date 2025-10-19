// lib/pages/statistics_page.dart
import 'package:budgetin_id/pages/account_screen.dart';
import 'package:budgetin_id/pages/auth/service/lock.dart';
import 'package:budgetin_id/pages/wallets/widgets/models/wallet_model.dart';
import 'package:budgetin_id/services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

enum ChartType { bar, pie }

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  ChartType _selectedChartType = ChartType.bar;
  
  @override
  Widget build(BuildContext context) {
    final user = context.watch<User?>();
    final firestoreService = context.watch<FirestoreService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistik'),
        actions: const [AccountPage()],
      ),
      body: user == null
        ? const LockWidget(
            featureName: "Statistik",
            featureIcon: Icons.bar_chart_rounded,
          )
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SegmentedButton<ChartType>(
                  segments: const [
                    ButtonSegment(value: ChartType.bar, label: Text('Batang'), icon: Icon(Icons.bar_chart)),
                    ButtonSegment(value: ChartType.pie, label: Text('Lingkaran'), icon: Icon(Icons.pie_chart)),
                  ],
                  selected: {_selectedChartType},
                  onSelectionChanged: (Set<ChartType> newSelection) {
                    setState(() {
                      _selectedChartType = newSelection.first;
                    });
                  },
                ),
              ),
              Expanded(
                child: StreamBuilder<List<Wallet>>(
                  stream: firestoreService.getWallets(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final wallets = snapshot.data!;
                    if (wallets.isEmpty) {
                      return const Center(child: Text("Anda belum memiliki dompet."));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(8.0, 0, 8.0, 16.0),
                      itemCount: wallets.length,
                      itemBuilder: (context, index) {
                        final wallet = wallets[index];
                        // [SOLUSI] Gunakan widget terpisah dengan Key
                        return _WalletStatCard(
                          key: ValueKey(wallet.id), // Key penting untuk state preservation
                          wallet: wallet,
                          chartType: _selectedChartType,
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
}

// [BARU] Widget terpisah untuk setiap kartu statistik
class _WalletStatCard extends StatefulWidget {
  final Wallet wallet;
  final ChartType chartType;

  const _WalletStatCard({
    super.key,
    required this.wallet,
    required this.chartType,
  });

  @override
  State<_WalletStatCard> createState() => _WalletStatCardState();
}

class _WalletStatCardState extends State<_WalletStatCard> {
  final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.wallet.walletName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Saldo: ${currencyFormatter.format(widget.wallet.balance)}', style: TextStyle(color: Colors.grey.shade700)),
            const Divider(height: 24),
            SizedBox(
              height: 200,
              child: StreamBuilder<Map<String, double>>(
                stream: firestoreService.getMonthlyExpenseByCategory([widget.wallet.id]),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text("Tidak ada data pengeluaran.", style: TextStyle(color: Colors.grey)));
                  }
                  final data = snapshot.data!;
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: widget.chartType == ChartType.bar
                      ? _buildBarChart(data)
                      : _buildPieChart(data),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(Map<String, double> data) {
    int colorIndex = 0;
    final List<Color> chartColors = [Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple, Colors.teal];
    
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        barGroups: data.entries.map((entry) {
          final color = chartColors[colorIndex % chartColors.length];
          colorIndex++;
          return BarChartGroupData(
            x: colorIndex,
            barRods: [
              BarChartRodData(
                toY: entry.value,
                color: color,
                width: 16,
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(show: false),
      ),
    );
  }

  Widget _buildPieChart(Map<String, double> data) {
    final totalExpense = data.values.fold(0.0, (sum, item) => sum + item);
    int colorIndex = 0;
    final List<Color> chartColors = [Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple, Colors.teal];

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: data.entries.map((entry) {
          final color = chartColors[colorIndex++ % chartColors.length];
          final percentage = (entry.value / totalExpense) * 100;
          return PieChartSectionData(
            color: color,
            value: entry.value,
            title: '${percentage.toStringAsFixed(0)}%',
            radius: 50,
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          );
        }).toList(),
      ),
    );
  }
}