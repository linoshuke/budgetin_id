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
  bool get isAnonymous => user?.isAnonymous ?? false;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
  
  Future<void> signOut() async {
    _setLoading(true);
    await _authService.signOut();
    // Tidak perlu setLoading(false) karena widget tree akan rebuild
  }

  // [PERBAIKAN] Fungsi ini sekarang hanya memanggil service
  // dan membiarkan UI menangani semua jenis error.
  Future<void> deleteAccount() async {
    _setLoading(true);
    try {
      await _authService.deleteUserAccount();
      // Jika berhasil, AuthWrapper akan menangani navigasi secara otomatis.
      // Tidak perlu setLoading(false) di sini.
    } catch (e) {
      // Jika terjadi error (APAPUN JENISNYA), hentikan loading
      _setLoading(false);
      // dan lempar kembali error tersebut agar UI bisa menanganinya.
      rethrow;
    }
  }

  Future<void> reauthenticateAndDelete({String? password}) async {
    if (user == null) return;
    _setLoading(true);

    try {
      final providerId = user!.providerData.first.providerId;

      if (providerId == 'password' && password != null) {
        await _authService.reauthenticateWithPassword(password);
      } else if (providerId == 'google.com') {
        await _authService.reauthenticateWithGoogle();
      } else {
        throw Exception("Metode re-autentikasi tidak didukung.");
      }

      // Jika re-autentikasi berhasil, coba hapus lagi.
      await _authService.deleteUserAccount();
    } catch (e) {
      _setLoading(false);
      debugPrint('Error saat re-autentikasi dan hapus: $e');
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