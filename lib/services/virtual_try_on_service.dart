import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../models/virtual_try_on.dart';
import 'api_service.dart';
import 'auth_service.dart';

class VirtualTryOnService {
  VirtualTryOnService._();

  static const int maxFileSizeBytes =
      10 * 1024 * 1024;

  static const Set<String> allowedExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
  };

  static Future<VirtualTryOnResult> generate({
    required int variantId,
    required XFile personImage,
  }) async {
    _validateFile(personImage);

    var accessToken =
        await AuthService.getAccessToken();

    var response = await _send(
      variantId: variantId,
      personImage: personImage,
      accessToken: accessToken,
    );

    if (response.statusCode == 401) {
      accessToken =
          await AuthService.refreshAccessToken();

      if (accessToken != null &&
          accessToken.isNotEmpty) {
        response = await _send(
          variantId: variantId,
          personImage: personImage,
          accessToken: accessToken,
        );
      }
    }

    dynamic data;

    try {
      data = jsonDecode(response.body);
    } catch (_) {
      data = null;
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw VirtualTryOnException(
        _errorMessage(
          data,
          response.statusCode,
        ),
        statusCode: response.statusCode,
      );
    }

    if (data is! Map) {
      throw const VirtualTryOnException(
        'El probador devolvió una respuesta inválida.',
      );
    }

    return VirtualTryOnResult.fromJson(
      Map<String, dynamic>.from(data),
    );
  }

  static Future<http.Response> _send({
    required int variantId,
    required XFile personImage,
    required String? accessToken,
  }) async {
    final uri = Uri.parse(
      '${ApiService.baseUrl}/ai/virtual-try-on',
    );

    final request =
        http.MultipartRequest('POST', uri);

    request.fields['variant_id'] =
        variantId.toString();

    if (accessToken != null &&
        accessToken.isNotEmpty) {
      request.headers['Authorization'] =
          'Bearer $accessToken';
    }

    request.headers['Accept'] =
        'application/json';

    final contentType =
        _contentTypeFor(personImage.name);

    request.files.add(
      await http.MultipartFile.fromPath(
        'person_image',
        personImage.path,
        filename: personImage.name,
        contentType: contentType,
      ),
    );

    final streamed =
        await request.send();

    return http.Response.fromStream(
      streamed,
    );
  }

  static Future<void> validatePickedFile(
    XFile file,
  ) async {
    _validateExtension(file.name);

    final length = await file.length();

    if (length > maxFileSizeBytes) {
      throw const VirtualTryOnException(
        'La foto no puede superar los 10 MB.',
      );
    }
  }

  static void _validateFile(
    XFile file,
  ) {
    _validateExtension(file.name);
  }

  static void _validateExtension(
    String name,
  ) {
    final parts =
        name.toLowerCase().split('.');

    final extension =
        parts.length > 1 ? parts.last : '';

    if (!allowedExtensions.contains(
      extension,
    )) {
      throw const VirtualTryOnException(
        'Usa una imagen JPG, PNG o WEBP.',
      );
    }
  }

  static MediaType _contentTypeFor(
    String name,
  ) {
    final extension =
        name.toLowerCase().split('.').last;

    switch (extension) {
      case 'png':
        return MediaType(
          'image',
          'png',
        );

      case 'webp':
        return MediaType(
          'image',
          'webp',
        );

      case 'jpg':
      case 'jpeg':
      default:
        return MediaType(
          'image',
          'jpeg',
        );
    }
  }

  static String _errorMessage(
    dynamic data,
    int statusCode,
  ) {
    if (statusCode == 401) {
      return 'Tu sesión expiró. Inicia sesión nuevamente para continuar.';
    }

    if (statusCode == 403) {
      return 'Tu cuenta no tiene permiso para utilizar el probador virtual.';
    }

    if (data is Map &&
        data['detail'] != null) {
      return data['detail'].toString();
    }

    return 'No pudimos generar la prueba virtual. Inténtalo nuevamente en unos segundos.';
  }
}
