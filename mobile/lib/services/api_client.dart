import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? field;
  final List<String>? details;

  ApiException(this.message, {this.statusCode, this.field, this.details});

  @override
  String toString() => message;
}

class ApiClient {
  String? _accessToken;
  String? _refreshToken;
  Future<String?> Function()? onTokenRefresh;

  String? get accessToken => _accessToken;

  void setTokens({String? access, String? refresh}) {
    _accessToken = access;
    _refreshToken = refresh;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  Future<dynamic> get(String path) => _request('GET', path);
  Future<dynamic> post(String path, [Map<String, dynamic>? body]) =>
      _request('POST', path, body: body);
  Future<dynamic> put(String path, [Map<String, dynamic>? body]) =>
      _request('PUT', path, body: body);
  Future<dynamic> patch(String path, [Map<String, dynamic>? body]) =>
      _request('PATCH', path, body: body);
  Future<dynamic> delete(String path) => _request('DELETE', path);

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool retried = false,
  }) async {
    final uri = Uri.parse('${AppConfig.apiUrl}$path');
    http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await http.get(uri, headers: _headers);
          break;
        case 'POST':
          response = await http.post(uri, headers: _headers, body: jsonEncode(body ?? {}));
          break;
        case 'PUT':
          response = await http.put(uri, headers: _headers, body: jsonEncode(body ?? {}));
          break;
        case 'PATCH':
          response = await http.patch(uri, headers: _headers, body: jsonEncode(body ?? {}));
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: _headers);
          break;
        default:
          throw ApiException('Unsupported method');
      }
    } on http.ClientException catch (e) {
      throw ApiException('Network error: ${e.message}');
    } catch (_) {
      throw ApiException(
        'Cannot reach server at ${AppConfig.apiBaseUrl}. Check Wi‑Fi and that the backend is running.',
      );
    }

    if (response.statusCode == 401 && !retried && _refreshToken != null) {
      final newToken = await onTokenRefresh?.call();
      if (newToken != null) {
        _accessToken = newToken;
        return _request(method, path, body: body, retried: true);
      }
    }

    dynamic data;
    if (response.body.isNotEmpty) {
      try {
        data = jsonDecode(response.body);
      } catch (_) {
        throw ApiException('Invalid server response', statusCode: response.statusCode);
      }
    }

    if (response.statusCode >= 400) {
      final err = data is Map<String, dynamic> ? data : null;
      throw ApiException(
        err?['error'] as String? ?? 'Request failed',
        statusCode: response.statusCode,
        field: err?['field'] as String?,
        details: (err?['details'] as List?)?.cast<String>(),
      );
    }
    if (data == null && response.statusCode >= 200 && response.statusCode < 300) {
      throw ApiException(
        'Empty server response (${response.statusCode}). Use https:// for Render URLs, not http://.',
        statusCode: response.statusCode,
      );
    }
    return data;
  }

  Future<http.Response> uploadMultipart(
    String path,
    String field,
    List<int> bytes,
    String filename, {
    Map<String, String>? fields,
    String? mimeType,
  }) async {
    final uri = Uri.parse('${AppConfig.apiUrl}$path');
    final request = http.MultipartRequest('POST', uri);
    if (_accessToken != null) {
      request.headers['Authorization'] = 'Bearer $_accessToken';
    }
    fields?.forEach((k, v) => request.fields[k] = v);
    request.files.add(http.MultipartFile.fromBytes(
      field,
      bytes,
      filename: filename,
    ));
    final streamed = await request.send();
    return http.Response.fromStream(streamed);
  }
}
