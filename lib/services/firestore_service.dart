// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  // --- Metode Inisialisasi User ---
  Future<void> initializeUserData(User user) async {
    final userRef = _db.collection('users').doc(user.uid);
    final doc = await userRef.get();

    if (!doc.exists) {
      await userRef.set({
        'email': user.email ?? '',
        'displayName': user.displayName ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await createDefaultWallets();
    }
  }

  // --- Metode Wallet ---
  Future<void> createDefaultWallets() async {
    if (_userId == null) return;
    final walletsRef = _db.collection('users').doc(_userId).collection('wallets');
    final existingWallets = await walletsRef.limit(1).get();
    if (existingWallets.docs.isNotEmpty) return;

    WriteBatch batch = _db.batch();
    List<String> defaultWallets = ['Cash', 'Gopay', 'Bank Indonesia'];

    for (var name in defaultWallets) {
      final newWalletRef = walletsRef.doc();
      batch.set(newWalletRef, {
        'walletName': name,
        'balance': 0.0,
        'displayPreference': 'monthly',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Stream<List<Wallet>> getWallets() {
    if (_userId == null) return Stream.value([]);
    return _db
        .collection('users')
        .doc(_userId)
        .collection('wallets')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Wallet.fromFirestore(doc)).toList());
  }

  Stream<Wallet> getWallet(String walletId) {
    if (_userId == null) return Stream.error('User not logged in');
    return _db
        .collection('users')
        .doc(_userId)
        .collection('wallets')
        .doc(walletId)
        .snapshots()
        .map((doc) => Wallet.fromFirestore(doc));
  }

  Future<void> addWallet(String walletName) async {
    if (_userId == null) return;
    await _db.collection('users').doc(_userId).collection('wallets').add({
      'walletName': walletName,
      'balance': 0.0,
      'displayPreference': 'monthly',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateWalletName(String walletId, String newName) async {
    if (_userId == null) return;
    await _db
        .collection('users')
        .doc(_userId)
        .collection('wallets')
        .doc(walletId)
        .update({'walletName': newName});
  }

  Future<void> updateWalletPreference(String walletId, String preference) async {
    if (_userId == null) return;
    await _db
        .collection('users')
        .doc(_userId)
        .collection('wallets')
        .doc(walletId)
        .update({'displayPreference': preference});
  }

  // [REVISI] Menggantikan getWalletStats dengan Stream untuk update real-time
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

    return _db
        .collection('users')
        .doc(_userId)
        .collection('transactions') // Query koleksi transaksi utama
        .where('walletId', isEqualTo: walletId) // Filter berdasarkan ID wallet
        .where('transactionDate', isGreaterThanOrEqualTo: start)
        .where('transactionDate', isLessThanOrEqualTo: end)
        .snapshots()
        .map((snapshot) {
      double income = 0;
      double expense = 0;
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

  // --- Metode Transaksi ---

  // [REVISI] getTransactions sekarang menerima rentang tanggal untuk filtering
  Stream<List<Transaction>> getTransactions(String walletId, DateTimeRange dateRange) {
    if (_userId == null) return Stream.value([]);
    return _db
        .collection('users')
        .doc(_userId)
        .collection('transactions')
        .where('walletId', isEqualTo: walletId)
        .where('transactionDate', isGreaterThanOrEqualTo: dateRange.start)
        .where('transactionDate', isLessThanOrEqualTo: dateRange.end)
        .orderBy('transactionDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Transaction.fromFirestore(doc))
            .toList());
  }

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

    WriteBatch batch = _db.batch();
    // 1. Buat dokumen transaksi baru
    batch.set(transactionRef, newTransaction.toFirestore());
    // 2. Perbarui saldo wallet secara atomik
    double amountChange = (type == TransactionType.income) ? amount : -amount;
    batch.update(walletRef, {'balance': FieldValue.increment(amountChange)});

    await batch.commit();
  }

  Future<void> setUserData(String uid, Map<String, String> map) async {}
}