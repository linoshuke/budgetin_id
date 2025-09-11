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

  // [BARU] Fungsi untuk re-autentikasi dengan Password
  Future<void> reauthenticateWithPassword(String password) async {
    if (currentUser == null) throw Exception("User not logged in.");
    try {
      final cred = EmailAuthProvider.credential(
        email: currentUser!.email!,
        password: password,
      );
      await currentUser!.reauthenticateWithCredential(cred);
    } on FirebaseAuthException {
      rethrow; // Biarkan UI yang menangani error (misal: password salah)
    }
  }

  // [BARU] Fungsi untuk re-autentikasi dengan Google
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

  // [PERBAIKAN] Fungsi hapus akun sekarang memanggil FirestoreService juga
  Future<void> deleteUserAccount() async {
    try {
      if (currentUser != null) {
        // 1. Hapus data dari Firestore terlebih dahulu
        await FirestoreService().deleteUserData();
        // 2. Baru hapus akun dari Firebase Auth
        await currentUser!.delete();
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        debugPrint(
            'Operasi ini sensitif dan memerlukan autentikasi baru. Coba login ulang.');
      }
      rethrow; // Lempar kembali error agar UI bisa menanganinya
    }
  }
  
  // --- Sisa Kode Anda (tidak perlu diubah) ---
  Future<User?> signUpWithEmailAndPassword(String email, String password) async {
    try {
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = userCredential.user;

      if (user != null) {
        await FirestoreService().initializeUserData(user);
      }

      return user;
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
      await _googleSignIn.signOut();
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
      final user = userCredential.user;

      if (user != null) {
        await FirestoreService().initializeUserData(user);
      }

      return user;
    } catch (e) {
      debugPrint("Error saat login dengan Google: $e");
      rethrow;
    }
  }
  
  Future<User?> linkWithGoogle() async {
    try {
      if (currentUser == null) throw Exception("Tidak ada pengguna untuk ditautkan.");

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null; 
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      final userCredential = await currentUser!.linkWithCredential(credential);
      return userCredential.user;
    } catch (e) {
      debugPrint("Error saat menautkan dengan Google: $e");
      rethrow;
    }
  }
  
  Future<void> signOut() async {
    await _googleSignIn.signOut();
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