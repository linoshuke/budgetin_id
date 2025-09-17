// lib/services/auth_service.dart (FIXED)

import 'package:budgetin_id/services/firestore_service.dart';
import 'package:budgetin_id/pages/usageservice.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  
  // [FIX] Inisialisasi service limiter sebagai properti dari class
  final UsageLimiterService _usageLimiter = UsageLimiterService(); 

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<User?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    // Pengecekan limit
    if (!await _usageLimiter.canPerformAction(LimitedAction.loginOrSignup)) {
      throw UsageLimitExceededException(
          'Anda telah mencapai batas maksimal login. Coba lagi dalam 24 jam.');
    }

    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Pencatatan jika berhasil
      await _usageLimiter.recordAction(LimitedAction.loginOrSignup);
      return userCredential.user;
    } on FirebaseAuthException {
      rethrow;
    }
  }

  Future<User?> signUpWithEmailAndPassword(String email, String password, String displayName) async {
    // Pengecekan limit
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

        if (!user.emailVerified) {
          await user.sendEmailVerification();
        }
        // Pencatatan jika berhasil
        await _usageLimiter.recordAction(LimitedAction.loginOrSignup);
      }
      return user;
    } on FirebaseAuthException {
      rethrow;
    }
  }
  
  Future<void> sendPasswordResetEmail(String email) async {
    // Pengecekan limit
    if (!await _usageLimiter.canPerformAction(LimitedAction.resetPassword)) {
      throw UsageLimitExceededException(
          'Anda telah mencapai batas maksimal reset password. Coba lagi dalam 24 jam.');
    }

    try {
      await _auth.sendPasswordResetEmail(email: email);
      // Pencatatan jika berhasil
      await _usageLimiter.recordAction(LimitedAction.resetPassword);
    } on FirebaseAuthException {
      rethrow;
    }
  }

  Future<void> deleteUserAccount() async {
    // Pengecekan limit
    if (!await _usageLimiter.canPerformAction(LimitedAction.deleteAccount)) {
      throw UsageLimitExceededException(
          'Anda hanya dapat menghapus akun satu kali dalam 24 jam.');
    }

    try {
      if (currentUser != null) {
        await FirestoreService().deleteUserData();
        await currentUser!.delete();
        // Pencatatan jika berhasil
        await _usageLimiter.recordAction(LimitedAction.deleteAccount);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        debugPrint('Operasi ini sensitif dan memerlukan autentikasi baru.');
      }
      rethrow;
    }
  }

  // ... sisa kode Anda yang tidak diubah (signInWithGoogle, signOut, reauthenticate, dll) ...
  // tidak perlu dimodifikasi.
  
  Future<User?> signInWithGoogle() async {
    try {
      await _googleSignIn.signOut();
      
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null;
      }
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
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