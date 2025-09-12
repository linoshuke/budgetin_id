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
  final StorageService _storageService = StorageService(); // Asumsi Anda punya service ini
  final ImagePicker _picker = ImagePicker();

  User? get user => _authService.currentUser;
  
  // [BARU] Getter untuk memeriksa status anonim
  bool get isAnonymous => user?.isAnonymous ?? false;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
  
  // [BARU] Fungsi untuk menautkan dengan Email
  Future<void> linkWithEmail(String email, String password) async {
    _setLoading(true);
    try {
      await _authService.linkWithEmailAndPassword(email, password);
      notifyListeners(); // Memberi tahu UI bahwa status user (isAnonymous) berubah
    } catch (e) {
      debugPrint('Error menautkan email di provider: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Fungsi linkWithGoogle yang sudah ada akan digunakan untuk menautkan juga
  Future<void> linkWithGoogle() async {
    _setLoading(true);
    try {
      await _authService.linkWithGoogle();
      notifyListeners(); 
    } catch (e) {
      debugPrint('Error menautkan Google di provider: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    // Untuk pengguna anonim, signOut akan menghapus sesi mereka.
    // Jika mereka kembali, sesi anonim baru akan dibuat.
    await _authService.signOut();
  }

  // [PERBAIKAN] Fungsi deleteAccount menjadi lebih sederhana
  Future<void> deleteAccount() async {
    _setLoading(true);
    try {
      await _authService.deleteUserAccount();
      // Navigasi akan ditangani oleh AuthWrapper secara otomatis
    } on FirebaseAuthException {
      _setLoading(false); // Pastikan loading berhenti jika ada error
      rethrow; // Lempar lagi agar UI bisa menangani
    }
  }

  // [BARU] Fungsi untuk handle re-autentikasi lalu menghapus
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

      // Jika re-autentikasi berhasil, coba hapus lagi
      await _authService.deleteUserAccount();
    } catch (e) {
      _setLoading(false);
      debugPrint('Error saat re-autentikasi dan hapus: $e');
      rethrow;
    }
  }

  // --- Sisa Kode Anda (tidak perlu diubah) ---
  Future<void> updateDisplayName(String newName) async {
    if (user == null || newName.trim().isEmpty) return;
    _setLoading(true);
    try {
      await user!.updateDisplayName(newName);
      await _firestoreService.updateUserData({'displayName': newName});
      notifyListeners();
    } catch (e) {
      debugPrint('e');
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
      debugPrint('e = $e');
    } finally {
      _setLoading(false);
    }
  }
}