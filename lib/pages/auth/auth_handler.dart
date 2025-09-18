import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app_links/app_links.dart';
import 'package:budgetin_id/pages/auth/service/auth_service.dart';

class AuthHandler extends StatefulWidget {
  final Widget child;
  const AuthHandler({super.key, required this.child});

  @override
  State<AuthHandler> createState() => _AuthHandlerState();
}

class _AuthHandlerState extends State<AuthHandler> {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  @override
  void initState() {
    super.initState();
    _initAppLinks();
  }

  // [DIGANTI] Ganti seluruh fungsi dispose() Anda dengan yang ini.
  @override
  void dispose() {
    // Perbaikan ini menambahkan null check untuk mencegah error jika stream
    // sudah tidak aktif atau tidak pernah diinisialisasi.
    if (_sub != null) {
      _sub?.cancel();
      _sub = null; // Set ke null untuk menandakan sudah dibatalkan
    }
    super.dispose();
  }

  Future<void> _initAppLinks() async {
    try {
      _sub = _appLinks.uriLinkStream.listen(
        (Uri uri) {
          if (mounted) {
            _handleDeepLink(uri);
          }
        },
        onError: (err) {
          debugPrint('app_links error: $err');
        },
      );

      final initialUri = await _appLinks.getInitialAppLink();
      if (initialUri != null && mounted) {
        _handleDeepLink(initialUri);
      }
    } on PlatformException {
      debugPrint('app_links platform exception');
    }
  }

  void _handleDeepLink(Uri uri) {
    if (uri.scheme == 'budgetin' && uri.host == 'auth-action') {
      final mode = uri.queryParameters['mode'];

      if (mode == 'resetPasswordSuccess') {
        // [PERBAIKAN] Tambahkan pengecekan 'mounted' sebelum menggunakan context
        if (!mounted) return;
        
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