import 'dart:convert';

import 'package:http/http.dart' as http;

/// Excepción estándar lanzada por los servicios cuando el backend
/// responde con un código de error. Extrae el `detail` que devuelve
/// FastAPI (`{"detail": "mensaje"}`) para mostrarlo tal cual en la UI.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  factory ApiException.fromResponse(http.Response response) {
    String message = 'Ocurrió un error inesperado (${response.statusCode}).';

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];

        if (detail is String) {
          message = detail;
        } else if (detail is List && detail.isNotEmpty) {
          // Errores de validación de Pydantic (422)
          final first = detail.first;
          if (first is Map && first['msg'] != null) {
            message = first['msg'].toString();
          }
        }
      }
    } catch (_) {
      // Si el cuerpo no es JSON, se mantiene el mensaje genérico.
    }

    return ApiException(response.statusCode, message);
  }

  @override
  String toString() => message;
}

/// Lanza [ApiException] si la respuesta no es 2xx.
void throwIfError(http.Response response) {
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw ApiException.fromResponse(response);
  }
}