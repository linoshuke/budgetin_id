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

  // [BARU] Fungsi untuk login secara anonim
  Future<User?> signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      final user = userCredential.user;
      if (user != null) {
        // Inisialisasi data di Firestore agar pengguna anonim bisa langsung
        // membuat wallet, dll.
        await FirestoreService().initializeUserData(user);
      }
      return user;
    } catch (e) {
      debugPrint("Error saat login anonim: $e");
      rethrow;
    }
  }

  // [BARU] Fungsi untuk menautkan akun anonim dengan Email & Password
  Future<User?> linkWithGoogle() async {
    try {
      if (currentUser == null) {
        throw Exception("Tidak ada pengguna untuk ditautkan.");
      }

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await currentUser!.linkWithCredential(credential);
      final user = userCredential.user;

      // ---- [BARU] Bagian Kritis untuk Memperbaiki Nama ----
      if (user != null) {
        // Jika nama pengguna saat ini masih default/kosong, update dengan nama Google
        if ((user.displayName == null || user.displayName!.isEmpty) &&
            googleUser.displayName != null) {
          await user.updateDisplayName(googleUser.displayName);
        }
        // Jika foto profil saat ini kosong, update dengan foto Google
        if ((user.photoURL == null || user.photoURL!.isEmpty) &&
            googleUser.photoUrl != null) {
          await user.updatePhotoURL(googleUser.photoUrl);
        }
        // Juga update data di Firestore
        await FirestoreService().updateUserData({
          'displayName': user.displayName,
          'photoURL': user.photoURL,
          'email': user.email, // Simpan juga emailnya
        });
      }
      // ---------------------------------------------------

      return user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        // Memberi tahu pengguna bahwa mereka harus login dengan metode lain
        throw FirebaseAuthException(
          code: 'existing-account-error',
          message:
              'Akun dengan email ini sudah ada. Silakan login menggunakan metode yang pernah Anda daftarkan (misal: Email & Password).',
        );
      }
      debugPrint("Error saat menautkan dengan Google: ${e.code}");
      rethrow;
    }
  }

  // [PERBAIKAN] Modifikasi linkWithEmailAndPassword untuk menyimpan email
  Future<User?> linkWithEmailAndPassword(String email, String password) async {
    try {
      if (currentUser == null){
        throw Exception("Tidak ada pengguna untuk ditautkan.");
        }

      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      final userCredential = await currentUser!.linkWithCredential(credential);
      final user = userCredential.user;

      // ---- [BARU] Update data di Firestore setelah menautkan email ----
      if (user != null) {
        await FirestoreService().updateUserData({'email': user.email});
      }
      // -------------------------------------------------------------

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        // Memberi tahu pengguna bahwa mereka harus login dengan metode lain
        throw FirebaseAuthException(
          code: 'existing-account-error',
          message:
              'Akun dengan email ini sudah ada. Silakan login menggunakan metode yang pernah Anda daftarkan (misal: Google).',
        );
      }
      debugPrint("Error saat menautkan dengan email: ${e.code}");
      rethrow;
    }
  }

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

  Future<void> signUpAndSignOut(String email, String password) async {
    try {
      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);
      final user = userCredential.user;

      if (user != null) {
        await FirestoreService().initializeUserData(user);
        if (!user.emailVerified) {
          await user.sendEmailVerification();
        }
        await signOut();
      }
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
        await FirestoreService().initializeUserData(user);
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
