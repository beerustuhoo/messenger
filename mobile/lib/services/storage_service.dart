import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

class StorageService {
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  static const _userKey = 'user_cache';
  static const _verifyKey = 'pending_verify_token';

  final _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  Future<void> saveTokens(String access, String refresh) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_accessKey, access);
      await prefs.setString(_refreshKey, refresh);
      return;
    }
    await _secure.write(key: _accessKey, value: access);
    await _secure.write(key: _refreshKey, value: refresh);
  }

  Future<(String?, String?)> loadTokens() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getString(_accessKey), prefs.getString(_refreshKey));
    }
    final access = await _secure.read(key: _accessKey);
    final refresh = await _secure.read(key: _refreshKey);
    return (access, refresh);
  }

  Future<void> clearTokens() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_accessKey);
      await prefs.remove(_refreshKey);
      return;
    }
    await _secure.delete(key: _accessKey);
    await _secure.delete(key: _refreshKey);
  }

  Future<void> saveCachedUser(UserModel user) async {
    final json = jsonEncode(user.toJson());
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, json);
      return;
    }
    await _secure.write(key: _userKey, value: json);
  }

  Future<UserModel?> loadCachedUser() async {
    String? raw;
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      raw = prefs.getString(_userKey);
    } else {
      raw = await _secure.read(key: _userKey);
    }
    if (raw == null) return null;
    try {
      return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearCachedUser() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
      return;
    }
    await _secure.delete(key: _userKey);
  }

  Future<void> savePendingVerificationToken(String? token) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      if (token == null || token.isEmpty) {
        await prefs.remove(_verifyKey);
      } else {
        await prefs.setString(_verifyKey, token);
      }
      return;
    }
    if (token == null || token.isEmpty) {
      await _secure.delete(key: _verifyKey);
    } else {
      await _secure.write(key: _verifyKey, value: token);
    }
  }

  Future<String?> loadPendingVerificationToken() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_verifyKey);
    }
    return _secure.read(key: _verifyKey);
  }
}
