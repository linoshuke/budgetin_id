// lib/Providers/setting/setting_provider.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../pages/auth/service/auth_service.dart';
import '/services/firestore_service.dart';
import '/services/storage_service.dart'; 

class SettingsProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();

  User? get user => _authService.currentUser;
  bool get isAnonymous => user?.isAnonymous ?? true;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
  
  Future<void> signOut() async {
    await _authService.signOut();
  }

  /// [PERBAIKAN] Logika diubah untuk selalu memprioritaskan verifikasi password jika tersedia.
  Future<void> deleteAccountWithVerification({String? password}) async {
    if (user == null) throw Exception("Pengguna tidak ditemukan.");
    _setLoading(true);

    try {
      // Cek apakah akun ini memiliki kredensial password.
      final hasPasswordProvider = user!.providerData.any((p) => p.providerId == 'password');

      if (hasPasswordProvider) {
        // Jika YA, password adalah satu-satunya metode yang diterima untuk re-autentikasi.
        if (password == null || password.isEmpty) {
          throw Exception("Password diperlukan untuk melanjutkan.");
        }
        await _authService.reauthenticateWithPassword(password);
      } else {
        // Jika TIDAK, baru kita coba metode lain seperti Google.
        await _authService.reauthenticateWithGoogle();
      }
      
      // Jika re-autentikasi berhasil, sesi sekarang sudah "segar". Lanjutkan untuk menghapus akun.
      await _authService.deleteUserAccount();

    } catch (e) {
      _setLoading(false);
      rethrow;
    }
  }

  Future<void> updateDisplayName(String newName) async {
    if (user == null || newName.trim().isEmpty) return;
    _setLoading(true);
    try {
      await user!.updateDisplayName(newName);
      await _firestoreService.updateUserData({'displayName': newName});
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating display name: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> pickAndUploadProfileImage() async {
    if (user == null) return;
    _setLoading(true);
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) {
        _setLoading(false);
        return;
      }
      
      final imageUrl = await _storageService.uploadProfileImage(user!.uid, File(image.path));
      await user!.updatePhotoURL(imageUrl);
      await _firestoreService.updateUserData({'photoURL': imageUrl});
      notifyListeners();
    } catch (e) {
      debugPrint('Error uploading profile image: $e');
    } finally {
      _setLoading(false);
    }
  }
}