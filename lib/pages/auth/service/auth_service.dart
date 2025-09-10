// lib/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
//import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
/*final FacebookAuth _facebookAuth = FacebookAuth.instance; */

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException {
      rethrow;
    }
  }

  Future<void> signUpAndSendVerificationEmail(String email, String password) async {
    try {
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (userCredential.user != null && !userCredential.user!.emailVerified) {
        await userCredential.user!.sendEmailVerification();
      }
    } on FirebaseAuthException {
      rethrow;
    }
  }

  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null;
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      return userCredential.user;
    } catch (e) {
      debugPrint("Error saat login dengan Google: $e");
      rethrow;
    }
  }
/*
  Future<User?> signInWithFacebook() async {
    try {
      final LoginResult result = await _facebookAuth.login();

      if (result.status == LoginStatus.success) {
        final AccessToken accessToken = result.accessToken!;
        final AuthCredential credential = FacebookAuthProvider.credential(accessToken.token);
        final UserCredential userCredential = await _auth.signInWithCredential(credential);
        return userCredential.user;
      } else {
        debugPrint("Login Facebook dibatalkan atau gagal: ${result.message}");
        return null;
      }
    } on FirebaseAuthException catch (e) {
      debugPrint("Firebase Auth Exception saat login Facebook: ${e.code} - ${e.message}");
      rethrow;
    } catch (e) {
      debugPrint("Error umum saat login dengan Facebook: $e");
      rethrow;
    }
  }*/

  // [TAMBAHAN] Fungsi untuk menautkan akun yang sudah ada dengan Google
  Future<User?> linkWithGoogle() async {
    try {
      if (currentUser == null) throw Exception("Tidak ada pengguna untuk ditautkan.");

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null; // Pengguna membatalkan
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      // Gunakan linkWithCredential untuk menautkan
      final userCredential = await currentUser!.linkWithCredential(credential);
      return userCredential.user;
    } catch (e) {
      debugPrint("Error saat menautkan dengan Google: $e");
      rethrow;
    }
  }

  // [TAMBAHAN] Fungsi untuk menghapus akun pengguna
  Future<void> deleteUserAccount() async {
    try {
      if (currentUser != null) {
        await currentUser!.delete();
        // Proses logout akan ditangani oleh stream authStateChanges
      }
    } on FirebaseAuthException catch (e) {
      // Error ini umum terjadi jika pengguna sudah lama tidak login
      if (e.code == 'requires-recent-login') {
        debugPrint('Operasi ini sensitif dan memerlukan autentikasi baru. Coba login ulang.');
      }
      rethrow; // Lempar kembali error agar UI bisa menanganinya
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    /*await _facebookAuth.logOut(); */
    await _auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException {
      rethrow;
    }
  }
}