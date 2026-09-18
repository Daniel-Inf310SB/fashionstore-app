import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;


class ApiService {
  static const FlutterSecureStorage _secureStorage =
  FlutterSecureStorage();

  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';

  static Future<String?>? _refreshFuture;

  static String get baseUrl {
    final url = dotenv.env['API_BASE_URL'];

    if (url == null || url.isEmpty) {
      throw Exception('API_BASE_URL no está configurado en .env');
    }

    return url;
  }

  // =========================================================
  // GET
  // =========================================================

  static Future<http.Response> get(
      String endpoint, {
        bool requiresAuth = false,
      }) async {
    return _withAuthRetry(
      requiresAuth: requiresAuth,
      call: (token) => _rawGet(endpoint, accessToken: token),
    );
  }

  // =========================================================
  // POST
  // =========================================================

  static Future<http.Response> post(
      String endpoint, {
        Map<String, dynamic>? body,
        bool requiresAuth = false,
      }) async {
    return _withAuthRetry(
      requiresAuth: requiresAuth,
      call: (token) => _rawSend(
        'POST',
        endpoint,
        body: body,
        accessToken: token,
      ),
    );
  }

  // =========================================================
  // PUT
  // =========================================================

  static Future<http.Response> put(
      String endpoint, {
        Map<String, dynamic>? body,
        bool requiresAuth = true,
      }) async {
    return _withAuthRetry(
      requiresAuth: requiresAuth,
      call: (token) => _rawSend(
        'PUT',
        endpoint,
        body: body,
        accessToken: token,
      ),
    );
  }

  // =========================================================
  // PATCH
  // =========================================================

  static Future<http.Response> patch(
      String endpoint, {
        Map<String, dynamic>? body,
        bool requiresAuth = true,
      }) async {
    return _withAuthRetry(
      requiresAuth: requiresAuth,
      call: (token) => _rawSend(
        'PATCH',
        endpoint,
        body: body,
        accessToken: token,
      ),
    );
  }

  // =========================================================
  // DELETE
  // =========================================================

  static Future<http.Response> delete(
      String endpoint, {
        bool requiresAuth = true,
      }) async {
    return _withAuthRetry(
      requiresAuth: requiresAuth,
      call: (token) => _rawSend(
        'DELETE',
        endpoint,
        accessToken: token,
      ),
    );
  }

  // =========================================================
  // MULTIPART (subida de archivos, ej. portada de producto)
  // =========================================================

  static Future<http.Response> uploadFile(
      String endpoint, {
        required File file,
        String fieldName = 'file',
        String method = 'POST',
        Map<String, String>? fields,
        bool requiresAuth = true,
      }) async {
    return _withAuthRetry(
      requiresAuth: requiresAuth,
      call: (token) => _rawMultipart(
        method,
        endpoint,
        file: file,
        fieldName: fieldName,
        fields: fields,
        accessToken: token,
      ),
    );
  }

  // =========================================================
  // NÚCLEO: reintento automático tras refrescar token
  // =========================================================

  static Future<http.Response> _withAuthRetry({
    required bool requiresAuth,
    required Future<http.Response> Function(String? token) call,
  }) async {
    String? accessToken;

    if (requiresAuth) {
      accessToken = await _secureStorage.read(key: _accessTokenKey);
    }

    var response = await call(accessToken);

    if (requiresAuth && response.statusCode == 401) {
      final newAccessToken = await _refreshAccessToken();

      if (newAccessToken != null) {
        response = await call(newAccessToken);
      }
    }

    return response;
  }

  // =========================================================
  // RAW GET
  // =========================================================

  static Future<http.Response> _rawGet(
      String endpoint, {
        String? accessToken,
      }) async {
    return http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers(accessToken),
    );
  }

  // =========================================================
  // RAW SEND (POST / PUT / PATCH / DELETE con JSON)
  // =========================================================

  static Future<http.Response> _rawSend(
      String method,
      String endpoint, {
        Map<String, dynamic>? body,
        String? accessToken,
      }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = _headers(accessToken);
    final encodedBody = body != null ? jsonEncode(body) : null;

    switch (method) {
      case 'POST':
        return http.post(uri, headers: headers, body: encodedBody);
      case 'PUT':
        return http.put(uri, headers: headers, body: encodedBody);
      case 'PATCH':
        return http.patch(uri, headers: headers, body: encodedBody);
      case 'DELETE':
        return http.delete(uri, headers: headers, body: encodedBody);
      default:
        throw ArgumentError('Método HTTP no soportado: $method');
    }
  }

  // =========================================================
  // RAW MULTIPART
  // =========================================================

  static Future<http.Response> _rawMultipart(
      String method,
      String endpoint, {
        required File file,
        required String fieldName,
        Map<String, String>? fields,
        String? accessToken,
      }) async {
    final uri = Uri.parse('$baseUrl$endpoint');

    final request = http.MultipartRequest(method, uri);

    request.headers['Accept'] = 'application/json';

    if (accessToken != null && accessToken.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $accessToken';
    }

    if (fields != null) {
      request.fields.addAll(fields);
    }

    request.files.add(
      await http.MultipartFile.fromPath(fieldName, file.path),
    );

    final streamedResponse = await request.send();

    return http.Response.fromStream(streamedResponse);
  }

  // =========================================================
  // HEADERS
  // =========================================================

  static Map<String, String> _headers(String? accessToken) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (accessToken != null && accessToken.isNotEmpty)
        'Authorization': 'Bearer $accessToken',
    };
  }

  // =========================================================
  // REFRESH AUTOMÁTICO
  // =========================================================

  static Future<String?> _refreshAccessToken() async {
    if (_refreshFuture != null) {
      return _refreshFuture!;
    }

    _refreshFuture = _performRefresh();

    try {
      return await _refreshFuture!;
    } finally {
      _refreshFuture = null;
    }
  }

  static Future<String?> _performRefresh() async {
    final refreshToken = await _secureStorage.read(key: _refreshTokenKey);

    if (refreshToken == null || refreshToken.isEmpty) {
      return null;
    }

    try {
      final response = await _rawSend(
        'POST',
        '/auth/refresh',
        body: {'refresh_token': refreshToken},
      );

      if (response.statusCode != 200) {
        await _clearTokens();
        return null;
      }

      final Map<String, dynamic> data = jsonDecode(response.body);

      final newAccessToken = data['access_token']?.toString();
      final newRefreshToken = data['refresh_token']?.toString();

      if (newAccessToken == null || newAccessToken.isEmpty) {
        await _clearTokens();
        return null;
      }

      await _secureStorage.write(
        key: _accessTokenKey,
        value: newAccessToken,
      );

      if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
        await _secureStorage.write(
          key: _refreshTokenKey,
          value: newRefreshToken,
        );
      }

      return newAccessToken;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _clearTokens() async {
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
  }
}