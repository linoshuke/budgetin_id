// lib/services/storage_service.dart
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload gambar profil dan kembalikan URL download-nya
  Future<String> uploadProfileImage(String uid, File imageFile) async {
    try {
      final ref = _storage.ref().child('profile_pictures').child(uid);
      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } on FirebaseException catch (e) {
      debugPrint('Error uploading image: $e');
      rethrow;
    }
  }
}