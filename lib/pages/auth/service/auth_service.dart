// lib/services/auth_service.dart (FIXED)

import 'package:budgetin_id/services/firestore_service.dart';
import 'package:budgetin_id/pages/usageservice.dart'; // Pastikan path ini benar
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

// [PERBAIKAN] Pindahkan deklarasi class exception ke luar dari AuthService.
// Sekarang ini adalah top-level class yang valid.
class RequiresRecentLoginException implements Exception {
  final String message = "Silakan login ulang untuk melanjutkan operasi ini.";
  RequiresRecentLoginException();
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  
  final UsageLimiterService _usageLimiter = UsageLimiterService(); 

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // ... (Metode signIn, signUp, sendPasswordResetEmail Anda tetap sama)

  Future<User?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    if (!await _usageLimiter.canPerformAction(LimitedAction.loginOrSignup)) {
      throw UsageLimitExceededException(
          'Anda telah mencapai batas maksimal login. Coba lagi dalam 24 jam.');
    }
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _usageLimiter.recordAction(LimitedAction.loginOrSignup);
      return userCredential.user;
    } on FirebaseAuthException {
      rethrow;
    }
  }

  Future<User?> signUpWithEmailAndPassword(String email, String password, String displayName) async {
    if (!await _usageLimiter.canPerformAction(LimitedAction.loginOrSignup)) {
      throw UsageLimitExceededException(
          'Anda telah mencapai batas maksimal registrasi. Coba lagi dalam 24 jam.');
    }
    try {
      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);
      final user = userCredential.user;
      if (user != null) {
        await user.updateDisplayName(displayName);
        await FirestoreService().initializeUserData(user, displayName: displayName);
        try {
          if (!user.emailVerified) {
            await user.sendEmailVerification();
          }
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
  
  Future<void> sendPasswordResetEmail(String email) async {
    if (!await _usageLimiter.canPerformAction(LimitedAction.resetPassword)) {
      throw UsageLimitExceededException(
          'Anda telah mencapai batas maksimal reset password. Coba lagi dalam 24 jam.');
    }
    try {
      await _auth.sendPasswordResetEmail(email: email);
      await _usageLimiter.recordAction(LimitedAction.resetPassword);
    } on FirebaseAuthException {
      rethrow;
    }
  }

  // Metode deleteUserAccount Anda sudah benar, tidak perlu diubah.
  Future<void> deleteUserAccount() async {
    if (!await _usageLimiter.canPerformAction(LimitedAction.deleteAccount)) {
      throw UsageLimitExceededException(
          'Anda hanya dapat menghapus akun satu kali dalam 24 jam.');
    }
    final user = currentUser;
    if (user == null) {
      throw Exception("Tidak ada pengguna yang login untuk dihapus.");
    }
    try {
      await FirestoreService().deleteUserData(); 
      await user.delete();
      await _usageLimiter.recordAction(LimitedAction.deleteAccount);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        debugPrint('Operasi ini sensitif dan memerlukan autentikasi baru.');
        throw RequiresRecentLoginException();
      }
      rethrow;
    }
  }
  
  // ... (Metode signInWithGoogle, signOut, reauthenticate Anda tetap sama)
  Future<User?> signInWithGoogle() async {
    try {
      await _googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user != null) {
        await FirestoreService().initializeUserData(user, displayName: user.displayName);
      }
      return user;
    } catch (e) {
      debugPrint("Error saat login dengan Google: $e");
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
  
  Future<void> reauthenticateWithPassword(String password) async {
    if (currentUser == null) throw Exception("User not logged in.");
    try {
      final cred = EmailAuthProvider.credential(
        email: currentUser!.email!,
        password: password,
      );
      await currentUser!.reauthenticateWithCredential(cred);
    } on FirebaseAuthException {
      rethrow;
    }
  }

  Future<void> reauthenticateWithGoogle() async {
    // ... (implementasi Anda sudah benar)
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