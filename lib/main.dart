// lib/main.dart

import 'package:budgetin_id/pages/home_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:budgetin_id/theme/app_theme.dart';
import 'package:budgetin_id/config/app_config.dart';

// Laravel API imports
import 'package:budgetin_id/services/api_service.dart';
import 'package:budgetin_id/services/api_auth_service.dart';
import 'package:budgetin_id/models/user_model.dart';

// Firebase imports (untuk backward compatibility)
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:budgetin_id/pages/auth/service/auth_service.dart';
import 'package:budgetin_id/services/firestore_service.dart';
import 'package:budgetin_id/pages/auth/service/email_verification.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppConfig.useLaravelApi) {
    // Laravel API mode - no Firebase initialization needed for data
    // But we still initialize Firebase for Firebase Hosting
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      debugPrint('Firebase init skipped: $e');
    }
  } else {
    // Firebase mode
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // [OPTIMASI] Enable Firestore offline persistence untuk cache data lokal
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    );
  }

  await initializeDateFormatting('id_ID', null);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    if (AppConfig.useLaravelApi) {
      return _buildLaravelApp();
    } else {
      return _buildFirebaseApp();
    }
  }

  /// Build app dengan Laravel API backend
  Widget _buildLaravelApp() {
    return MultiProvider(
      providers: [
        Provider<ApiAuthService>(
          create: (_) => ApiAuthService(),
          dispose: (_, service) => service.dispose(),
        ),
        Provider<ApiService>(create: (_) => ApiService()),
      ],
      child: MaterialApp(
        title: 'Budgetin',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true,
          extensions: const <ThemeExtension<dynamic>>[
            AppTheme(
              cardGradientStart: Color(0xFF1E88E5),
              cardGradientEnd: Color(0xFF1565C0),
            ),
          ],
        ),
        debugShowCheckedModeBanner: false,
        home: const LaravelAuthWrapper(),
      ),
    );
  }

  /// Build app dengan Firebase backend (original)
  Widget _buildFirebaseApp() {
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
              cardGradientStart: Color(0xFF1E88E5),
              cardGradientEnd: Color(0xFF1565C0),
            ),
          ],
        ),
        debugShowCheckedModeBanner: false,
        home: const FirebaseAuthWrapper(),
      ),
    );
  }
}

/// Auth wrapper untuk Laravel API
class LaravelAuthWrapper extends StatefulWidget {
  const LaravelAuthWrapper({super.key});

  @override
  State<LaravelAuthWrapper> createState() => _LaravelAuthWrapperState();
}

class _LaravelAuthWrapperState extends State<LaravelAuthWrapper> {
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    final authService = context.read<ApiAuthService>();
    await authService.initialize();
    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final authService = context.read<ApiAuthService>();

    return StreamBuilder<UserModel?>(
      stream: authService.authStateChanges,
      initialData: authService.currentUser,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: HomePage(key: ValueKey(user?.id ?? 'guest')),
        );
      },
    );
  }
}

/// Auth wrapper untuk Firebase (original)
class FirebaseAuthWrapper extends StatelessWidget {
  const FirebaseAuthWrapper({super.key});

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
      },
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