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

  bool get hasPasswordProvider => user?.providerData.any((p) => p.providerId == 'password') ?? false;
  bool get hasGoogleProvider => user?.providerData.any((p) => p.providerId == 'google.com') ?? false;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
  
  Future<void> signOut() async {
    await _authService.signOut();
    notifyListeners();
  }

  Future<void> deleteAccountWithVerification({String? password}) async {
    // ... (kode ini tidak berubah)
    if (user == null) throw Exception("Pengguna tidak ditemukan.");
    _setLoading(true);

    try {
      final hasPassword = user!.providerData.any((p) => p.providerId == 'password');

      if (hasPassword) {
        if (password == null || password.isEmpty) {
          throw Exception("Password diperlukan untuk melanjutkan.");
        }
        await _authService.reauthenticateWithPassword(password);
      } else {
        await _authService.reauthenticateWithGoogle();
      }
      
      await _authService.deleteUserAccount();
      notifyListeners();

    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateDisplayName(String newName) async {
    // ... (kode ini tidak berubah)
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
    // ... (kode ini tidak berubah)
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

  Future<void> linkGoogleAccount() async {
    // ... (kode ini tidak berubah)
    _setLoading(true);
    try {
      await _authService.linkWithGoogle();
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'credential-already-in-use') {
        throw Exception('Akun Google ini sudah terhubung dengan pengguna lain.');
      }
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> addPasswordToAccount(String password) async {
    // ... (kode ini tidak berubah)
    _setLoading(true);
    try {
      await _authService.addPasswordLink(password);
      notifyListeners();
    } on FirebaseAuthException catch (e) {
       if (e.code == 'weak-password') {
        throw Exception('Password terlalu lemah.');
      }
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // [BARU] Fungsi untuk mengirim email reset password ke pengguna yang sedang login
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