import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/app_error_message.dart';
import '../core/network/connectivity_service.dart';
import '../core/offline/offline_database.dart';
import 'api_service.dart';
import 'offline_reservation_service.dart';

/// Reenvía ÚNICAMENTE reservas del cliente mediante el UUID persistente.
/// Verificado contra FastAPI: POST /reservations/mine acepta
/// client_operation_id y retorna la misma reserva cuando el UUID/payload
/// se repite. No sincroniza ventas ni carritos (contratos distintos).
class OfflineSyncCoordinator {
  OfflineSyncCoordinator._();
  static final instance = OfflineSyncCoordinator._();

  final ValueNotifier<bool> serverReachable = ValueNotifier(false);
  final ValueNotifier<int> queuedOperations = ValueNotifier(0);
  final ValueNotifier<bool> syncing = ValueNotifier(false);
  VoidCallback? _listener;
  bool _checking = false;
  int? _activeBranch;
  Timer? _retryTimer;
  // Un máximo de 5 minutos entre reintentos, sin un bucle agresivo.
  static const _maxRetryDelay = Duration(minutes: 5);

  Duration _retryDelay(int attempts) {
    final exponent = attempts.clamp(1, 6).toInt();
    final seconds = (5 * (1 << (exponent - 1))).clamp(5, _maxRetryDelay.inSeconds).toInt();
    return Duration(seconds: seconds);
  }

  Future<(int, int)?> _identity() async {
    final prefs = await SharedPreferences.getInstance();
    final tenantId = prefs.getInt('auth_tenant_id');
    final userId = int.tryParse(prefs.getString('auth_user_id') ?? '');
    if (tenantId == null || tenantId <= 0 || userId == null || userId <= 0) return null;
    return (tenantId, userId);
  }

  Future<List<OfflineScope>> _localScopes() async {
    final identity = await _identity();
    if (identity == null) return const [];
    final (tenantId, userId) = identity;
    final branchIds = await OfflineDatabase.instance.pendingReservationBranchIds(
      tenantId: tenantId, userId: userId);
    if (_activeBranch != null && _activeBranch! > 0 && !branchIds.contains(_activeBranch)) {
      branchIds.add(_activeBranch!);
    }
    return branchIds.map((branchId) => OfflineScope(
      tenantId: tenantId, branchId: branchId, userId: userId)).toList();
  }

  void _scheduleRetry(Duration delay) {
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () => unawaited(refresh()));
  }


  Future<void> startForBranch(int branchId) async {
    // La sucursal debe pertenecer a la sesión vigente; la API lo validará.
    await OfflineReservationService.requireScope(branchId);
    _activeBranch = branchId;
    _listener ??= () { unawaited(refresh()); };
    ConnectivityService.instance.status.removeListener(_listener!);
    ConnectivityService.instance.status.addListener(_listener!);
    await refresh();
  }

  /// Puede llamarse al abrir Mis reservas tras reiniciar la aplicación.
  /// Solo procesa sucursales accesibles al tenant y cuenta actuales.
  Future<void> startForMyReservations() async {
    _activeBranch = null;
    _listener ??= () { unawaited(refresh()); };
    ConnectivityService.instance.status.removeListener(_listener!);
    ConnectivityService.instance.status.addListener(_listener!);
    await refresh();
  }

  Future<void> refresh() async {
    if (_checking) return;
    _checking = true;
    try {
      final online = await ConnectivityService.instance.canSyncNow();
      serverReachable.value = online;
      if (online) {
        await _sendPendingReservations();
      } else {
        _retryTimer?.cancel();
      }
      await _countPending();
      OfflineReservationService.notifyChanged();
    } catch (error) {
      debugPrint('[FS-SYNC] No se pudo sincronizar: $error');
    } finally {
      _checking = false;
    }
  }

  Future<void> _countPending() async {
    try {
      var count = 0;
      for (final scope in await _localScopes()) {
        final pending = await OfflineDatabase.instance.getOperations(
          scope: scope, status: OfflineDatabase.pending);
        count += pending.where((op) => op.type == 'RESERVATION_CREATE').length;
      }
      queuedOperations.value = count;
    } catch (error) {
      debugPrint('[FS-SYNC] No se pudo contar pendientes SQLite: $error');
    }
  }

  Future<void> _sendPendingReservations() async {
    if (syncing.value) return;
    syncing.value = true;
    _retryTimer?.cancel();
    Duration? nextRetry;
    try {
      for (final scope in await _localScopes()) {
        final pending = await OfflineDatabase.instance.getOperations(
          scope: scope, status: OfflineDatabase.pending);
        for (final operation in pending) {
          if (operation.type != 'RESERVATION_CREATE') continue;
          // Aplicar espera entre fallos; también funciona después de reiniciar
          // porque attempts/updated_at se conservan en SQLite.
          if (operation.attempts > 0 && operation.lastError != null) {
            final eligibleAt = operation.updatedAt.add(_retryDelay(operation.attempts));
            final remaining = eligibleAt.difference(DateTime.now().toUtc());
            if (remaining > Duration.zero) {
              if (nextRetry == null || remaining < nextRetry) nextRetry = remaining;
              continue;
            }
          }
          final body = Map<String, dynamic>.from(operation.payload);
          body['client_operation_id'] = operation.id;
          body['branch_id'] = scope.branchId;
          body.remove('customer_id');
          body.remove('tenant_id');
          body.remove('user_id');
          try {
            final response = await ApiService.post(
              '/reservations/mine', requiresAuth: true, body: body);
            if (response.statusCode == 200 || response.statusCode == 201) {
              await OfflineDatabase.instance.updateOperation(
                scope: scope, operationId: operation.id,
                status: OfflineDatabase.synced, attempted: true);
              debugPrint('[FS-SYNC] Reserva ${operation.id} aceptada por FastAPI');
              continue;
            }
            final info = _serverMessage(response.body);
            if (response.statusCode == 401 || response.statusCode == 403) {
              await OfflineDatabase.instance.updateOperation(
                scope: scope, operationId: operation.id,
                status: OfflineDatabase.pending, attempted: true,
                error: 'HTTP ${response.statusCode}: $info');
              // Es necesaria una sesión válida: no repetir automáticamente.
              return;
            }
            if (response.statusCode >= 500 || response.statusCode == 429 || response.statusCode == 408) {
              await OfflineDatabase.instance.updateOperation(
                scope: scope, operationId: operation.id,
                status: OfflineDatabase.pending, attempted: true,
                error: 'HTTP ${response.statusCode}: $info');
              nextRetry = _retryDelay(operation.attempts + 1);
              return;
            }
            await OfflineDatabase.instance.updateOperation(
              scope: scope, operationId: operation.id,
              status: OfflineDatabase.conflict, attempted: true,
              error: 'HTTP ${response.statusCode}: $info');
            debugPrint('[FS-SYNC] Reserva ${operation.id} requiere revisión: $info');
          } on AppNetworkException catch (error) {
            await OfflineDatabase.instance.updateOperation(
              scope: scope, operationId: operation.id,
              status: OfflineDatabase.pending, attempted: true,
              error: error.message);
            nextRetry = _retryDelay(operation.attempts + 1);
            return;
          } catch (error) {
            debugPrint('[FS-SYNC] Error inesperado: $error');
            await OfflineDatabase.instance.updateOperation(
              scope: scope, operationId: operation.id,
              status: OfflineDatabase.pending, attempted: true,
              error: 'No se pudo completar la sincronización.');
            nextRetry = _retryDelay(operation.attempts + 1);
            return;
          }
        }
      }
    } finally {
      syncing.value = false;
      if (nextRetry != null && serverReachable.value) _scheduleRetry(nextRetry);
    }
  }

  static String _serverMessage(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map && data['detail'] != null) {
        final detail = data['detail'];
        final message = detail is String ? detail : detail.toString();
        return message.length > 300 ? message.substring(0, 300) : message;
      }
    } catch (_) {}
    return 'El servidor rechazó la operación.';
  }

  void stop() {
    if (_listener != null) {
      ConnectivityService.instance.status.removeListener(_listener!);
    }
    _activeBranch = null;
    _retryTimer?.cancel();
    _retryTimer = null;
  }
}
