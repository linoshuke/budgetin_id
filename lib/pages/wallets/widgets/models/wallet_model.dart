import 'package:cloud_firestore/cloud_firestore.dart';

class Wallet {
  final String id;
  final String walletName;
  double balance;
  final String displayPreference; // 'daily' atau 'monthly'
  final DateTime createdAt;
  final String category;
  final String location;

  Wallet({
    required this.id,
    required this.walletName,
    this.balance = 0.0,
    this.displayPreference = 'monthly',
    required this.createdAt,
     required this.category, 
    required this.location, 
  });

  // Factory constructor untuk membuat instance Wallet dari Firestore document
  factory Wallet.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Wallet(
      id: doc.id,
      walletName: data['walletName'] ?? '',
      balance: (data['balance'] ?? 0).toDouble(),
      displayPreference: data['displayPreference'] ?? 'monthly',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      category: data['category'] ?? 'Lainnya', 
      location: data['location'] ?? 'Tidak Diketahui', 
    );
  }

  // Method untuk mengubah instance Wallet menjadi Map untuk disimpan ke Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'walletName': walletName,
      'balance': balance,
      'displayPreference': displayPreference,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}