// lib/services/api_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../pages/wallets/widgets/models/transaction_model.dart';
import '../pages/wallets/widgets/models/wallet_model.dart';

/// Exception untuk error API
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  
  ApiException(this.message, {this.statusCode});
  
  @override
  String toString() => message;
}
class ApiService {
  static const String baseUrl = 'http://10.65.1.114:8000/api';
  
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _tokenKey = 'auth_token';
  
  String? _authToken;

  Future<String?> getAuthToken() async {
    if (_authToken != null) return _authToken;
    _authToken = await _storage.read(key: _tokenKey);
    return _authToken;
  }

  Future<void> setAuthToken(String token) async {
    _authToken = token;
    await _storage.write(key: _tokenKey, value: token);
  }

  /// Clear auth token
  Future<void> clearAuthToken() async {
    _authToken = null;
    await _storage.delete(key: _tokenKey);
  }

  /// Get headers with authorization
  Future<Map<String, String>> _getHeaders({bool isMultipart = false}) async {
    final token = await getAuthToken();
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    
    if (!isMultipart) {
      headers['Content-Type'] = 'application/json';
    }
    
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
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
    if (data is Map && data['message'] != null) {
      message = data['message'];
    } else if (data is Map && data['errors'] != null) {
      final errors = data['errors'] as Map;
      message = errors.values.first.first ?? message;
    }
    
    throw ApiException(message, statusCode: response.statusCode);
  }

  // ==================== WALLET METHODS ====================

  /// Get all wallets
  Future<List<Wallet>> getWallets() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/wallets'),
        headers: await _getHeaders(),
      );
      
      final data = _handleResponse(response);
      final List walletList = data['data'] ?? [];
      return walletList.map((json) => Wallet.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error getting wallets: $e');
      rethrow;
    }
  }

  /// Get a single wallet
  Future<Wallet> getWallet(String walletId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/wallets/$walletId'),
        headers: await _getHeaders(),
      );
      
      final data = _handleResponse(response);
      return Wallet.fromJson(data['data']);
    } catch (e) {
      debugPrint('Error getting wallet: $e');
      rethrow;
    }
  }

  /// Add a new wallet
  Future<Wallet> addWallet({
    required String name,
    required String category,
    required String location,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/wallets'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'walletName': name,
          'category': category,
          'location': location,
        }),
      );
      
      final data = _handleResponse(response);
      return Wallet.fromJson(data['data']);
    } catch (e) {
      debugPrint('Error adding wallet: $e');
      rethrow;
    }
  }

  /// Update wallet
  Future<Wallet> updateWallet(String walletId, {
    String? name,
    String? displayPreference,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (name != null) body['walletName'] = name;
      if (displayPreference != null) body['displayPreference'] = displayPreference;
      
      final response = await http.put(
        Uri.parse('$baseUrl/wallets/$walletId'),
        headers: await _getHeaders(),
        body: jsonEncode(body),
      );
      
      final data = _handleResponse(response);
      return Wallet.fromJson(data['data']);
    } catch (e) {
      debugPrint('Error updating wallet: $e');
      rethrow;
    }
  }

  /// Update wallet name
  Future<void> updateWalletName(String walletId, String newName) async {
    await updateWallet(walletId, name: newName);
  }

  /// Update wallet display preference
  Future<void> updateWalletPreference(String walletId, String preference) async {
    await updateWallet(walletId, displayPreference: preference);
  }

  /// Delete a wallet
  Future<void> deleteWallet(String walletId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/wallets/$walletId'),
        headers: await _getHeaders(),
      );
      
      _handleResponse(response);
    } catch (e) {
      debugPrint('Error deleting wallet: $e');
      rethrow;
    }
  }

  /// Create default wallets
  Future<List<Wallet>> createDefaultWallets() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/wallets/default'),
        headers: await _getHeaders(),
      );
      
      final data = _handleResponse(response);
      final List walletList = data['data'] ?? [];
      return walletList.map((json) => Wallet.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error creating default wallets: $e');
      rethrow;
    }
  }

  /// Get wallet statistics
  Future<Map<String, double>> getWalletStats(String walletId, String preference) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/wallets/$walletId/stats?preference=$preference'),
        headers: await _getHeaders(),
      );
      
      final data = _handleResponse(response);
      final statsData = data['data'];
      return {
        'income': (statsData['income'] as num?)?.toDouble() ?? 0.0,
        'expense': (statsData['expense'] as num?)?.toDouble() ?? 0.0,
      };
    } catch (e) {
      debugPrint('Error getting wallet stats: $e');
      rethrow;
    }
  }

  // ==================== TRANSACTION METHODS ====================

  /// Get transactions with optional filters
  Future<List<Transaction>> getTransactions({
    String? walletId,
    List<String>? walletIds,
    DateTimeRange? dateRange,
  }) async {
    try {
      final queryParams = <String, String>{};
      
      if (walletId != null) {
        queryParams['wallet_id'] = walletId;
      }
      if (walletIds != null && walletIds.isNotEmpty) {
        queryParams['wallet_ids'] = walletIds.join(',');
      }
      if (dateRange != null) {
        queryParams['start_date'] = dateRange.start.toIso8601String().split('T')[0];
        queryParams['end_date'] = dateRange.end.toIso8601String().split('T')[0];
      }
      
      final uri = Uri.parse('$baseUrl/transactions').replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );
      
      final data = _handleResponse(response);
      final List transactionList = data['data'] ?? [];
      return transactionList.map((json) => Transaction.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error getting transactions: $e');
      rethrow;
    }
  }

  /// Add a new transaction
  Future<Transaction> addTransaction({
    required String walletId,
    required String description,
    required double amount,
    required TransactionType type,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/transactions'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'wallet_id': int.parse(walletId),
          'description': description,
          'amount': amount,
          'type': type == TransactionType.income ? 'income' : 'expense',
        }),
      );
      
      final data = _handleResponse(response);
      return Transaction.fromJson(data['data']['transaction']);
    } catch (e) {
      debugPrint('Error adding transaction: $e');
      rethrow;
    }
  }

  /// Delete a transaction
  Future<void> deleteTransaction(String transactionId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/transactions/$transactionId'),
        headers: await _getHeaders(),
      );
      
      _handleResponse(response);
    } catch (e) {
      debugPrint('Error deleting transaction: $e');
      rethrow;
    }
  }

  /// Get transactions grouped by day
  Future<Map<int, List<Transaction>>> getMonthlyTransactionsGroupedByDay(
    String walletId, {
    int? year,
    int? month,
  }) async {
    try {
      final queryParams = <String, String>{
        'wallet_id': walletId,
      };
      if (year != null) queryParams['year'] = year.toString();
      if (month != null) queryParams['month'] = month.toString();
      
      final uri = Uri.parse('$baseUrl/transactions/grouped/day')
          .replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );
      
      final data = _handleResponse(response);
      final Map<String, dynamic> grouped = data['data'] ?? {};
      
      final result = <int, List<Transaction>>{};
      grouped.forEach((key, value) {
        final day = int.tryParse(key) ?? 0;
        final List transactions = value ?? [];
        result[day] = transactions.map((json) => Transaction.fromJson(json)).toList();
      });
      
      return result;
    } catch (e) {
      debugPrint('Error getting grouped transactions: $e');
      rethrow;
    }
  }

  // ==================== SUMMARY METHODS ====================

  /// Get daily summary
  Future<Map<String, double>> getDailySummary({List<String>? walletIds}) async {
    try {
      final queryParams = <String, String>{};
      if (walletIds != null && walletIds.isNotEmpty) {
        queryParams['wallet_ids'] = walletIds.join(',');
      }
      
      final uri = Uri.parse('$baseUrl/summary/daily')
          .replace(queryParameters: queryParams.isEmpty ? null : queryParams);
      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );
      
      final data = _handleResponse(response);
      final summaryData = data['data'];
      return {
        'income': (summaryData['income'] as num?)?.toDouble() ?? 0.0,
        'expense': (summaryData['expense'] as num?)?.toDouble() ?? 0.0,
        'difference': (summaryData['difference'] as num?)?.toDouble() ?? 0.0,
      };
    } catch (e) {
      debugPrint('Error getting daily summary: $e');
      rethrow;
    }
  }

  /// Get monthly summary
  Future<Map<String, double>> getMonthlySummary({
    List<String>? walletIds,
    int? year,
    int? month,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (walletIds != null && walletIds.isNotEmpty) {
        queryParams['wallet_ids'] = walletIds.join(',');
      }
      if (year != null) queryParams['year'] = year.toString();
      if (month != null) queryParams['month'] = month.toString();
      
      final uri = Uri.parse('$baseUrl/summary/monthly')
          .replace(queryParameters: queryParams.isEmpty ? null : queryParams);
      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );
      
      final data = _handleResponse(response);
      final summaryData = data['data'];
      return {
        'income': (summaryData['income'] as num?)?.toDouble() ?? 0.0,
        'expense': (summaryData['expense'] as num?)?.toDouble() ?? 0.0,
        'difference': (summaryData['difference'] as num?)?.toDouble() ?? 0.0,
      };
    } catch (e) {
      debugPrint('Error getting monthly summary: $e');
      rethrow;
    }
  }

  /// Get expense by category
  Future<Map<String, double>> getMonthlyExpenseByCategory({
    List<String>? walletIds,
    int? year,
    int? month,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (walletIds != null && walletIds.isNotEmpty) {
        queryParams['wallet_ids'] = walletIds.join(',');
      }
      if (year != null) queryParams['year'] = year.toString();
      if (month != null) queryParams['month'] = month.toString();
      
      final uri = Uri.parse('$baseUrl/summary/category')
          .replace(queryParameters: queryParams.isEmpty ? null : queryParams);
      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );
      
      final data = _handleResponse(response);
      final Map<String, dynamic> categories = data['data']['categories'] ?? {};
      
      return categories.map((key, value) => 
        MapEntry(key, (value as num?)?.toDouble() ?? 0.0)
      );
    } catch (e) {
      debugPrint('Error getting category summary: $e');
      rethrow;
    }
  }

  /// Get monthly transaction summary by day
  Future<Map<int, Map<String, double>>> getMonthlyTransactionSummary(
    String walletId, {
    int? year,
    int? month,
  }) async {
    try {
      final queryParams = <String, String>{
        'wallet_id': walletId,
      };
      if (year != null) queryParams['year'] = year.toString();
      if (month != null) queryParams['month'] = month.toString();
      
      final uri = Uri.parse('$baseUrl/summary/monthly-by-day')
          .replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );
      
      final data = _handleResponse(response);
      final Map<String, dynamic> dailyTotals = data['data']['daily_totals'] ?? {};
      
      final result = <int, Map<String, double>>{};
      dailyTotals.forEach((key, value) {
        final day = int.tryParse(key) ?? 0;
        result[day] = {
          'income': (value['income'] as num?)?.toDouble() ?? 0.0,
          'expense': (value['expense'] as num?)?.toDouble() ?? 0.0,
        };
      });
      
      return result;
    } catch (e) {
      debugPrint('Error getting monthly summary by day: $e');
      rethrow;
    }
  }

  // ==================== USER METHODS ====================

  /// Update user profile
  Future<void> updateUserProfile({String? displayName}) async {
    try {
      final body = <String, dynamic>{};
      if (displayName != null) body['displayName'] = displayName;
      
      final response = await http.put(
        Uri.parse('$baseUrl/user'),
        headers: await _getHeaders(),
        body: jsonEncode(body),
      );
      
      _handleResponse(response);
    } catch (e) {
      debugPrint('Error updating profile: $e');
      rethrow;
    }
  }

  /// Upload profile photo
  Future<String> uploadProfilePhoto(File imageFile) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/user/photo'),
      );
      
      final headers = await _getHeaders(isMultipart: true);
      request.headers.addAll(headers);
      
      request.files.add(await http.MultipartFile.fromPath(
        'photo',
        imageFile.path,
      ));
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      final data = _handleResponse(response);
      return data['data']['photoURL'] ?? '';
    } catch (e) {
      debugPrint('Error uploading photo: $e');
      rethrow;
    }
  }

  /// Delete user account
  Future<void> deleteUserAccount() async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/user'),
        headers: await _getHeaders(),
      );
      
      _handleResponse(response);
      await clearAuthToken();
    } catch (e) {
      debugPrint('Error deleting account: $e');
      rethrow;
    }
  }
}
