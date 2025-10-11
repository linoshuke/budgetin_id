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
      final signInMethods = await _auth.fetchSignInMethodsForEmail(email);
      if (signInMethods.isNotEmpty && !signInMethods.contains('password')) {
        throw AccountExistsWithDifferentCredentialException(email, signInMethods);
      }
      
      // [LOGIC DISEDERHANAKAN] Tidak ada lagi pengecekan user anonim.
      final userCredential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      await _usageLimiter.recordAction(LimitedAction.loginOrSignup);
      return userCredential.user;
    } on FirebaseAuthException {
      rethrow;
    }
  }

  // [REVISI LOGIC] Menghapus logika "Account Linking" dari anonim.
  // Fungsi ini sekarang murni membuat akun baru.
  Future<User?> signUpWithEmailAndPassword(
    String email,
    String password,
    String displayName,
  ) async {
    if (!await _usageLimiter.canPerformAction(LimitedAction.loginOrSignup)) {
      throw UsageLimitExceededException('Anda telah mencapai batas maksimal registrasi. Coba lagi dalam 24 jam.');
    }
    try {
      // Selalu buat pengguna baru karena tidak ada lagi sesi tamu untuk di-upgrade.
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      
      final user = userCredential.user;
      if (user != null) {
        await user.updateDisplayName(displayName);
        // Inisialisasi data pengguna saat pertama kali dibuat.
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

  // [REVISI LOGIC] Menghapus logika "Account Linking" dari anonim.
  // Fungsi ini sekarang murni untuk sign-in atau sign-up via Google.
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Selalu sign-in dengan kredensial. Jika user belum ada, Firebase akan membuatnya.
      final userCredential = await _auth.signInWithCredential(credential);
      
      final user = userCredential.user;
      if (user != null) {
        // Panggil inisialisasi. Fungsi ini aman karena tidak akan menimpa data yang ada.
        await _firestoreService.initializeUserData(user, displayName: user.displayName);
      }
      return user;

    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        final email = e.email;
        if (email != null && e.credential != null) {
          final signInMethods = await _auth.fetchSignInMethodsForEmail(email);
          if (signInMethods.contains('password')) {
            throw PasswordVerificationRequiredException(e.credential!, email);
          }
        }
      }
      debugPrint("Error saat login dengan Google: $e");
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

  Future<void> deleteUserAccount() async {
    final user = currentUser;
    if (user == null) throw Exception("Tidak ada pengguna yang login untuk dihapus.");

    try {
      await _firestoreService.deleteUserData();
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw RequiresRecentLoginException();
      }
      rethrow;
    }
  }

  // [REVISI LOGIC] Menghapus signInAnonymously() setelah logout.
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      debugPrint("Terjadi error tak terduga saat sign out: $e");
    }
  }
  
  // Sisa fungsi (linkWithGoogle, addPasswordToAccount, reauthenticate) tidak berubah
  // karena fungsinya untuk manajemen akun yang sudah login, bukan untuk alur awal.
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