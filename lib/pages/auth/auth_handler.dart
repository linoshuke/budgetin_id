// auth_handler.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app_links/app_links.dart'; // Pastikan import ini benar
import 'package:budgetin_id/pages/auth/service/auth_service.dart';

class AuthHandler extends StatefulWidget {
  final Widget child;
  const AuthHandler({super.key, required this.child});

  @override
  State<AuthHandler> createState() => _AuthHandlerState();
}

class _AuthHandlerState extends State<AuthHandler> {
  // 1. Buat instance dari AppLinks
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  @override
  void initState() {
    super.initState();
    _initAppLinks(); // Ganti nama fungsi agar lebih sesuai
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _initAppLinks() async {
    try {
      // 2. Gunakan instance '_appLinks' untuk mengakses stream
      _sub = _appLinks.uriLinkStream.listen(
        (Uri uri) { // Tipe data bisa Uri, tidak perlu Uri? karena stream ini tidak akan mengirimkan null
          if (mounted) {
            _handleDeepLink(uri);
          }
        },
        onError: (err) {
          // Handle error jika ada
          debugPrint('app_links error: $err');
        },
      );

      // (Opsional tapi direkomendasikan) Handle initial link saat aplikasi pertama kali dibuka dari deep link
      final initialUri = await _appLinks.getInitialAppLink();
      if (initialUri != null && mounted) {
        _handleDeepLink(initialUri);
      }

    } on PlatformException {
      // Handle error jika platform tidak mendukung
      debugPrint('app_links platform exception');
    }
  }

  void _handleDeepLink(Uri uri) {
    if (uri.scheme == 'budgetin' && uri.host == 'auth-action') {
      final mode = uri.queryParameters['mode'];

      if (mode == 'resetPasswordSuccess') {
        debugPrint('Password reset detected. Forcing sign out...');
        context.read<AuthService>().signOut();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Silakan login dengan password baru Anda.'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}