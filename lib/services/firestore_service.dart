// lib/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../pages/wallets/widgets/models/wallet_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

   Future<void> updateUserData(Map<String, dynamic> data) async {
    if (_userId == null) return;
    final userRef = _db.collection('users').doc(_userId);
    // Gunakan merge: true untuk update field tanpa menimpa seluruh dokumen
    await userRef.set(data, SetOptions(merge: true));
  }

  // --- Metode Inisialisasi User ---
  Future<void> initializeUserData(User user, {String? displayName}) async {
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

  // [PERBAIKAN UTAMA] Logika ini sekarang menghapus semua data pengguna di Firestore,
  // termasuk semua dompet dan transaksi yang tersimpan di dalam sub-koleksi.
  Future<void> deleteUserData() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception("User tidak login, tidak ada data yang bisa dihapus.");
    }

    final userDocRef = _db.collection('users').doc(user.uid);

    // 1. Hapus sub-koleksi 'transactions'
    final transactionsRef = userDocRef.collection('transactions');
    await _deleteCollection(transactionsRef);

    // 2. Hapus sub-koleksi 'wallets'
    final walletsRef = userDocRef.collection('wallets');
    await _deleteCollection(walletsRef);

    // 3. Terakhir, hapus dokumen utama pengguna itu sendiri
    await userDocRef.delete();
  }

  // [BARU] Helper untuk menghapus semua dokumen dalam sebuah koleksi secara batch.
  // Firestore tidak dapat menghapus koleksi secara langsung dari sisi klien,
  // jadi kita harus menghapus setiap dokumen di dalamnya satu per satu.
  Future<void> _deleteCollection(CollectionReference collectionRef) async {
    // Ambil semua dokumen dalam koleksi
    final querySnapshot = await collectionRef.get();

    // Jika koleksi sudah kosong, tidak ada yang perlu dilakukan
    if (querySnapshot.docs.isEmpty) {
      return;
    }

    // Buat batch write untuk efisiensi
    final batch = _db.batch();
    for (final doc in querySnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Lakukan semua operasi hapus dalam satu panggilan ke server
    await batch.commit();
  }

  
  Future<void> createDefaultWallets() async {
    if (_userId == null) return;
    final walletsRef = _db.collection('users').doc(_userId).collection('wallets');
    final existingWallets = await walletsRef.limit(1).get();
    if (existingWallets.docs.isNotEmpty) return;

    WriteBatch batch = _db.batch();
    
    final List<Map<String, dynamic>> defaultWalletsData = [
      {'walletName': 'Cash', 'category': 'Uang Jajan', 'location': 'Cash'},
      {'walletName': 'Gopay', 'category': 'Uang Jajan', 'location': 'Qris'},
      {'walletName': 'Bank Indonesia', 'category': 'Investasi', 'location': 'Bank'}
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
      });
    }
    await batch.commit();
  }

  Future<void> addWallet({
    required String name,
    required String category,
    required String location,
  }) async {
    if (_userId == null) return;
    await _db.collection('users').doc(_userId).collection('wallets').add({
      'walletName': name,
      'category': category,
      'location': location,
      'balance': 0.0,
      'displayPreference': 'monthly',
      'createdAt': FieldValue.serverTimestamp(),
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

  Stream<List<Wallet>> getWallets() {
    if (_userId == null) return Stream.value([]);
    return _db.collection('users').doc(_userId).collection('wallets')
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => Wallet.fromFirestore(doc)).toList());
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

  Stream<List<Transaction>> getTransactions(String walletId, DateTimeRange dateRange) {
    if (_userId == null) return Stream.value([]);
    return _db.collection('users').doc(_userId).collection('transactions')
      .where('walletId', isEqualTo: walletId)
      .where('transactionDate', isGreaterThanOrEqualTo: dateRange.start)
      .where('transactionDate', isLessThanOrEqualTo: dateRange.end)
      .orderBy('transactionDate', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => Transaction.fromFirestore(doc)).toList());
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
    batch.set(transactionRef, newTransaction.toFirestore());
    double amountChange = (type == TransactionType.income) ? amount : -amount;
    batch.update(walletRef, {'balance': FieldValue.increment(amountChange)});

    await batch.commit();
  }
}