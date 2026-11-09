import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../../services/api_service.dart';

/// Estado observado de la conectividad con el backend de FashionStore.
/// `apiAvailable` no significa que la sesión esté autenticada.
enum ConnectionStatus { checking, offline, networkOnly, apiAvailable }

/// Solo observa conectividad: no sincroniza ni elimina operaciones SQLite.
/// Los consumidores deben llamar a [checkNow] antes de enviar pendientes.
class ConnectivityService with WidgetsBindingObserver {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  final ValueNotifier<ConnectionStatus> status =
      ValueNotifier<ConnectionStatus>(ConnectionStatus.checking);

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _healthTimer;
  bool _probeRunning = false;
  bool _started = false;
  int _generation = 0;

  /// Inicia el seguimiento de cambios de Wi-Fi/datos móviles.
  /// No usar el estado Wi-Fi como confirmación de Internet.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    // Revisa FastAPI incluso cuando Wi-Fi no cambia (p. ej. reiniciar Uvicorn).
    _healthTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(checkNow());
    });
    _subscription = _connectivity.onConnectivityChanged.listen((_) {
      unawaited(checkNow());
    });
    await checkNow();
  }

  /// Verifica la red y que FastAPI responda, con tiempo de espera limitado.
  /// Un 401/404 significa que el servidor está disponible, aunque no sea
  /// una petición autorizada o una ruta pública válida.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(checkNow());
  }

  Future<ConnectionStatus> checkNow() async {
    if (_probeRunning) return status.value;
    _probeRunning = true;
    final requestGeneration = ++_generation;
    try {
      final interfaces = await _connectivity.checkConnectivity();
      if (interfaces.isEmpty ||
          interfaces.every((e) => e == ConnectivityResult.none)) {
        return _setIfCurrent(requestGeneration, ConnectionStatus.offline);
      }

      final rawBase = ApiService.baseUrl.trim();
      final base = Uri.parse(rawBase);
      if (base.scheme != 'http' && base.scheme != 'https') {
        return _setIfCurrent(requestGeneration, ConnectionStatus.networkOnly);
      }

      // No utiliza tokens ni modifica datos. GET a la URL base de la API:
      // 200, 401, 403 y 404 implican que el servidor contestó.
      final response = await http.get(base).timeout(const Duration(seconds: 4));
      return _setIfCurrent(
        requestGeneration,
        response.statusCode < 500
            ? ConnectionStatus.apiAvailable
            : ConnectionStatus.networkOnly,
      );
    } catch (_) {
      // El dispositivo puede tener Wi-Fi, pero el backend estar apagado.
      return _setIfCurrent(requestGeneration, ConnectionStatus.networkOnly);
    } finally {
      _probeRunning = false;
    }
  }

  ConnectionStatus _setIfCurrent(int generation, ConnectionStatus next) {
    if (generation == _generation && status.value != next) {
      debugPrint('[FS-CONEXION] ${status.value.name} -> ${next.name}');
      status.value = next;
    }
    return status.value;
  }

  bool get canReachApi => status.value == ConnectionStatus.apiAvailable;

  Future<bool> canSyncNow() async =>
      await checkNow() == ConnectionStatus.apiAvailable;

  Future<void> dispose() async {
    ++_generation;
    _healthTimer?.cancel();
    _healthTimer = null;
    WidgetsBinding.instance.removeObserver(this);
    await _subscription?.cancel();
    _subscription = null;
    _started = false;
  }
}
