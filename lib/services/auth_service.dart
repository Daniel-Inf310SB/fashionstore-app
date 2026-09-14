import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'api_service.dart';


class AuthService {
  static const String _isLoggedInKey =
      'is_logged_in';

  static const String _userNameKey =
      'user_name';

  static const String _userEmailKey =
      'user_email';

  static const String _userPhotoKey =
      'user_photo';

  static const String _userRoleKey =
      'user_role';

  static const String _userPermissionsKey =
      'user_permissions';

  static const String _profileCompletedKey =
      'profile_completed';


  static const String _accessTokenKey =
      'access_token';

  static const String _refreshTokenKey =
      'refresh_token';

  static const String _deviceIdKey =
      'device_id';


  static const FlutterSecureStorage _secureStorage =
      FlutterSecureStorage();


  static final GoogleSignIn _googleSignIn =
      GoogleSignIn.instance;


  static final DeviceInfoPlugin _deviceInfo =
      DeviceInfoPlugin();


  static const Uuid _uuid =
      Uuid();


  // =========================
  // INICIALIZAR GOOGLE
  // =========================

  static Future<void> initializeGoogle() async {
    final serverClientId =
        dotenv.env['GOOGLE_SERVER_CLIENT_ID'];

    if (serverClientId == null ||
        serverClientId.isEmpty) {
      throw Exception(
        'GOOGLE_SERVER_CLIENT_ID no está configurado en .env',
      );
    }

    await _googleSignIn.initialize(
      serverClientId: serverClientId,
    );
  }


  // =========================
  // INFORMACIÓN DISPOSITIVO
  // =========================

  static Future<Map<String, String>>
      _getDeviceData() async {
    String? deviceId =
        await _secureStorage.read(
      key: _deviceIdKey,
    );


    if (deviceId == null ||
        deviceId.isEmpty) {
      deviceId =
          _uuid.v4();

      await _secureStorage.write(
        key: _deviceIdKey,
        value: deviceId,
      );
    }


    String deviceName =
        'Dispositivo desconocido';

    String platform =
        'unknown';


    try {
      if (kIsWeb) {
        final info =
            await _deviceInfo.webBrowserInfo;

        deviceName =
            info.browserName.name;

        platform =
            'web';
      } else {
        switch (defaultTargetPlatform) {
          case TargetPlatform.android:
            final info =
                await _deviceInfo.androidInfo;

            final manufacturer =
                info.manufacturer.trim();

            final model =
                info.model.trim();

            deviceName =
                '$manufacturer $model'
                    .trim();

            platform =
                'android';

            break;


          case TargetPlatform.iOS:
            final info =
                await _deviceInfo.iosInfo;

            deviceName =
                info.name.isNotEmpty
                    ? info.name
                    : info.model;

            platform =
                'ios';

            break;


          case TargetPlatform.windows:
            final info =
                await _deviceInfo.windowsInfo;

            deviceName =
                info.computerName;

            platform =
                'windows';

            break;


          case TargetPlatform.macOS:
            final info =
                await _deviceInfo.macOsInfo;

            deviceName =
                info.computerName;

            platform =
                'macos';

            break;


          case TargetPlatform.linux:
            final info =
                await _deviceInfo.linuxInfo;

            deviceName =
                info.prettyName;

            platform =
                'linux';

            break;


          case TargetPlatform.fuchsia:
            platform =
                'fuchsia';

            break;
        }
      }
    } catch (error) {
      debugPrint(
        'Error obteniendo información del dispositivo: $error',
      );
    }


    debugPrint(
      '==============================',
    );

    debugPrint(
      'DEVICE ID: $deviceId',
    );

    debugPrint(
      'DEVICE NAME: $deviceName',
    );

    debugPrint(
      'PLATFORM: $platform',
    );

    debugPrint(
      '==============================',
    );


    return {
      'device_id':
          deviceId,

      'device_name':
          deviceName,

      'platform':
          platform,
    };
  }

 // =========================
// REGISTRO
// =========================

static Future<Map<String, dynamic>> register({
  required String firstName,
  String? lastName,
  required String email,
  required String password,
}) async {
  final response =
      await ApiService.post(
    '/auth/register',

    body: {
      'first_name':
          firstName.trim(),

      'last_name':
          lastName != null &&
                  lastName.trim().isNotEmpty
              ? lastName.trim()
              : null,

      'email':
          email
              .trim()
              .toLowerCase(),

      'password':
          password,
    },
  );


  final Map<String, dynamic> data =
      jsonDecode(
    response.body,
  );


  if (response.statusCode != 201) {
    final detail =
        data['detail'];

    if (detail is Map) {
      throw Exception(
        jsonEncode(detail),
      );
    }

    throw Exception(
      detail ??
          'No se pudo crear la cuenta',
    );
  }


  return data;
}

  // =========================
  // VERIFICAR EMAIL
  // =========================

  static Future<Map<String, dynamic>>
      verifyEmail({
    required String email,
    required String code,
  }) async {
    final response =
        await ApiService.post(
      '/auth/verify-email',

      body: {
        'email':
            email
                .trim()
                .toLowerCase(),

        'code':
            code.trim(),
      },
    );


    final Map<String, dynamic> data =
        jsonDecode(
      response.body,
    );


    if (response.statusCode != 200) {
      throw Exception(
        data['detail'] ??
            'No se pudo verificar el correo',
      );
    }


    return data;
  }


  // =========================
  // REENVIAR CÓDIGO
  // =========================

  static Future<Map<String, dynamic>>
      resendVerificationCode({
    required String email,
  }) async {
    final response =
        await ApiService.post(
      '/auth/resend-verification-code',

      body: {
        'email':
            email
                .trim()
                .toLowerCase(),
      },
    );


    final Map<String, dynamic> data =
        jsonDecode(
      response.body,
    );


    if (response.statusCode != 200) {
      throw Exception(
        data['detail'] ??
            'No se pudo reenviar el código',
      );
    }


    return data;
  }

  // =========================
// OLVIDÉ CONTRASEÑA
// =========================

static Future<Map<String, dynamic>>
    forgotPassword({
  required String email,
}) async {
  final response =
      await ApiService.post(
    '/auth/forgot-password',

    body: {
      'email':
          email
              .trim()
              .toLowerCase(),
    },
  );


  final Map<String, dynamic> data =
      jsonDecode(
    response.body,
  );


  if (response.statusCode != 200) {
    throw Exception(
      data['detail'] ??
          'No se pudo solicitar la recuperación',
    );
  }


  return data;
}


// =========================
// VERIFICAR CÓDIGO RESET
// =========================

static Future<Map<String, dynamic>>
    verifyResetCode({
  required String email,
  required String code,
}) async {
  final response =
      await ApiService.post(
    '/auth/verify-reset-code',

    body: {
      'email':
          email
              .trim()
              .toLowerCase(),

      'code':
          code.trim(),
    },
  );


  final Map<String, dynamic> data =
      jsonDecode(
    response.body,
  );


  if (response.statusCode != 200) {
    throw Exception(
      data['detail'] ??
          'El código no es válido',
    );
  }


  return data;
}


// =========================
// RESTABLECER CONTRASEÑA
// =========================

static Future<Map<String, dynamic>>
    resetPassword({
  required String email,
  required String code,
  required String newPassword,
}) async {
  final response =
      await ApiService.post(
    '/auth/reset-password',

    body: {
      'email':
          email
              .trim()
              .toLowerCase(),

      'code':
          code.trim(),

      'new_password':
          newPassword,
    },
  );


  final Map<String, dynamic> data =
      jsonDecode(
    response.body,
  );


  if (response.statusCode != 200) {
    throw Exception(
      data['detail'] ??
          'No se pudo cambiar la contraseña',
    );
  }


  return data;
}

  // =========================
  // LOGIN GOOGLE
  // =========================

  static Future<Map<String, dynamic>>
      signInWithGoogle() async {
    try {
      final GoogleSignInAccount account =
          await _googleSignIn.authenticate();


      final GoogleSignInAuthentication authentication =
          account.authentication;


      final String? idToken =
          authentication.idToken;


      if (idToken == null ||
          idToken.isEmpty) {
        throw Exception(
          'Google no devolvió un ID Token',
        );
      }


      final device =
          await _getDeviceData();


      final response =
          await ApiService.post(
        '/auth/google',

        body: {
          'id_token':
              idToken,

          'device_id':
              device['device_id'],

          'device_name':
              device['device_name'],

          'platform':
              device['platform'],
        },
      );


      final Map<String, dynamic> data =
          jsonDecode(
        response.body,
      );


      if (response.statusCode != 200) {
        throw Exception(
          data['detail'] ??
              'No se pudo iniciar sesión con Google',
        );
      }


      await _saveBackendSession(
        data,
      );


      return data;
    } catch (error) {
      debugPrint(
        'Error Google Login: $error',
      );

      rethrow;
    }
  }


  // =========================
  // LOGIN NORMAL
  // =========================

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final device =
        await _getDeviceData();


    final response =
        await ApiService.post(
      '/auth/login',

      body: {
        'email':
            email.trim(),

        'password':
            password,

        'device_id':
            device['device_id'],

        'device_name':
            device['device_name'],

        'platform':
            device['platform'],
      },
    );


    final Map<String, dynamic> data =
        jsonDecode(
      response.body,
    );


    if (response.statusCode != 200) {
      throw Exception(
        data['detail'] ??
            'No se pudo iniciar sesión',
      );
    }


    await _saveBackendSession(
      data,
    );


    return data;
  }


  // =========================
  // COMPROBAR USERNAME
  // =========================

  static Future<Map<String, dynamic>>
      checkUsername(
    String username,
  ) async {
    final normalizedUsername =
        username
            .trim()
            .toLowerCase();


    final encodedUsername =
        Uri.encodeQueryComponent(
      normalizedUsername,
    );


    final response =
        await ApiService.get(
      '/auth/check-username'
      '?username=$encodedUsername',

      requiresAuth:
          true,
    );


    final Map<String, dynamic> data =
        jsonDecode(
      response.body,
    );


    if (response.statusCode != 200) {
      throw Exception(
        data['detail'] ??
            'No se pudo comprobar el nombre de usuario',
      );
    }


    return data;
  }


// =========================
// COMPROBAR DOCUMENTO
// =========================

static Future<Map<String, dynamic>>
    checkDocument(
  String documentNumber,
) async {
  final normalizedDocument =
      documentNumber.trim();

  final encoded =
      Uri.encodeQueryComponent(
    normalizedDocument,
  );

  final response =
      await ApiService.get(
    '/auth/check-document'
    '?document_number=$encoded',

    requiresAuth:
        true,
  );

  final Map<String, dynamic> data =
      jsonDecode(
    response.body,
  );

  if (response.statusCode != 200) {
    throw Exception(
      data['detail'] ??
          'No se pudo comprobar el documento',
    );
  }

  return data;
}


  // =========================
  // COMPLETAR PERFIL
  // =========================

  static Future<Map<String, dynamic>>
      completeProfile({
    required String username,
    required DateTime dateOfBirth,
    String? phone,
    String? documentNumber,
    String? address,
    String? photoUrl,
  }) async {
    final response =
        await ApiService.post(
      '/auth/complete-profile',

      requiresAuth:
          true,

      body: {
        'username':
            username
                .trim()
                .toLowerCase(),

        'date_of_birth':
            _formatDate(
          dateOfBirth,
        ),

        'phone':
            phone != null &&
                    phone.trim().isNotEmpty
                ? phone.trim()
                : null,

        'document_number':
            documentNumber != null &&
                    documentNumber.trim().isNotEmpty
                ? documentNumber.trim()
                : null,

        'address':
            address != null &&
                    address.trim().isNotEmpty
                ? address.trim()
                : null,

        'photo_url':
            photoUrl != null &&
                    photoUrl.trim().isNotEmpty
                ? photoUrl.trim()
                : null,
      },
    );


    final Map<String, dynamic> data =
        jsonDecode(
      response.body,
    );


    if (response.statusCode != 200) {
      throw Exception(
        data['detail'] ??
            'No se pudo completar el perfil',
      );
    }


    await _saveUserPreferences(
      data,
    );


    return data;
  }


  // =========================
  // GUARDAR SESIÓN
  // =========================

  static Future<void> _saveBackendSession(
    Map<String, dynamic> data,
  ) async {
    final String accessToken =
        data['access_token']
            as String;


    final String refreshToken =
        data['refresh_token']
            as String;


    final Map<String, dynamic> user =
        Map<String, dynamic>.from(
      data['user'] as Map,
    );


    await _secureStorage.write(
      key:
          _accessTokenKey,

      value:
          accessToken,
    );


    await _secureStorage.write(
      key:
          _refreshTokenKey,

      value:
          refreshToken,
    );


    await _saveUserPreferences(
      user,
    );
  }


  // =========================
  // GUARDAR DATOS USUARIO
  // =========================

  static Future<void> _saveUserPreferences(
    Map<String, dynamic> user,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();


    await prefs.setBool(
      _isLoggedInKey,
      true,
    );


    await prefs.setString(
      _userNameKey,
      _buildUserName(
        user,
      ),
    );


    await prefs.setString(
      _userEmailKey,
      user['email']
              ?.toString() ??
          '',
    );


    await prefs.setString(
      _userPhotoKey,
      user['photo_url']
              ?.toString() ??
          '',
    );


    await prefs.setString(
      _userRoleKey,
      user['role']
              ?.toString() ??
          '',
    );


    final permissions =
        user['permissions'];


    if (permissions is List) {
      await prefs.setStringList(
        _userPermissionsKey,
        permissions
            .map(
              (permission) =>
                  permission.toString(),
            )
            .toList(),
      );
    } else {
      await prefs.setStringList(
        _userPermissionsKey,
        [],
      );
    }


    await prefs.setBool(
      _profileCompletedKey,
      user['profile_completed'] ==
          true,
    );
  }


  // =========================
  // REFRESH MANUAL
  // =========================

  static Future<String?>
      refreshAccessToken() async {
    final refreshToken =
        await getRefreshToken();


    if (refreshToken == null ||
        refreshToken.isEmpty) {
      return null;
    }


    try {
      final response =
          await ApiService.post(
        '/auth/refresh',

        body: {
          'refresh_token':
              refreshToken,
        },
      );


      if (response.statusCode != 200) {
        await clearLocalSession();

        return null;
      }


      final Map<String, dynamic> data =
          jsonDecode(
        response.body,
      );


      final String? newAccessToken =
          data['access_token']
              ?.toString();


      final String? newRefreshToken =
          data['refresh_token']
              ?.toString();


      if (newAccessToken == null ||
          newAccessToken.isEmpty) {
        await clearLocalSession();

        return null;
      }


      await _secureStorage.write(
        key:
            _accessTokenKey,

        value:
            newAccessToken,
      );


      if (newRefreshToken != null &&
          newRefreshToken.isNotEmpty) {
        await _secureStorage.write(
          key:
              _refreshTokenKey,

          value:
              newRefreshToken,
        );
      }


      final user =
          data['user'];


      if (user is Map) {
        await _saveUserPreferences(
          Map<String, dynamic>.from(
            user,
          ),
        );
      }


      return newAccessToken;
    } catch (error) {
      debugPrint(
        'Error renovando token: $error',
      );

      return null;
    }
  }


  // =========================
  // TOKENS
  // =========================

  static Future<String?> getAccessToken() async {
    return _secureStorage.read(
      key:
          _accessTokenKey,
    );
  }


  static Future<String?> getRefreshToken() async {
    return _secureStorage.read(
      key:
          _refreshTokenKey,
    );
  }


  // =========================
  // SESIÓN
  // =========================

  static Future<bool> isLoggedIn() async {
    final refreshToken =
        await getRefreshToken();


    return refreshToken != null &&
        refreshToken.isNotEmpty;
  }


  static Future<bool>
      isProfileCompleted() async {
    final prefs =
        await SharedPreferences.getInstance();


    return prefs.getBool(
          _profileCompletedKey,
        ) ??
        false;
  }


  static Future<String?> getUserName() async {
    final prefs =
        await SharedPreferences.getInstance();


    return prefs.getString(
      _userNameKey,
    );
  }


  static Future<String?> getUserEmail() async {
    final prefs =
        await SharedPreferences.getInstance();


    return prefs.getString(
      _userEmailKey,
    );
  }


  static Future<String?> getUserPhoto() async {
    final prefs =
        await SharedPreferences.getInstance();


    return prefs.getString(
      _userPhotoKey,
    );
  }


  static Future<String?> getUserRole() async {
    final prefs =
        await SharedPreferences.getInstance();


    return prefs.getString(
      _userRoleKey,
    );
  }


  static Future<List<String>>
      getUserPermissions() async {
    final prefs =
        await SharedPreferences.getInstance();


    return prefs.getStringList(
          _userPermissionsKey,
        ) ??
        [];
  }


  static Future<bool> hasPermission(
    String permission,
  ) async {
    final permissions =
        await getUserPermissions();


    return permissions.contains(
      permission,
    );
  }


  // =========================
  // LOGOUT
  // =========================

  static Future<void> logout() async {
    final refreshToken =
        await getRefreshToken();


    if (refreshToken != null &&
        refreshToken.isNotEmpty) {
      try {
        await ApiService.post(
          '/auth/logout',

          body: {
            'refresh_token':
                refreshToken,
          },
        );
      } catch (error) {
        debugPrint(
          'Error cerrando sesión en backend: $error',
        );
      }
    }


    try {
      await _googleSignIn.signOut();
    } catch (error) {
      debugPrint(
        'Error cerrando sesión de Google: $error',
      );
    }


    await clearLocalSession();
  }


  // =========================
  // LIMPIAR SESIÓN LOCAL
  // =========================

  static Future<void> clearLocalSession() async {
    await _secureStorage.delete(
      key:
          _accessTokenKey,
    );


    await _secureStorage.delete(
      key:
          _refreshTokenKey,
    );


    final prefs =
        await SharedPreferences.getInstance();


    await prefs.remove(
      _isLoggedInKey,
    );


    await prefs.remove(
      _userNameKey,
    );


    await prefs.remove(
      _userEmailKey,
    );


    await prefs.remove(
      _userPhotoKey,
    );


    await prefs.remove(
      _userRoleKey,
    );


    await prefs.remove(
      _userPermissionsKey,
    );


    await prefs.remove(
      _profileCompletedKey,
    );
  }


  // =========================
  // HELPERS
  // =========================

  static String _buildUserName(
    Map<String, dynamic> user,
  ) {
    final firstName =
        user['first_name']
                ?.toString() ??
            '';


    final lastName =
        user['last_name']
                ?.toString() ??
            '';


    return '$firstName $lastName'
        .trim();
  }


  static String _formatDate(
    DateTime date,
  ) {
    final year =
        date.year.toString();


    final month =
        date.month
            .toString()
            .padLeft(
              2,
              '0',
            );


    final day =
        date.day
            .toString()
            .padLeft(
              2,
              '0',
            );


    return '$year-$month-$day';
  }
  
}