import 'package:budgetin_id/pages/auth/auth_handler.dart';
import 'package:budgetin_id/pages/auth/email_verification.dart'; // Pastikan path ini benar
import 'package:budgetin_id/pages/home_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:budgetin_id/pages/auth/service/auth_service.dart';
import 'package:budgetin_id/services/firestore_service.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

// [TAMBAHKAN] Impor yang diperlukan untuk App Check
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart'; // Untuk kDebugMode

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // [TAMBAHKAN] Inisialisasi Firebase App Check di sini
  // Ini akan mencegah Firebase memblokir perangkat Anda selama development
  await FirebaseAppCheck.instance.activate(
    // Gunakan provider debug saat dalam mode debug
    androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    // Jika Anda juga menargetkan iOS:
    // appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
  );

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
          scaffoldBackgroundColor: Colors.grey[50],
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: IconThemeData(color: Colors.black87),
            titleTextStyle: TextStyle(
              color: Colors.black87,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          cardTheme: CardThemeData(
            elevation: 0.5,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
          ),
           inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
        ),
        debugShowCheckedModeBanner: false,
          home: AuthHandler(
          child: AuthWrapper(),
        ),
      )
    );
  }
}

// AuthWrapper Anda sudah benar, tidak perlu diubah.
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

        if (user != null) {
          if (user.emailVerified) {
            return const HomePage();
          } else {
            // Pastikan Anda memiliki class EmailVerificationScreen
            return const EmailVerificationScreen();
          }
        }
        
        // Jika tidak ada user, arahkan ke halaman login
        // (Saya asumsikan Anda punya LoginScreen, ganti jika perlu)
        // Note: Anda sebelumnya menggunakan HomePage, yang mungkin tidak ideal
        // jika user belum login sama sekali.
        return const HomePage(); 
      }
    );
  }
}
