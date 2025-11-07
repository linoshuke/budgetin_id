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

  factory Wallet.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;

    // [PERBAIKAN] Membuat parsing data menjadi lebih aman (defensif)
    DateTime createdAtDate;
    if (data['createdAt'] is Timestamp) {
      // Jika field ada dan tipenya benar
      createdAtDate = (data['createdAt'] as Timestamp).toDate();
    } else {
      // Jika field tidak ada atau tipenya salah, berikan nilai default
      // Ini mencegah aplikasi dari crash.
      createdAtDate = DateTime.now();
    }
    // ----------------------------------------------------

    return Wallet(
      id: doc.id,
      walletName: data['walletName'] ?? 'Tanpa Nama',
      balance: (data['balance'] as num?)?.toDouble() ?? 0.0, // Cara aman lain untuk parsing angka
      displayPreference: data['displayPreference'] ?? 'monthly',
      createdAt: createdAtDate, 
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