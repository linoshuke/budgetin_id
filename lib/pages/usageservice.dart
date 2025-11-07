// lib/services/usage_limiter_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// Enum untuk mendefinisikan tipe aksi yang akan dibatasi
enum LimitedAction {
  loginOrSignup,
  resetPassword,
  deleteAccount,
}

class UsageService {
  static const _storageKey = 'usage_action_tracker';
  static const _cooldownPeriod = Duration(hours: 24);

  // Definisikan batas maksimal untuk setiap aksi
  final Map<LimitedAction, int> _actionLimits = {
    LimitedAction.loginOrSignup: 5, // Diberi kelonggaran menjadi 5x
    LimitedAction.resetPassword: 2,
    LimitedAction.deleteAccount: 1,
  };

  // Memeriksa apakah sebuah aksi masih diizinkan
  Future<bool> canPerformAction(LimitedAction action) async {
    final prefs = await SharedPreferences.getInstance();
    final records = _getRecords(prefs);
    final now = DateTime.now();

    // Hapus catatan lama yang sudah melewati masa cooldown
    records.removeWhere((key, timestamps) {
      timestamps.removeWhere((ts) => now.difference(DateTime.parse(ts)) > _cooldownPeriod);
      return timestamps.isEmpty;
    });

    final actionKey = action.toString();
    final currentCount = records[actionKey]?.length ?? 0;
    final limit = _actionLimits[action] ?? 0;

    await _saveRecords(prefs, records); // Simpan kembali setelah pembersihan

    return currentCount < limit;
  }

  // Mencatat bahwa sebuah aksi telah dilakukan
  Future<void> recordAction(LimitedAction action) async {
    final prefs = await SharedPreferences.getInstance();
    final records = _getRecords(prefs);
    final actionKey = action.toString();

    if (records[actionKey] == null) {
      records[actionKey] = [];
    }
    records[actionKey]!.add(DateTime.now().toIso8601String());

    await _saveRecords(prefs, records);
  }

  // Helper untuk membaca data dari SharedPreferences
  Map<String, List<String>> _getRecords(SharedPreferences prefs) {
    final jsonString = prefs.getString(_storageKey);
    if (jsonString == null) return {};
    
    final Map<String, dynamic> decoded = json.decode(jsonString);
    return decoded.map((key, value) => MapEntry(key, List<String>.from(value)));
  }

  // Helper untuk menyimpan data ke SharedPreferences
  Future<void> _saveRecords(SharedPreferences prefs, Map<String, List<String>> records) {
    return prefs.setString(_storageKey, json.encode(records));
  }
}

// Custom exception untuk ditangkap di UI
class UsageLimitExceededException implements Exception {
  final String message;
  UsageLimitExceededException(this.message);

  @override
  String toString() => message;
}