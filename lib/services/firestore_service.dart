// lib/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../pages/wallets/widgets/models/transaction_model.dart';
import '../pages/wallets/widgets/models/wallet_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  // ========================================
  // USER DOCUMENT
  // ========================================

  Stream<DocumentSnapshot> get userDocumentStream {
    if (_userId == null) {
      return Stream.empty();
    }
    return _db.collection('users').doc(_userId).snapshots();
  }

   Future<void> updateUserData(Map<String, dynamic> data) async {
    if (_userId == null) return;
    final userRef = _db.collection('users').doc(_userId);
    await userRef.set(data, SetOptions(merge: true));
  }

  Future<void> initializeUserData(User user, {String? displayName}) async {
    final userRef = _db.collection('users').doc(user.uid);
    final doc = await userRef.get();

    if (!doc.exists) {
      await userRef.set({
        'email': user.email ?? '',
        'displayName': user.displayName ?? user.email?.split('@').first ?? 'User',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await createDefaultWallets();
    }
  }
  
  Future<void> deleteUserData() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception("User tidak login, tidak ada data yang bisa dihapus.");
    }
    final userDocRef = _db.collection('users').doc(user.uid);
    await _deleteCollection(userDocRef.collection('transactions'));
    await _deleteCollection(userDocRef.collection('wallets'));
    await userDocRef.delete();
  }

  Future<void> _deleteCollection(CollectionReference collectionRef) async {
    final querySnapshot = await collectionRef.limit(500).get();
    if (querySnapshot.docs.isEmpty) {
      return;
    }
    final batch = _db.batch();
    for (final doc in querySnapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    if (querySnapshot.size >= 500) {
      await _deleteCollection(collectionRef);
    }
  }

  // ========================================
  // WALLET OPERATIONS
  // ========================================

  Future<void> createDefaultWallets() async {
    if (_userId == null) return;
    final walletsRef = _db.collection('users').doc(_userId).collection('wallets');
    final existingWallets = await walletsRef.limit(1).get();
    if (existingWallets.docs.isNotEmpty) return;
    
    final now = DateTime.now();
    WriteBatch batch = _db.batch();
    final List<Map<String, dynamic>> defaultWalletsData = [
      {'walletName': 'Dompet Tunai', 'category': 'Uang Fisik', 'location': 'Cash'},
      {'walletName': 'GoPay', 'category': 'E-Wallet', 'location': 'Qris'},
      {'walletName': 'Rekening Bank', 'category': 'Tabungan', 'location': 'Bank'}
    ];
    for (var walletData in defaultWalletsData) {
      final newWalletRef = walletsRef.doc();
      batch.set(newWalletRef, {
        'walletName': walletData['walletName'],
        'category': walletData['category'],
        'location': walletData['location'],
        'balance': 0.0,
        'displayPreference': 'monthly',
        'createdAt': FieldValue.serverTimestamp(),
        // Aggregation counters (initialized)
        'monthlyIncome': 0.0,
        'monthlyExpense': 0.0,
        'lastResetMonth': now.month,
        'lastResetYear': now.year,
      });
    }
    await batch.commit();
  }

  Future<void> addWallet({ required String name, required String category, required String location, }) async {
    if (_userId == null) return;
    final now = DateTime.now();
    await _db.collection('users').doc(_userId).collection('wallets').add({
      'walletName': name,
      'category': category,
      'location': location,
      'balance': 0.0,
      'displayPreference': 'monthly',
      'createdAt': FieldValue.serverTimestamp(),
      // Aggregation counters (initialized)
      'monthlyIncome': 0.0,
      'monthlyExpense': 0.0,
      'lastResetMonth': now.month,
      'lastResetYear': now.year,
    });
  }
  
  Future<void> deleteWallet(String walletId) async {
    if (_userId == null) return;
    final walletRef = _db.collection('users').doc(_userId).collection('wallets').doc(walletId);
    final transactionsRef = _db.collection('users').doc(_userId).collection('transactions');
    WriteBatch batch = _db.batch();
    final transactionsToDelete = await transactionsRef.where('walletId', isEqualTo: walletId).get();
    for (final doc in transactionsToDelete.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(walletRef);
    await batch.commit();
  }

  // Real-time stream untuk wallets (tetap diperlukan untuk UI reaktif)
  Stream<List<Wallet>> getWallets() {
    if (_userId == null) return Stream.value([]);
    return _db.collection('users').doc(_userId).collection('wallets')
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => Wallet.fromFirestore(doc)).toList());
  }

  // [OPTIMASI] One-time read untuk wallets (hemat reads)
  Future<List<Wallet>> getWalletsOnce() async {
    if (_userId == null) return [];
    final snapshot = await _db.collection('users').doc(_userId).collection('wallets')
      .orderBy('createdAt', descending: false)
      .get();
    return snapshot.docs.map((doc) => Wallet.fromFirestore(doc)).toList();
  }

  Stream<Wallet> getWallet(String walletId) {
    if (_userId == null) return Stream.error('User not logged in');
    return _db.collection('users').doc(_userId).collection('wallets').doc(walletId)
      .snapshots().map((doc) => Wallet.fromFirestore(doc));
  }
  
  Future<void> updateWalletName(String walletId, String newName) async {
    if (_userId == null) return;
    await _db.collection('users').doc(_userId).collection('wallets').doc(walletId)
      .update({'walletName': newName});
  }

  Future<void> updateWalletPreference(String walletId, String preference) async {
    if (_userId == null) return;
    await _db.collection('users').doc(_userId).collection('wallets').doc(walletId)
      .update({'displayPreference': preference});
  }

  // ========================================
  // [OPTIMASI] MONTHLY COUNTER OPERATIONS
  // ========================================

  /// Reset counter jika sudah bulan baru
  Future<void> resetMonthlyCountersIfNeeded(String walletId) async {
    if (_userId == null) return;
    
    final walletRef = _db.collection('users').doc(_userId).collection('wallets').doc(walletId);
    final walletDoc = await walletRef.get();
    
    if (!walletDoc.exists) return;
    
    final data = walletDoc.data()!;
    final lastResetMonth = data['lastResetMonth'] as int? ?? 0;
    final lastResetYear = data['lastResetYear'] as int? ?? 0;
    final now = DateTime.now();
    
    // Jika bulan/tahun berbeda, reset counter
    if (lastResetMonth != now.month || lastResetYear != now.year) {
      await walletRef.update({
        'monthlyIncome': 0.0,
        'monthlyExpense': 0.0,
        'lastResetMonth': now.month,
        'lastResetYear': now.year,
      });
    }
  }

  /// Reset semua wallet counters jika perlu
  Future<void> resetAllWalletCountersIfNeeded() async {
    if (_userId == null) return;
    
    final wallets = await getWalletsOnce();
    final now = DateTime.now();
    
    WriteBatch batch = _db.batch();
    bool needsBatch = false;
    
    for (var wallet in wallets) {
      if (wallet.needsMonthlyReset()) {
        final walletRef = _db.collection('users').doc(_userId).collection('wallets').doc(wallet.id);
        batch.update(walletRef, {
          'monthlyIncome': 0.0,
          'monthlyExpense': 0.0,
          'lastResetMonth': now.month,
          'lastResetYear': now.year,
        });
        needsBatch = true;
      }
    }
    
    if (needsBatch) {
      await batch.commit();
    }
  }

  /// [OPTIMASI] Get monthly summary dari counters (1 read per wallet, bukan ratusan)
  Stream<Map<String, double>> getMonthlySummaryFromCounters(List<String> walletIds) {
    if (_userId == null) return Stream.value({'income': 0, 'expense': 0, 'difference': 0});
    
    return getWallets().map((wallets) {
      double totalIncome = 0;
      double totalExpense = 0;
      
      final now = DateTime.now();
      
      for (var wallet in wallets) {
        // Filter by selected wallets if specified
        if (walletIds.isNotEmpty && !walletIds.contains(wallet.id)) {
          continue;
        }
        
        // Hanya hitung jika counter masih valid (bulan ini)
        if (wallet.lastResetMonth == now.month && wallet.lastResetYear == now.year) {
          totalIncome += wallet.monthlyIncome;
          totalExpense += wallet.monthlyExpense;
        }
      }
      
      return {
        'income': totalIncome,
        'expense': totalExpense,
        'difference': totalIncome - totalExpense,
      };
    });
  }

  // ========================================
  // WALLET STATS (tetap query, untuk daily)
  // ========================================

  Stream<Map<String, double>> getWalletStatsStream(String walletId, String preference) {
    if (_userId == null) return Stream.value({'income': 0, 'expense': 0});
    DateTime now = DateTime.now();
    DateTime start;
    DateTime end;
    if (preference == 'daily') {
      start = DateTime(now.year, now.month, now.day);
      end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else { // 'monthly'
      start = DateTime(now.year, now.month, 1);
      end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    }
    return _db.collection('users').doc(_userId).collection('transactions')
      .where('walletId', isEqualTo: walletId)
      .where('transactionDate', isGreaterThanOrEqualTo: start)
      .where('transactionDate', isLessThanOrEqualTo: end)
      .limit(100) // [OPTIMASI] Limit untuk hemat reads
      .snapshots()
      .map((snapshot) {
        double income = 0; double expense = 0;
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final type = data['type'] as String;
          final amount = (data['amount'] as num).toDouble();
          if (type == TransactionType.income.name) {
            income += amount;
          } else {
            expense += amount;
          }
        }
        return {'income': income, 'expense': expense};
    });
  }

  // ========================================
  // TRANSACTION OPERATIONS
  // ========================================

  // [OPTIMASI] Dengan limit dan pagination
  Stream<List<Transaction>> getTransactions(String walletId, DateTimeRange dateRange, {int limit = 50}) {
    if (_userId == null) return Stream.value([]);
    return _db.collection('users').doc(_userId).collection('transactions')
      .where('walletId', isEqualTo: walletId)
      .where('transactionDate', isGreaterThanOrEqualTo: dateRange.start)
      .where('transactionDate', isLessThanOrEqualTo: dateRange.end)
      .orderBy('transactionDate', descending: true)
      .limit(limit) // [OPTIMASI] Limit
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => Transaction.fromFirestore(doc)).toList());
  }
  
  // [LEGACY] Daily summary - masih perlu query (untuk backward compatibility)
  Stream<Map<String, double>> getDailySummary(List<String> walletIds) {
    if (_userId == null) return Stream.value({'income': 0, 'expense': 0, 'difference': 0});
    DateTime now = DateTime.now();
    DateTime start = DateTime(now.year, now.month, now.day);
    DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    Query query = _db.collection('users').doc(_userId).collection('transactions');
    if (walletIds.isNotEmpty) {
      query = query.where('walletId', whereIn: walletIds);
    }
    return query
      .where('transactionDate', isGreaterThanOrEqualTo: start)
      .where('transactionDate', isLessThanOrEqualTo: end)
      .limit(100) // [OPTIMASI] Limit
      .snapshots()
      .map((snapshot) {
        double income = 0; double expense = 0;
        for (var doc in snapshot.docs) {
          final transaction = Transaction.fromFirestore(doc);
          if (transaction.type == TransactionType.income) {
            income += transaction.amount;
          } else {
            expense += transaction.amount;
          }
        }
        return {
          'income': income, 
          'expense': expense,
          'difference': income - expense
        };
      });
  }

  // [LEGACY] Monthly summary - gunakan getMonthlySummaryFromCounters untuk optimasi
   Stream<Map<String, double>> getMonthlySummary(List<String> walletIds) {
    // [OPTIMASI] Gunakan counter-based method
    return getMonthlySummaryFromCounters(walletIds);
  }

  // [OPTIMASI] Dengan limit
  Stream<List<Transaction>> getFilteredTransactions({ 
    required DateTimeRange dateRange, 
    List<String> walletIds = const [], 
    int limit = 50,
  }) {
    if (_userId == null) return Stream.value([]);
    Query query = _db.collection('users').doc(_userId).collection('transactions')
      .where('transactionDate', isGreaterThanOrEqualTo: dateRange.start)
      .where('transactionDate', isLessThanOrEqualTo: dateRange.end);
    if (walletIds.isNotEmpty) {
      query = query.where('walletId', whereIn: walletIds);
    }
    return query
      .orderBy('transactionDate', descending: true)
      .limit(limit) // [OPTIMASI] Limit
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => Transaction.fromFirestore(doc)).toList());
  }

  // [OPTIMASI] Dengan limit
   Stream<Map<String, double>> getMonthlyExpenseByCategory(List<String> walletIds, {int limit = 100}) {
    if (_userId == null) return Stream.value({});

    DateTime now = DateTime.now();
    DateTime startOfMonth = DateTime(now.year, now.month, 1);
    DateTime endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    Query query = _db.collection('users').doc(_userId).collection('transactions')
        .where('type', isEqualTo: 'expense')
        .where('transactionDate', isGreaterThanOrEqualTo: startOfMonth)
        .where('transactionDate', isLessThanOrEqualTo: endOfMonth);

    if (walletIds.isNotEmpty) {
        query = query.where('walletId', whereIn: walletIds);
    }

    return query.limit(limit).snapshots().map((snapshot) {
      Map<String, double> categoryExpenses = {};
      for (var doc in snapshot.docs) {
        final transaction = Transaction.fromFirestore(doc);
        String category = transaction.description; 
        categoryExpenses.update(category, (value) => value + transaction.amount, ifAbsent: () => transaction.amount);
      }
      return categoryExpenses;
    });
  }

    Stream<Map<int, Map<String, double>>> getMonthlyTransactionSummary(String walletId, {int limit = 100}) {
    if (_userId == null) return Stream.value({});

    DateTime now = DateTime.now();
    DateTime startOfMonth = DateTime(now.year, now.month, 1);
    DateTime endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    return _db.collection('users').doc(_userId).collection('transactions')
      .where('walletId', isEqualTo: walletId)
      .where('transactionDate', isGreaterThanOrEqualTo: startOfMonth)
      .where('transactionDate', isLessThanOrEqualTo: endOfMonth)
      .orderBy('transactionDate')
      .limit(limit) // [OPTIMASI] Limit
      .snapshots()
      .map((snapshot) {
        Map<int, Map<String, double>> dailyTotals = {};

        for (var doc in snapshot.docs) {
          final transaction = Transaction.fromFirestore(doc);
          final day = transaction.transactionDate.day;

          dailyTotals.putIfAbsent(day, () => {'income': 0.0, 'expense': 0.0});

          if (transaction.type == TransactionType.income) {
            dailyTotals[day]!['income'] = (dailyTotals[day]!['income'] ?? 0) + transaction.amount;
          } else {
            dailyTotals[day]!['expense'] = (dailyTotals[day]!['expense'] ?? 0) + transaction.amount;
          }
        }
        return dailyTotals;
      });
  }

  Stream<Map<int, List<Transaction>>> getMonthlyTransactionsGroupedByDay(String walletId, {int limit = 100}) {
    if (_userId == null) return Stream.value({});

    DateTime now = DateTime.now();
    DateTime startOfMonth = DateTime(now.year, now.month, 1);
    DateTime endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    return _db.collection('users').doc(_userId).collection('transactions')
      .where('walletId', isEqualTo: walletId)
      .where('transactionDate', isGreaterThanOrEqualTo: startOfMonth)
      .where('transactionDate', isLessThanOrEqualTo: endOfMonth)
      .orderBy('transactionDate')
      .limit(limit) // [OPTIMASI] Limit
      .snapshots()
      .map((snapshot) {
        Map<int, List<Transaction>> groupedTransactions = {};
        for (var doc in snapshot.docs) {
          final transaction = Transaction.fromFirestore(doc);
          final day = transaction.transactionDate.day;

          if (!groupedTransactions.containsKey(day)) {
            groupedTransactions[day] = [];
          }
          groupedTransactions[day]!.add(transaction);
        }
        return groupedTransactions;
      });
  }
  
  // [OPTIMASI] addTransaction dengan update counter
  Future<void> addTransaction({ 
    required String walletId, 
    required String description, 
    required double amount, 
    required TransactionType type, 
  }) async {
    if (_userId == null) return;
    
    final walletRef = _db.collection('users').doc(_userId).collection('wallets').doc(walletId);
    final transactionRef = _db.collection('users').doc(_userId).collection('transactions').doc();
    
    final newTransaction = Transaction(
      id: transactionRef.id,
      description: description,
      amount: amount,
      type: type,
      transactionDate: DateTime.now(),
      walletId: walletId,
    );
    
    // Cek apakah perlu reset counter dulu
    await resetMonthlyCountersIfNeeded(walletId);
    
    WriteBatch batch = _db.batch();
    
    // Set transaksi baru
    batch.set(transactionRef, newTransaction.toFirestore());
    
    // Update balance
    double amountChange = (type == TransactionType.income) ? amount : -amount;
    batch.update(walletRef, {'balance': FieldValue.increment(amountChange)});
    
    // [OPTIMASI] Update monthly counter
    String counterField = (type == TransactionType.income) ? 'monthlyIncome' : 'monthlyExpense';
    batch.update(walletRef, {counterField: FieldValue.increment(amount)});
    
    await batch.commit();
  }
}