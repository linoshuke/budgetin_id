// lib/models/transaction_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType { income, expense }

class Transaction {
  final String id;
  final String description;
  final double amount;
  final TransactionType type;
  final DateTime transactionDate;
  final String walletId;

  Transaction({
    required this.id,
    required this.description,
    required this.amount,
    required this.type,
    required this.transactionDate,
    required this.walletId,
  });

  factory Transaction.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Transaction(
      id: doc.id,
      description: data['description'] ?? '',
      amount: (data['amount'] ?? 0.0).toDouble(),
      type: (data['type'] == 'income') ? TransactionType.income : TransactionType.expense,
      transactionDate: (data['transactionDate'] as Timestamp).toDate(),
      walletId: data['walletId'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'description': description,
      'amount': amount,
      'type': type == TransactionType.income ? 'income' : 'expense',
      'transactionDate': Timestamp.fromDate(transactionDate),
      'walletId': walletId,
    };
  }
}