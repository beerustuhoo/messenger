import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Backend URL — default `10.0.2.2` reaches Docker on the host from Android emulators.
/// Physical devices: change once in app **Server settings** (login Server button or Profile → Server).
class AppConfig {
  static const _prefsKey = 'api_base_url';

  static const String compileDefault = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  static String _baseUrl = compileDefault;

  static String get apiBaseUrl => _baseUrl;
  static String get apiUrl => '$_baseUrl/api';
  static String get socketUrl => _baseUrl;

  static String mediaUrl(String path) =>
      path.startsWith('http') ? path : '$_baseUrl$path';

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved != null && saved.isNotEmpty) {
      _baseUrl = normalizeBaseUrl(saved);
    }
  }

  static Future<void> setBaseUrl(String url) async {
    _baseUrl = normalizeBaseUrl(url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _baseUrl);
  }

  static Future<void> resetToDefault() async {
    _baseUrl = compileDefault;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  static String normalizeBaseUrl(String url) {
    var u = url.trim();
    if (u.isEmpty) return compileDefault;
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'http://$u';
    }
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  static Future<({bool ok, String message})> testConnection([String? url]) async {
    final base = url != null ? normalizeBaseUrl(url) : _baseUrl;
    try {
      final response = await http
          .get(Uri.parse('$base/health'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['status'] == 'ok') {
          return (ok: true, message: 'Connected to $base');
        }
      }
      return (ok: false, message: 'Server at $base did not return a healthy response');
    } catch (_) {
      return (
        ok: false,
        message:
            'Cannot reach $base. Start Docker with .\\start-backend.ps1 and check the URL.',
      );
    }
  }
}
