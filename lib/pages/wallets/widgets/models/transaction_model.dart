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

  // Factory untuk parsing dari Firestore (backward compatibility)
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

  // Factory untuk parsing dari Laravel API (JSON)
  factory Transaction.fromJson(Map<String, dynamic> json) {
    DateTime transactionDateTime;
    if (json['transactionDate'] != null) {
      transactionDateTime = DateTime.tryParse(json['transactionDate']) ?? DateTime.now();
    } else if (json['transaction_date'] != null) {
      transactionDateTime = DateTime.tryParse(json['transaction_date']) ?? DateTime.now();
    } else {
      transactionDateTime = DateTime.now();
    }

    return Transaction(
      id: json['id']?.toString() ?? '',
      description: json['description'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      type: (json['type'] == 'income') ? TransactionType.income : TransactionType.expense,
      transactionDate: transactionDateTime,
      walletId: json['wallet_id']?.toString() ?? json['walletId']?.toString() ?? '',
    );
  }

  // Method untuk mengubah instance Transaction menjadi Map untuk Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'description': description,
      'amount': amount,
      'type': type == TransactionType.income ? 'income' : 'expense',
      'transactionDate': Timestamp.fromDate(transactionDate),
      'walletId': walletId,
    };
  }

  // Method untuk mengubah instance Transaction menjadi Map untuk Laravel API
  Map<String, dynamic> toJson() {
    return {
      'wallet_id': walletId,
      'description': description,
      'amount': amount,
      'type': type == TransactionType.income ? 'income' : 'expense',
      'transactionDate': transactionDate.toIso8601String(),
    };
  }

  Transaction copyWith({
    String? id,
    String? description,
    double? amount,
    TransactionType? type,
    DateTime? transactionDate,
    String? walletId,
  }) {
    return Transaction(
      id: id ?? this.id,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      transactionDate: transactionDate ?? this.transactionDate,
      walletId: walletId ?? this.walletId,
    );
  }
}