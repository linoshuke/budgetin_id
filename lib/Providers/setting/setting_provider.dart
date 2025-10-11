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

  bool get hasPasswordProvider => _authService.currentUserProviders.contains('password');
  bool get hasGoogleProvider => _authService.currentUserProviders.contains('google.com');

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
  
  Future<void> signOut() async {
    await _authService.signOut();
    notifyListeners();
  }

  // [PERBAIKAN] Logika ini sekarang sudah valid karena metode di AuthService sudah ada.
  Future<void> deleteAccountWithVerification({String? password}) async {
    if (user == null) throw Exception("Pengguna tidak ditemukan.");
    _setLoading(true);

    try {
      // Cek apakah akun punya metode login password
      if (hasPasswordProvider) {
        if (password == null || password.isEmpty) {
          throw Exception("Password diperlukan untuk melanjutkan.");
        }
        await _authService.reauthenticateWithPassword(password);
      } else {
        // Jika tidak ada password (misal login hanya via Google), re-autentikasi via Google
        await _authService.reauthenticateWithGoogle();
      }
      
      // Setelah re-autentikasi berhasil, lanjutkan hapus akun
      await _authService.deleteUserAccount();
      notifyListeners();

    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateDisplayName(String newName) async {
    if (user == null || newName.trim().isEmpty) return;
    _setLoading(true);
    try {
      await user!.updateDisplayName(newName);
      await _firestoreService.updateUserData({'displayName': newName.trim()});
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating display name: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> pickAndUploadProfileImage() async {
    if (user == null) return;
    _setLoading(true);
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
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
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> linkGoogleAccount() async {
    _setLoading(true);
    try {
      await _authService.linkWithGoogle();
      notifyListeners(); // Beritahu UI bahwa provider telah diperbarui
    } on FirebaseAuthException catch (e) {
      if (e.code == 'credential-already-in-use') {
        throw Exception('Akun Google ini sudah terhubung dengan pengguna lain.');
      } else if (e.code == 'provider-already-linked') {
        // Kasus ini bisa diabaikan atau ditangani dengan pesan "Akun sudah tertaut"
      } else {
        rethrow;
      }
    } finally {
      _setLoading(false);
    }
  }

  // [PERBAIKAN] Memanggil metode 'addPasswordToAccount' yang sudah didefinisikan di AuthService
  Future<void> addPasswordToAccount(String password) async {
    _setLoading(true);
    try {
      await _authService.addPasswordToAccount(password);
      notifyListeners(); // Beritahu UI bahwa provider (password) telah ditambahkan
    } on FirebaseAuthException catch (e) {
       if (e.code == 'weak-password') {
        throw Exception('Password terlalu lemah. Gunakan minimal 6 karakter.');
      }
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> sendPasswordResetEmailForCurrentUser() async {
    if (user == null || user!.email == null) {
      throw Exception("Tidak ada pengguna valid yang sedang login.");
    }
    try {
      await _authService.sendPasswordResetEmail(user!.email!);
    } catch (e) {
      rethrow;
    }
  }
}