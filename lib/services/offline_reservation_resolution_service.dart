import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/offline/offline_database.dart';
import 'api_service.dart';
import 'offline_reservation_service.dart';
import 'reservation_service.dart';

/// Resolución EXPLÍCITA de una reserva offline rechazada porque ya existe
/// otra PENDING en la misma sucursal. No reenvía automáticamente escrituras
/// sin idempotencia (POST /reservations/mine/{id}/items).
class OfflineReservationResolutionService {
  const OfflineReservationResolutionService();

  static const uncertainPrefix = 'RESULTADO_INCIERTO: ';

  /// Devuelve la reserva PENDING actual o null. La identidad viene del JWT.
  Future<ReservationMergeTarget?> findPending(LocalReservationRecord local) async {
    final pending = await ReservationService.getMyPendingReservation(local.branchId);
    if (pending == null) return null;
    return ReservationMergeTarget(id: pending.id, code: pending.reservationCode);
  }

  /// Solo se debe invocar tras mostrar y aceptar una confirmación explícita.
  /// Una caída tras enviar puede dejar el resultado incierto; NUNCA reintenta
  /// este POST automáticamente, pues el backend todavía no da idempotencia
  /// para agregar ítems a una reserva existente.
  Future<ReservationMergeResult> addToPending({
    required LocalReservationRecord local,
    required ReservationMergeTarget target,
  }) async {
    final scope = await OfflineReservationService.requireScope(local.branchId);
    final matches = await OfflineDatabase.instance.getOperations(scope: scope);
    final current = matches.where((op) => op.id == local.operation.id).toList();
    if (current.length != 1 || current.single.status != OfflineDatabase.conflict) {
      return const ReservationMergeResult(false, 'Esta operación ya cambió de estado. Actualiza la lista.');
    }
    if ((current.single.lastError ?? '').startsWith(uncertainPrefix)) {
      return const ReservationMergeResult(false, 'El resultado anterior es incierto. Revisa la reserva del servidor antes de intentar otra vez.');
    }
    if (local.items.isEmpty) {
      return const ReservationMergeResult(false, 'Esta operación no tiene prendas guardadas.');
    }
    final items = <Map<String, int>>[];
    for (final row in local.items) {
      final variant = (row['variant_id'] as num?)?.toInt();
      final quantity = (row['quantity'] as num?)?.toInt();
      if (variant == null || variant <= 0 || quantity == null || quantity <= 0) {
        return const ReservationMergeResult(false, 'Los detalles locales no son válidos.');
      }
      items.add({'product_variant_id': variant, 'quantity': quantity});
    }
    // Primero guardar estado incierto, para proteger contra cierres repentinos
    // después del envío y antes de que Flutter reciba la respuesta.
    await OfflineDatabase.instance.updateOperation(
      scope: scope, operationId: local.operation.id,
      status: OfflineDatabase.conflict,
      error: '${uncertainPrefix}Se inició la incorporación a ${target.code}. Verifica el resultado en el servidor antes de reintentar.',
    );
    OfflineReservationService.notifyChanged();

    try {
      final response = await ApiService.post(
        '/reservations/mine/${target.id}/items',
        requiresAuth: true,
        body: {'items': items},
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        await OfflineDatabase.instance.updateOperation(
          scope: scope, operationId: local.operation.id,
          status: OfflineDatabase.synced, attempted: true,
        );
        OfflineReservationService.notifyChanged();
        return ReservationMergeResult(true, 'Las prendas se añadieron a ${target.code}.');
      }
      final message = _detail(response.body);
      // Una respuesta HTTP explícita 4xx es un rechazo conocido; puede
      // requerir ajustar cantidades o cambiar variantes, nunca borrar datos.
      if (response.statusCode >= 400 && response.statusCode < 500) {
        await OfflineDatabase.instance.updateOperation(
          scope: scope, operationId: local.operation.id,
          status: OfflineDatabase.conflict, attempted: true,
          error: 'HTTP ${response.statusCode}: $message',
        );
        OfflineReservationService.notifyChanged();
        return ReservationMergeResult(false, message);
      }
      // 5xx puede ocurrir después de una escritura confirmada: incierto.
      return ReservationMergeResult(false,
          'El servidor respondió ${response.statusCode}. Verifica si las prendas se añadieron; no se reenviarán automáticamente.');
    } catch (error) {
      debugPrint('[FS-RESERVA-RESOLVER] Resultado incierto: $error');
      // No tocar el marcador incierto: conserva datos, impide duplicados.
      OfflineReservationService.notifyChanged();
      return const ReservationMergeResult(false,
          'No recibimos una confirmación. Comprueba primero el detalle de la reserva del servidor; no reenviaremos las prendas automáticamente.');
    }
  }

  static String _detail(String body) {
    try {
      final obj = jsonDecode(body);
      if (obj is Map && obj['detail'] != null) return obj['detail'].toString();
    } catch (_) {}
    return 'La operación fue rechazada por el servidor.';
  }
}

class ReservationMergeTarget {
  const ReservationMergeTarget({required this.id, required this.code});
  final int id;
  final String code;
}

class ReservationMergeResult {
  const ReservationMergeResult(this.success, this.message);
  final bool success;
  final String message;
}
