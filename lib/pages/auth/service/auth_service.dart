// lib/services/auth_service.dart

import 'package:budgetin_id/services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<User?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException {
      rethrow;
    }
  }

  // [REVISI] Menambahkan parameter displayName untuk registrasi username
  Future<User?> signUpWithEmailAndPassword(String email, String password, String displayName) async {
    try {
      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);
      final user = userCredential.user;

      if (user != null) {
        // [BARU] Simpan username ke profil Firebase Auth & Firestore
        await user.updateDisplayName( displayName);
        await FirestoreService().initializeUserData(user, displayName: displayName);

        // Kirim email verifikasi
        if (!user.emailVerified) {
          var actionCodeSettings = ActionCodeSettings(
            url: 'https://budgetin-id.web.app/verifikasi_email.html', // Pastikan nama file HTML benar
            handleCodeInApp: true, 
            iOSBundleId: 'com.example.budgetinId',
            androidPackageName: 'com.lino.budgetin_id', 
            androidMinimumVersion: '12',
          );
          
          await user.sendEmailVerification(actionCodeSettings);
        }
      }
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
        // [REVISI] Mengirim displayName dari akun Google ke Firestore
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

  // ... (Sisa fungsi lain tetap sama, tidak perlu diubah) ...
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

  Future<void> deleteUserAccount() async {
    try {
      if (currentUser != null) {
        await FirestoreService().deleteUserData();
        await currentUser!.delete();
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        debugPrint('Operasi ini sensitif dan memerlukan autentikasi baru.');
      }
      rethrow;
    }
  }
}