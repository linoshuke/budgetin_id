import 'package:cloud_firestore/cloud_firestore.dart';

class Wallet {
  final String id;
  final String walletName;
  double balance;
  final String displayPreference;
  final DateTime createdAt;
  final String category;
  final String location;
  
  // Aggregation counters untuk optimasi Firebase reads
  double monthlyIncome;
  double monthlyExpense;
  int lastResetMonth; // Bulan terakhir counter di-reset (1-12)
  int lastResetYear;  // Tahun terakhir counter di-reset

  Wallet({
    required this.id,
    required this.walletName,
    this.balance = 0.0,
    this.displayPreference = 'monthly',
    required this.createdAt,
    required this.category, 
    required this.location,
    this.monthlyIncome = 0.0,
    this.monthlyExpense = 0.0,
    this.lastResetMonth = 0,
    this.lastResetYear = 0,
  });

  // Factory untuk parsing dari Firestore (backward compatibility)
  factory Wallet.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;

    // Parsing createdAt dengan aman
    DateTime createdAtDate;
    if (data['createdAt'] is Timestamp) {
      createdAtDate = (data['createdAt'] as Timestamp).toDate();
    } else {
      createdAtDate = DateTime.now();
    }

    return Wallet(
      id: doc.id,
      walletName: data['walletName'] ?? 'Tanpa Nama',
      balance: (data['balance'] as num?)?.toDouble() ?? 0.0,
      displayPreference: data['displayPreference'] ?? 'monthly',
      createdAt: createdAtDate, 
      category: data['category'] ?? 'Lainnya', 
      location: data['location'] ?? 'Tidak Diketahui',
      // Aggregation counters
      monthlyIncome: (data['monthlyIncome'] as num?)?.toDouble() ?? 0.0,
      monthlyExpense: (data['monthlyExpense'] as num?)?.toDouble() ?? 0.0,
      lastResetMonth: (data['lastResetMonth'] as int?) ?? 0,
      lastResetYear: (data['lastResetYear'] as int?) ?? 0,
    );
  }

  // Factory untuk parsing dari Laravel API (JSON)
  factory Wallet.fromJson(Map<String, dynamic> json) {
    DateTime createdAtDate;
    if (json['created_at'] != null) {
      createdAtDate = DateTime.tryParse(json['created_at']) ?? DateTime.now();
    } else if (json['createdAt'] != null) {
      createdAtDate = DateTime.tryParse(json['createdAt']) ?? DateTime.now();
    } else {
      createdAtDate = DateTime.now();
    }

    return Wallet(
      id: json['id']?.toString() ?? '',
      walletName: json['walletName'] ?? json['wallet_name'] ?? 'Tanpa Nama',
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      displayPreference: json['displayPreference'] ?? json['display_preference'] ?? 'monthly',
      createdAt: createdAtDate,
      category: json['category'] ?? 'Lainnya',
      location: json['location'] ?? 'Tidak Diketahui',
      monthlyIncome: (json['monthlyIncome'] as num?)?.toDouble() ?? 0.0,
      monthlyExpense: (json['monthlyExpense'] as num?)?.toDouble() ?? 0.0,
      lastResetMonth: (json['lastResetMonth'] as int?) ?? 0,
      lastResetYear: (json['lastResetYear'] as int?) ?? 0,
    );
  }

  // Method untuk mengubah instance Wallet menjadi Map untuk Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'walletName': walletName,
      'balance': balance,
      'displayPreference': displayPreference,
      'createdAt': Timestamp.fromDate(createdAt),
      'category': category,
      'location': location,
      'monthlyIncome': monthlyIncome,
      'monthlyExpense': monthlyExpense,
      'lastResetMonth': lastResetMonth,
      'lastResetYear': lastResetYear,
    };
  }

  // Method untuk mengubah instance Wallet menjadi Map untuk Laravel API
  Map<String, dynamic> toJson() {
    return {
      'walletName': walletName,
      'category': category,
      'location': location,
      'balance': balance,
      'displayPreference': displayPreference,
      'monthlyIncome': monthlyIncome,
      'monthlyExpense': monthlyExpense,
      'lastResetMonth': lastResetMonth,
      'lastResetYear': lastResetYear,
    };
  }

  // Helper untuk cek apakah counter perlu di-reset (bulan baru)
  bool needsMonthlyReset() {
    final now = DateTime.now();
    return lastResetMonth != now.month || lastResetYear != now.year;
  }

  Wallet copyWith({
    String? id,
    String? walletName,
    double? balance,
    String? displayPreference,
    DateTime? createdAt,
    String? category,
    String? location,
    double? monthlyIncome,
    double? monthlyExpense,
    int? lastResetMonth,
    int? lastResetYear,
  }) {
    return Wallet(
      id: id ?? this.id,
      walletName: walletName ?? this.walletName,
      balance: balance ?? this.balance,
      displayPreference: displayPreference ?? this.displayPreference,
      createdAt: createdAt ?? this.createdAt,
      category: category ?? this.category,
      location: location ?? this.location,
      monthlyIncome: monthlyIncome ?? this.monthlyIncome,
      monthlyExpense: monthlyExpense ?? this.monthlyExpense,
      lastResetMonth: lastResetMonth ?? this.lastResetMonth,
      lastResetYear: lastResetYear ?? this.lastResetYear,
    );
  }
}