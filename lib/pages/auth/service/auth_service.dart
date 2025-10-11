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

      // [FIX] Jika pengguna saat ini adalah tamu, logout dulu sebelum login ke akun lain.
      // Ini memastikan sesi tamu tidak tercampur dengan sesi pengguna terdaftar yang sudah ada.
      if (currentUser != null && currentUser!.isAnonymous) {
        await _auth.signOut();
        // Setelah sign out, proses login akan membuat sesi baru untuk pengguna.
      }

      final userCredential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      await _usageLimiter.recordAction(LimitedAction.loginOrSignup);
      return userCredential.user;
    } on FirebaseAuthException {
      rethrow;
    }
  }

  // [REFACTOR LOGIC] Mengimplementasikan "Account Linking" untuk upgrade akun tamu.
  Future<User?> signUpWithEmailAndPassword(
    String email,
    String password,
    String displayName,
  ) async {
    if (!await _usageLimiter.canPerformAction(LimitedAction.loginOrSignup)) {
      throw UsageLimitExceededException('Anda telah mencapai batas maksimal registrasi. Coba lagi dalam 24 jam.');
    }
    try {
      UserCredential userCredential;
      final activeUser = _auth.currentUser;

      // Jika pengguna saat ini adalah tamu (anonymous), tautkan kredensial baru.
      // Ini akan mengubah akun tamu menjadi akun email/password permanen dengan UID yang sama.
      if (activeUser != null && activeUser.isAnonymous) {
        final credential = EmailAuthProvider.credential(email: email, password: password);
        userCredential = await activeUser.linkWithCredential(credential);
      } else {
        // Jika tidak ada sesi atau sesi bukan tamu, buat akun baru seperti biasa.
        userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      }

      final user = userCredential.user;
      if (user != null) {
        await user.updateDisplayName(displayName);
        // Inisialisasi data pengguna (aman dipanggil, tidak akan menimpa data yang ada).
        await _firestoreService.initializeUserData(user, displayName: displayName);

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

  // [REFACTOR LOGIC] Mengimplementasikan "Account Linking" untuk upgrade atau login via Google.
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // Pengguna membatalkan proses.

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final activeUser = _auth.currentUser;
      UserCredential userCredential;

      // Jika pengguna saat ini adalah tamu, tautkan kredensial Google.
      // Ini akan mengubah akun tamu menjadi akun Google permanen dengan UID yang sama.
      if (activeUser != null && activeUser.isAnonymous) {
        userCredential = await activeUser.linkWithCredential(credential);
      } else {
        // Jika tidak ada sesi atau sesi bukan tamu, login dengan Google seperti biasa.
        userCredential = await _auth.signInWithCredential(credential);
      }
      
      final user = userCredential.user;
      if (user != null) {
        // Inisialisasi data pengguna (aman dipanggil, tidak akan menimpa data yang ada).
        await _firestoreService.initializeUserData(user, displayName: user.displayName);
      }
      return user;

    } on FirebaseAuthException catch (e) {
      // Menangani kasus di mana akun Google sudah ada tetapi perlu ditautkan ke akun email/password.
      if (e.code == 'account-exists-with-different-credential') {
        final email = e.email;
        if (email != null && e.credential != null) {
          final signInMethods = await _auth.fetchSignInMethodsForEmail(email);
          if (signInMethods.contains('password')) {
            // Lemparkan exception khusus agar UI bisa menangani verifikasi password.
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
      // Gunakan signIn (bukan reauthenticate) karena konteksnya adalah login awal.
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

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    // [FIX] Setelah sign out, buat sesi tamu baru agar aplikasi tidak crash.
    await _auth.signInAnonymously();
  }
  
  Future<void> linkWithGoogle() async {
    if (currentUser == null) throw Exception("User not logged in.");

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return; // Batal oleh pengguna, jangan lempar error.

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