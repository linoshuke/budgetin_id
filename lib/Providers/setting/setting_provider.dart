// lib/presentation/providers/settings_provider.dart

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

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // UPDATE NAMA TAMPILAN (Tidak Berubah)
  Future<void> updateDisplayName(String newName) async {
    if (user == null || newName.trim().isEmpty) return;
    _setLoading(true);
    try {
      await user!.updateDisplayName(newName);
      await _firestoreService.setUserData(user!.uid, {'displayName': newName});
      notifyListeners();
    } catch (e) {
      debugPrint('e');
    } finally {
      _setLoading(false);
    }
  }

  // PILIH DAN UPLOAD FOTO PROFIL 
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
      await _firestoreService.setUserData(user!.uid, {'photoURL': imageUrl});
      notifyListeners();
    } catch (e) {
      debugPrint('e = $e');
    } finally {
      _setLoading(false);
    }
  }

  //  HAPUS AKUN
  Future<void> deleteAccount() async {
    _setLoading(true);
    try {
      await _authService.deleteUserAccount();
      // Navigasi akan ditangani oleh AuthWrapper secara otomatis
    } catch (e) {
      debugPrint('e = $e'); 
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Fungsi untuk login dengan Google
  Future<void> linkWithGoogle() async {
    _setLoading(true);
    try {
      await _authService.linkWithGoogle();
      notifyListeners(); 
    } catch (e) {
      debugPrint('e = $e'); // Handle error, misal: akun Google sudah tertaut ke user lain
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    await _authService.signOut();
  }
}