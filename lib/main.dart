// lib/main.dart

import 'package:budgetin_id/pages/auth/service/auth_handler.dart';
import 'package:budgetin_id/pages/auth/service/email_verification.dart';
import 'package:budgetin_id/pages/home_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:budgetin_id/pages/auth/service/auth_service.dart';
import 'package:budgetin_id/services/firestore_service.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await FirebaseAppCheck.instance.activate(
    androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
  );

  // [PERBAIKAN UTAMA] Logika untuk Guest Mode
  // Jika tidak ada pengguna yang login (baik permanen maupun anonim),
  // maka buat sesi anonim baru secara otomatis.
  if (FirebaseAuth.instance.currentUser == null) {
    try {
      await FirebaseAuth.instance.signInAnonymously();
      debugPrint("Sesi anonim baru telah dibuat untuk pengguna tamu.");
    } catch (e) {
      debugPrint("Gagal membuat sesi anonim saat startup: $e");
    }
  }

  await initializeDateFormatting('id_ID', null);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
      ],
      child: MaterialApp(
        title: 'Budgetin',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true,
          // ... sisa tema Anda tidak berubah
        ),
        debugShowCheckedModeBanner: false,
        home: const AuthHandler( // Anda bisa mempertimbangkan apakah AuthHandler masih perlu
          child: AuthWrapper(),
        ),
      )
    );
  }
}

// [PERBAIKAN] AuthWrapper disederhanakan untuk alur Guest Mode
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        final user = snapshot.data;

        // Jika user ada (baik anonim maupun permanen)
        if (user != null) {
          // Jika user adalah akun permanen TAPI email belum diverifikasi,
          // arahkan ke halaman verifikasi.
          if (!user.isAnonymous && !user.emailVerified) {
            return const EmailVerificationScreen();
          }
          // Jika user adalah anonim ATAU user permanen yang sudah verifikasi,
          // langsung masuk ke HomePage.
          return const HomePage();
        }
        
        // Fallback jika sign-in anonim gagal, tampilkan HomePage dalam mode tamu.
        return const HomePage();
      }
    );
  }
}