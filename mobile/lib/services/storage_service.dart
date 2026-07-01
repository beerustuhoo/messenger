import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/models.dart';

class StorageService {
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  static const _userKey = 'user_cache';

  final _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  Future<void> saveTokens(String access, String refresh) async {
    await _secure.write(key: _accessKey, value: access);
    await _secure.write(key: _refreshKey, value: refresh);
  }

  Future<(String?, String?)> loadTokens() async {
    final access = await _secure.read(key: _accessKey);
    final refresh = await _secure.read(key: _refreshKey);
    return (access, refresh);
  }

  Future<void> clearTokens() async {
    await _secure.delete(key: _accessKey);
    await _secure.delete(key: _refreshKey);
  }

  Future<void> saveCachedUser(UserModel user) async {
    await _secure.write(key: _userKey, value: jsonEncode(user.toJson()));
  }

  Future<UserModel?> loadCachedUser() async {
    final raw = await _secure.read(key: _userKey);
    if (raw == null) return null;
    try {
      return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearCachedUser() async {
    await _secure.delete(key: _userKey);
  }

  Future<void> savePendingVerificationToken(String? token) async {
    if (token == null || token.isEmpty) {
      await _secure.delete(key: 'pending_verify_token');
    } else {
      await _secure.write(key: 'pending_verify_token', value: token);
    }
  }

  Future<String?> loadPendingVerificationToken() async {
    return _secure.read(key: 'pending_verify_token');
  }
}
