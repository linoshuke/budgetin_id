import 'package:budgetin_id/pages/auth/service/email_verification.dart';
import 'package:budgetin_id/pages/home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:budgetin_id/pages/auth/service/auth_service.dart';
import 'package:budgetin_id/services/firestore_service.dart';
import 'package:provider/provider.dart';
import 'package:budgetin_id/theme/app_theme.dart';
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
          StreamProvider<User?>(
          create: (context) => context.read<AuthService>().authStateChanges,
          initialData: null,
          ),
      ],
      child: MaterialApp(
        title: 'Budgetin',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true,
            extensions: const <ThemeExtension<dynamic>>[
            AppTheme(
              cardGradientStart: Color(0xFF1E88E5), // Colors.blue.shade600
              cardGradientEnd: Color(0xFF1565C0),   // Colors.blue.shade800
            ),
          ],
        ),
        debugShowCheckedModeBanner: false,
        home: const AuthWrapper(),
      )
    );
  }
}
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
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildContent(user),
        );
      }
    );
  }

  Widget _buildContent(User? user) {
    final key = ValueKey(user?.uid);
    if (user == null) {
      return HomePage(key: key); // Guest mode
    }

    final isPasswordProvider = user.providerData.any((p) => p.providerId == 'password');


    if (isPasswordProvider && !user.emailVerified) {
      return EmailVerificationScreen(key: key);
    }
    return HomePage(key: key);
  }
}