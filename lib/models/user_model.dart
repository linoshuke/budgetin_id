// lib/models/user_model.dart

class UserModel {
  final String id;
  final String displayName;
  final String email;
  final String? photoURL;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.id,
    required this.displayName,
    required this.email,
    this.photoURL,
    this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      displayName: json['displayName'] ?? json['display_name'] ?? 'User',
      email: json['email'] ?? '',
      photoURL: json['photoURL'] ?? json['photo_url'],
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at']) 
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.tryParse(json['updated_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'email': email,
      'photoURL': photoURL,
    };
  }

  UserModel copyWith({
    String? id,
    String? displayName,
    String? email,
    String? photoURL,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoURL: photoURL ?? this.photoURL,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, displayName: $displayName, email: $email)';
  }
}
