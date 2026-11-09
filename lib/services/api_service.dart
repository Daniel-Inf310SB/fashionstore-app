import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../core/network/app_error_message.dart';

class ApiService {
  static const Duration _requestTimeout = Duration(seconds: 15);

  static Future<http.Response> _request(
    Future<http.Response> Function() action,
  ) async {
    try {
      return await action().timeout(_requestTimeout);
    } on SocketException catch (error) {
      throw AppNetworkException(AppErrorMessage.from(error));
    } on http.ClientException catch (error) {
      throw AppNetworkException(AppErrorMessage.from(error));
    } on TimeoutException catch (error) {
      throw AppNetworkException(AppErrorMessage.from(error));
    } on HandshakeException catch (error) {
      throw AppNetworkException(AppErrorMessage.from(error));
    }
  }

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

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

  // =========================
  // POST
  // =========================

  static Future<http.Response> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = false,
  }) async {
    String? accessToken;

    if (requiresAuth) {
      accessToken = await _secureStorage.read(key: _accessTokenKey);
    }

    var response = await _rawPost(
      endpoint,
      body: body,
      accessToken: accessToken,
    );

    if (requiresAuth && response.statusCode == 401) {
      final newAccessToken = await _refreshAccessToken();

      if (newAccessToken != null) {
        response = await _rawPost(
          endpoint,
          body: body,
          accessToken: newAccessToken,
        );
      }
    }

    return response;
  }

  // =========================
  // GET
  // =========================

  static Future<http.Response> get(
    String endpoint, {
    bool requiresAuth = false,
  }) async {
    String? accessToken;

    if (requiresAuth) {
      accessToken = await _secureStorage.read(key: _accessTokenKey);
    }

    var response = await _rawGet(endpoint, accessToken: accessToken);

    if (requiresAuth && response.statusCode == 401) {
      final newAccessToken = await _refreshAccessToken();

      if (newAccessToken != null) {
        response = await _rawGet(endpoint, accessToken: newAccessToken);
      }
    }

    return response;
  }

  // =========================
  // PATCH
  // =========================

  static Future<http.Response> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = false,
  }) async {
    String? accessToken;

    if (requiresAuth) {
      accessToken = await _secureStorage.read(key: _accessTokenKey);
    }

    var response = await _rawPatch(
      endpoint,
      body: body,
      accessToken: accessToken,
    );

    if (requiresAuth && response.statusCode == 401) {
      final newAccessToken = await _refreshAccessToken();

      if (newAccessToken != null) {
        response = await _rawPatch(
          endpoint,
          body: body,
          accessToken: newAccessToken,
        );
      }
    }

    return response;
  }

  // =========================
  // RAW POST
  // =========================

  static Future<http.Response> _rawPost(
    String endpoint, {
    Map<String, dynamic>? body,
    String? accessToken,
  }) async {
    return _request(() => http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',

        'Accept': 'application/json',

        if (accessToken != null && accessToken.isNotEmpty)
          'Authorization': 'Bearer $accessToken',
      },
      body: body != null ? jsonEncode(body) : null,
    ));
  }

  // =========================
  // RAW GET
  // =========================

  static Future<http.Response> _rawGet(
    String endpoint, {
    String? accessToken,
  }) async {
    return _request(() => http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Accept': 'application/json',

        if (accessToken != null && accessToken.isNotEmpty)
          'Authorization': 'Bearer $accessToken',
      },
    ));
  }

  // =========================
  // RAW PATCH
  // =========================

  static Future<http.Response> _rawPatch(
    String endpoint, {
    Map<String, dynamic>? body,
    String? accessToken,
  }) async {
    return _request(() => http.patch(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (accessToken != null && accessToken.isNotEmpty)
          'Authorization': 'Bearer $accessToken',
      },
      body: body != null ? jsonEncode(body) : null,
    ));
  }

  // =========================
  // DELETE
  // =========================

  static Future<http.Response> delete(
    String endpoint, {
    bool requiresAuth = false,
  }) async {
    String? accessToken;

    if (requiresAuth) {
      accessToken = await _secureStorage.read(key: _accessTokenKey);
    }

    var response = await _rawDelete(endpoint, accessToken: accessToken);

    if (requiresAuth && response.statusCode == 401) {
      final newAccessToken = await _refreshAccessToken();

      if (newAccessToken != null) {
        response = await _rawDelete(endpoint, accessToken: newAccessToken);
      }
    }

    return response;
  }

  // =========================
  // RAW DELETE
  // =========================

  static Future<http.Response> _rawDelete(
    String endpoint, {
    String? accessToken,
  }) async {
    return _request(() => http.delete(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Accept': 'application/json',
        if (accessToken != null && accessToken.isNotEmpty)
          'Authorization': 'Bearer $accessToken',
      },
    ));
  }

  // =========================
  // REFRESH AUTOMÁTICO
  // =========================

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
      final response = await _rawPost(
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

      await _secureStorage.write(key: _accessTokenKey, value: newAccessToken);

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

  // =========================
  // LIMPIAR TOKENS
  // =========================

  static Future<void> _clearTokens() async {
    await _secureStorage.delete(key: _accessTokenKey);

    await _secureStorage.delete(key: _refreshTokenKey);
  }
}
