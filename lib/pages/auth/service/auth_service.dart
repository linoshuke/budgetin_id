// lib/pages/auth/service/auth_service.dart

import 'package:budgetin_id/services/firestore_service.dart';
import 'package:budgetin_id/pages/usageservice.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AccountExistsWithDifferentCredentialException implements Exception {
  final String email;
  final List<String> methods;
  AccountExistsWithDifferentCredentialException(this.email, this.methods);
}

class PasswordVerificationRequiredException implements Exception {
  final AuthCredential credential;
  final String email;
  PasswordVerificationRequiredException(this.credential, this.email);
}

class RequiresRecentLoginException implements Exception {
  final String message = "Silakan login ulang untuk melanjutkan operasi ini.";
  RequiresRecentLoginException();
}

class GoogleSignUpNotAllowedException implements Exception {
  final String message;
  GoogleSignUpNotAllowedException(this.message);
}


class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirestoreService _firestoreService = FirestoreService();
  final UsageService _usageLimiter = UsageService();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  List<String> get currentUserProviders {
    if (currentUser == null) return [];
    return currentUser!.providerData.map((userInfo) => userInfo.providerId).toList();
  }

  Future<User?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    if (!await _usageLimiter.canPerformAction(LimitedAction.loginOrSignup)) {
      throw UsageLimitExceededException('Anda telah mencapai batas maksimal login. Coba lagi dalam 24 jam.');
    }
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      await _usageLimiter.recordAction(LimitedAction.loginOrSignup);
      return userCredential.user;
    } on FirebaseAuthException {
      rethrow;
    }
  }

  Future<User?> signUpWithEmailAndPassword(
    String email,
    String password,
    String displayName,
  ) async {
    if (!await _usageLimiter.canPerformAction(LimitedAction.loginOrSignup)) {
      throw UsageLimitExceededException('Anda telah mencapai batas maksimal registrasi. Coba lagi dalam 24 jam.');
    }
    try {
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      
      final user = userCredential.user;
      if (user != null) {
        await user.updateDisplayName(displayName);
        await _firestoreService.initializeUserData(user, displayName: displayName);

        try {
          await user.sendEmailVerification();
        } on FirebaseAuthException catch (e) {
          if (e.code == 'too-many-requests') {
            debugPrint("Pendaftaran berhasil, tetapi pengiriman email verifikasi diblokir sementara.");
          } else {
            rethrow;
          }
        }
        await _usageLimiter.recordAction(LimitedAction.loginOrSignup);
      }
      return user;
    } on FirebaseAuthException {
      rethrow;
    }
  }

  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      
      if (user != null && userCredential.additionalUserInfo?.isNewUser == true) {
        await user.delete();
        await _googleSignIn.signOut();
        await _auth.signOut();
        throw GoogleSignUpNotAllowedException(
          'Akun Google ini belum terdaftar. Silakan daftar terlebih dahulu.'
        );
      }
      
      if (user != null) {
        await _firestoreService.initializeUserData(user, displayName: user.displayName);
      }
      return user;

    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        final email = e.email;
        if (email != null && e.credential != null) {
            throw PasswordVerificationRequiredException(e.credential!, email);
        }
      }
      debugPrint("Error saat login dengan Google: $e");
      rethrow;
    }
  }

  Future<User?> signUpWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      
      if (user != null) {
        await _firestoreService.initializeUserData(user, displayName: user.displayName);
      }
      return user;

    } on FirebaseAuthException {
      rethrow;
    }
  }


  Future<User?> linkGoogleAfterPasswordVerification(String email, String password, AuthCredential googleCredential) async {
    try {
      final emailCredential = EmailAuthProvider.credential(email: email, password: password);
      final userCredential = await _auth.signInWithCredential(emailCredential);
      final user = userCredential.user;

      if (user == null) {
        throw Exception("Verifikasi password gagal, user tidak ditemukan.");
      }

      await user.linkWithCredential(googleCredential);
      return user;
    } on FirebaseAuthException {
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException {
      rethrow;
    }
  }

  // [PERBAIKAN BUG]
  Future<void> deleteUserAccount() async {
    final user = currentUser;
    if (user == null) throw Exception("Tidak ada pengguna yang login untuk dihapus.");
    
    // Periksa apakah pengguna login dengan Google SEBELUM dihapus
    final isGoogleProvider = user.providerData.any((p) => p.providerId == 'google.com');

    try {
      await _firestoreService.deleteUserData();
      await user.delete();

      // [FIX] Jika pengguna yang dihapus login via Google, putuskan koneksi sepenuhnya.
      // Ini akan membersihkan cache di `google_sign_in` dan memaksa
      // dialog pilihan akun muncul lagi pada login berikutnya.
      if (isGoogleProvider) {
        await _googleSignIn.disconnect();
      }
      
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw RequiresRecentLoginException();
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      // signOut() sudah cukup untuk logout biasa, disconnect() tidak diperlukan di sini
      // agar pengguna tidak perlu re-authorize setiap kali logout.
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      debugPrint("Terjadi error tak terduga saat sign out: $e");
    }
  }
  
  Future<void> linkWithGoogle() async {
    if (currentUser == null) throw Exception("User not logged in.");

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;

      if (googleUser.email != currentUser!.email) {
        await _googleSignIn.signOut();
        throw Exception("Gagal menautkan. Email Google harus sama dengan email terdaftar Anda.");
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      await currentUser!.linkWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'credential-already-in-use') {
        throw Exception("Akun Google ini sudah tertaut ke akun lain.");
      }
      rethrow;
    }
  }
  
  Future<void> addPasswordToAccount(String password) async {
    if (currentUser == null || currentUser!.email == null) {
      throw Exception("User tidak valid untuk menambahkan password.");
    }

    try {
      final AuthCredential credential = EmailAuthProvider.credential(
        email: currentUser!.email!,
        password: password,
      );
      await currentUser!.linkWithCredential(credential);
    } on FirebaseAuthException {
      rethrow;
    }
  }

  Future<void> reauthenticateWithPassword(String password) async {
    if (currentUser == null || currentUser!.email == null) throw Exception("User tidak valid.");
    try {
      final cred = EmailAuthProvider.credential(email: currentUser!.email!, password: password);
      await currentUser!.reauthenticateWithCredential(cred);
    } on FirebaseAuthException {
      rethrow;
    }
  }
  
  Future<void> reauthenticateWithGoogle() async {
    if (currentUser == null) throw Exception("User not logged in.");
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception("Proses login Google dibatalkan.");
      }
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await currentUser!.reauthenticateWithCredential(credential);
    } on FirebaseAuthException {
      rethrow;
    }
  }
}