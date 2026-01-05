import 'package:cloud_firestore/cloud_firestore.dart';

class Wallet {
  final String id;
  final String walletName;
  double balance;
  final String displayPreference;
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

  // Factory untuk parsing dari Firestore (backward compatibility)
  factory Wallet.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;

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
    );
  }

  // Method untuk mengubah instance Wallet menjadi Map untuk Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'walletName': walletName,
      'balance': balance,
      'displayPreference': displayPreference,
      'createdAt': Timestamp.fromDate(createdAt),
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
    };
  }

  Wallet copyWith({
    String? id,
    String? walletName,
    double? balance,
    String? displayPreference,
    DateTime? createdAt,
    String? category,
    String? location,
  }) {
    return Wallet(
      id: id ?? this.id,
      walletName: walletName ?? this.walletName,
      balance: balance ?? this.balance,
      displayPreference: displayPreference ?? this.displayPreference,
      createdAt: createdAt ?? this.createdAt,
      category: category ?? this.category,
      location: location ?? this.location,
    );
  }
}