import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Traduce fallos técnicos a mensajes seguros para la interfaz.
/// El error original debe registrarse en logs durante desarrollo, no en UI.
class AppErrorMessage {
  AppErrorMessage._();

  static String from(Object error) {
    if (error is AppNetworkException) return error.message;
    if (error is SocketException || error is http.ClientException) {
      return 'No pudimos conectar con el servidor. '
          'Comprueba tu conexión o inténtalo nuevamente más tarde.';
    }
    if (error is TimeoutException) {
      return 'El servidor está tardando demasiado en responder. '
          'Inténtalo nuevamente.';
    }
    if (error is HandshakeException || error is TlsException) {
      return 'No se pudo establecer una conexión segura con el servidor.';
    }

    final value = error.toString().toLowerCase();
    // Algunas capas HTTP envuelven SocketException en otra excepción.
    if (value.contains('socketexception') ||
        value.contains('connection refused') ||
        value.contains('failed host lookup') ||
        value.contains('network is unreachable') ||
        value.contains('connection reset') ||
        value.contains('clientexception')) {
      return 'No pudimos conectar con el servidor. '
          'Comprueba tu conexión o inténtalo nuevamente más tarde.';
    }
    if (value.contains('timeout') || value.contains('timed out')) {
      return 'El servidor está tardando demasiado en responder. '
          'Inténtalo nuevamente.';
    }
    if (value.contains('401') || value.contains('sesión expirada') ||
        value.contains('sesion expirada')) {
      return 'Tu sesión ha expirado. Inicia sesión nuevamente.';
    }
    if (value.contains('403')) {
      return 'No tienes permiso para realizar esta acción.';
    }
    if (value.contains('500') || value.contains('502') ||
        value.contains('503') || value.contains('504')) {
      return 'El servidor tiene un problema temporal. '
          'Inténtalo nuevamente más tarde.';
    }
    return 'No pudimos cargar la información en este momento. '
        'Inténtalo nuevamente.';
  }
}

/// Error de transporte seguro para mostrar en cualquier pantalla.
class AppNetworkException implements Exception {
  const AppNetworkException(this.message);

  final String message;

  @override
  String toString() => message;
}
