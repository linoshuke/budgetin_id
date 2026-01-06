// lib/services/api_auth_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import 'api_service.dart';

// Re-export exceptions from their original definitions to avoid duplication
export 'package:budgetin_id/pages/usageservice.dart' show UsageLimitExceededException;
export 'package:budgetin_id/pages/auth/service/auth_service.dart' show GoogleSignUpNotAllowedException, GoogleAccountAlreadyExistsException;

/// Exception untuk autentikasi
class AuthException implements Exception {
  final String message;
  final String? code;
  
  AuthException(this.message, {this.code});
  
  @override
  String toString() => message;
}



/// Service untuk autentikasi dengan Laravel API
class ApiAuthService {
  static const String baseUrl = ApiService.baseUrl;
  
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final firebase_auth.FirebaseAuth _firebaseAuth = firebase_auth.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'current_user';
  
  // Stream controller untuk auth state changes
  final StreamController<UserModel?> _authStateController = 
      StreamController<UserModel?>.broadcast();
  
  UserModel? _currentUser;
  String? _authToken;
  bool _isInitialized = false;

  /// Stream untuk memantau perubahan auth state
  Stream<UserModel?> get authStateChanges => _authStateController.stream;
  
  /// Get current user
  UserModel? get currentUser => _currentUser;

  /// Initialize service and restore session
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _authToken = await _storage.read(key: _tokenKey);
      final userJson = await _storage.read(key: _userKey);
      
      if (_authToken != null && userJson != null) {
        _currentUser = UserModel.fromJson(jsonDecode(userJson));
        
        // Verify token is still valid
        try {
          final user = await _fetchCurrentUser();
          _currentUser = user;
          await _saveUser(user);
        } catch (e) {
          // Token invalid, clear session
          await _clearSession();
        }
      }
      
      _authStateController.add(_currentUser);
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing auth: $e');
      await _clearSession();
      _authStateController.add(null);
      _isInitialized = true;
    }
  }

  /// Get headers with authorization
  Map<String, String> _getHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    
    return headers;
  }

  /// Handle API response
  dynamic _handleResponse(http.Response response) {
    final data = jsonDecode(response.body);
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }
    
    String message = 'Terjadi kesalahan';
    String? code;
    
    if (data is Map) {
      if (data['message'] != null) {
        message = data['message'];
      }
      if (data['errors'] != null) {
        final errors = data['errors'] as Map;
        if (errors.isNotEmpty) {
          final firstError = errors.values.first;
          if (firstError is List && firstError.isNotEmpty) {
            message = firstError.first;
          }
        }
      }
    }
    
    // Map common HTTP status codes to error codes
    switch (response.statusCode) {
      case 401:
        code = 'invalid-credentials';
        break;
      case 422:
        code = 'validation-error';
        break;
      case 429:
        code = 'too-many-requests';
        break;
    }
    
    throw AuthException(message, code: code);
  }

  /// Save user to secure storage
  Future<void> _saveUser(UserModel user) async {
    await _storage.write(key: _userKey, value: jsonEncode(user.toJson()));
  }

  /// Clear session data
  Future<void> _clearSession() async {
    _currentUser = null;
    _authToken = null;
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
    _authStateController.add(null);
  }

  /// Fetch current user from API
  Future<UserModel> _fetchCurrentUser() async {
    final response = await http.get(
      Uri.parse('$baseUrl/user'),
      headers: _getHeaders(),
    );
    
    final data = _handleResponse(response);
    return UserModel.fromJson(data['data']);
  }

  /// Register a new user
  Future<UserModel> signUpWithEmailAndPassword(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: _getHeaders(),
        body: jsonEncode({
          'displayName': displayName,
          'email': email,
          'password': password,
          'password_confirmation': password,
        }),
      );
      
      final data = _handleResponse(response);
      
      // Save token and user
      _authToken = data['data']['token'];
      await _storage.write(key: _tokenKey, value: _authToken);
      
      _currentUser = UserModel.fromJson(data['data']['user']);
      await _saveUser(_currentUser!);
      
      _authStateController.add(_currentUser);
      
      return _currentUser!;
    } catch (e) {
      debugPrint('Error signing up: $e');
      rethrow;
    }
  }

  /// Sign in with email and password
  Future<UserModel> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: _getHeaders(),
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );
      
      final data = _handleResponse(response);
      
      // Save token and user
      _authToken = data['data']['token'];
      await _storage.write(key: _tokenKey, value: _authToken);
      
      _currentUser = UserModel.fromJson(data['data']['user']);
      await _saveUser(_currentUser!);
      
      _authStateController.add(_currentUser);
      
      return _currentUser!;
    } catch (e) {
      debugPrint('Error signing in: $e');
      rethrow;
    }
  }

  /// Sign in with Google using Firebase + Laravel
  /// 
  /// Alur:
  /// 1. User memilih akun Google melalui GoogleSignIn
  /// 2. Firebase Auth mendapatkan credential dan ID Token
  /// 3. ID Token dikirim ke Laravel untuk diverifikasi
  /// 4. Laravel memverifikasi token dan mengembalikan Sanctum token
  Future<UserModel?> signInWithGoogle() async {
    try {
      // Step 1: Initiate Google Sign In
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // User cancelled

      // Step 2: Get Google auth credentials
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // Step 3: Sign in to Firebase to get ID Token
      final firebase_auth.AuthCredential credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      final firebase_auth.UserCredential userCredential = 
          await _firebaseAuth.signInWithCredential(credential);
      
      // Step 4: Get Firebase ID Token
      final String? firebaseIdToken = await userCredential.user?.getIdToken();
      
      if (firebaseIdToken == null) {
        throw AuthException('Gagal mendapatkan token dari Firebase');
      }

      // Step 5: Send token to Laravel for verification
      final response = await http.post(
        Uri.parse('$baseUrl/login/firebase'),
        headers: _getHeaders(),
        body: jsonEncode({
          'firebase_token': firebaseIdToken,
        }),
      );
      
      final data = _handleResponse(response);
      
      // Save Sanctum token and user
      _authToken = data['data']['token'];
      await _storage.write(key: _tokenKey, value: _authToken);
      
      _currentUser = UserModel.fromJson(data['data']['user']);
      await _saveUser(_currentUser!);
      
      _authStateController.add(_currentUser);
      
      // Sign out from Firebase (we're using Laravel for session management)
      await _firebaseAuth.signOut();
      
      return _currentUser!;
    } on firebase_auth.FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth Error: ${e.code} - ${e.message}');
      throw AuthException(e.message ?? 'Terjadi kesalahan saat login dengan Google', code: e.code);
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      // Clean up on error
      await _googleSignIn.signOut();
      await _firebaseAuth.signOut();
      rethrow;
    }
  }

  /// Sign up with Google (sama dengan signIn, karena Firebase handles both)
  Future<UserModel?> signUpWithGoogle() async {
    return signInWithGoogle();
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      if (_authToken != null) {
        await http.post(
          Uri.parse('$baseUrl/logout'),
          headers: _getHeaders(),
        );
      }
      
      // Also sign out from Google if signed in
      await _googleSignIn.signOut();
      await _firebaseAuth.signOut();
    } catch (e) {
      debugPrint('Error during logout API call: $e');
    } finally {
      await _clearSession();
    }
  }

  /// Update user profile
  Future<UserModel> updateProfile({String? displayName}) async {
    try {
      final body = <String, dynamic>{};
      if (displayName != null) body['displayName'] = displayName;
      
      final response = await http.put(
        Uri.parse('$baseUrl/user'),
        headers: _getHeaders(),
        body: jsonEncode(body),
      );
      
      final data = _handleResponse(response);
      _currentUser = UserModel.fromJson(data['data']);
      await _saveUser(_currentUser!);
      _authStateController.add(_currentUser);
      
      return _currentUser!;
    } catch (e) {
      debugPrint('Error updating profile: $e');
      rethrow;
    }
  }

  /// Delete user account
  Future<void> deleteUserAccount() async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/user'),
        headers: _getHeaders(),
      );
      
      _handleResponse(response);
      
      // Also sign out from Google
      await _googleSignIn.signOut();
      await _firebaseAuth.signOut();
      
      await _clearSession();
    } catch (e) {
      debugPrint('Error deleting account: $e');
      rethrow;
    }
  }

  /// Check if user is logged in
  bool get isLoggedIn => _currentUser != null && _authToken != null;

  /// Get auth token for ApiService
  Future<String?> getAuthToken() async {
    return _authToken ?? await _storage.read(key: _tokenKey);
  }

  /// Dispose resources
  void dispose() {
    _authStateController.close();
  }
}

