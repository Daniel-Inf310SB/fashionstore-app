import 'dart:math';
import 'package:flutter/foundation.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/offline/offline_database.dart';
import '../repositories/offline_commerce_repository.dart';

/// Captura local de reservas del CLIENTE; no crea reservas confirmadas.
/// Nunca deducir permisos ni identidad a partir de una sucursal seleccionada.
class OfflineReservationService {
  OfflineReservationService._();

  static final repository = OfflineCommerceRepository();
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);
  static void notifyChanged() => changes.value++;

  static Future<OfflineScope> requireScope(int branchId) async {
    final prefs = await SharedPreferences.getInstance();
    final tenantId = prefs.getInt('auth_tenant_id');
    final userId = int.tryParse(prefs.getString('auth_user_id') ?? '');
    if (tenantId == null || tenantId <= 0 || userId == null || userId <= 0 || branchId <= 0) {
      throw StateError('Inicia sesión con una empresa y selecciona una sucursal antes de guardar la reserva.');
    }
    return OfflineScope(tenantId: tenantId, branchId: branchId, userId: userId);
  }

  /// UUID v4 generado criptográficamente una sola vez para reintentos futuros.
  static String newOperationId() {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0,8)}-${h.substring(8,12)}-${h.substring(12,16)}-${h.substring(16,20)}-${h.substring(20)}';
  }

  static Future<String> savePending({
    required int branchId,
    required int variantId,
    required int quantity,
    required double unitPrice,
    String? notes,
    String? productName,
    String? sizeName,
    String? colorName,
    String? branchName,
  }) async {
    if (variantId <= 0 || quantity <= 0 || !unitPrice.isFinite || unitPrice < 0) {
      throw ArgumentError('Prenda, cantidad o precio no válidos');
    }
    final scope = await requireScope(branchId);
    final id = newOperationId();
    await repository.savePendingTransaction(
      scope: scope,
      operationId: id,
      operationType: 'RESERVATION_CREATE',
      lines: [OfflineLine(variantId: variantId, quantity: quantity,
        unitPriceCents: (unitPrice * 100).round())],
      payloadExtra: {'notes': notes?.trim().isEmpty == true ? null : notes?.trim()},
      localDisplay: {
        'branch_name': branchName ?? 'Sucursal',
        'items': [{
          'variant_id': variantId, 'name': productName ?? 'Prenda',
          'size': sizeName ?? '', 'color': colorName ?? '',
          'quantity': quantity, 'unit_price_cents': (unitPrice * 100).round(),
        }],
      },
    );
    notifyChanged();
    return id;
  }

  static Future<List<LocalReservationRecord>> details({
    required int branchId, String? branchName,
  }) async {
    final scope = await requireScope(branchId);
    final operations = (await repository.allOperations(scope))
        .where((o) => o.type == 'RESERVATION_CREATE' &&
          o.status != OfflineDatabase.synced);
    final result = <LocalReservationRecord>[];
    for (final op in operations) {
      final display = await repository.reservationDisplay(
        scope: scope, operationId: op.id);
      final stored = await repository.transactionItems(
        scope: scope, operationId: op.id);
      final descriptions = (display?['items'] as List?)
          ?.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() ?? [];
      final lines = <Map<String, dynamic>>[];
      for (final row in stored) {
        final variantId = (row['variant_id'] as num).toInt();
        final match = descriptions.where((m) => m['variant_id'] == variantId);
        lines.add({
          ...row,
          if (match.isNotEmpty) ...match.first,
          'variant_id': variantId,
          'quantity': row['quantity'],
          'unit_price_cents': row['unit_price_cents'],
        });
      }
      result.add(LocalReservationRecord(
        operation: op, branchId: branchId,
        branchName: display?['branch_name']?.toString() ?? branchName ?? 'Sucursal',
        items: lines,
      ));
    }
    return result;
  }

  static Future<List<OfflineOperation>> list({required int branchId}) async =>
      repository.allOperations(await requireScope(branchId));
}

/// Representación local únicamente. Nunca implica confirmación central.
class LocalReservationRecord {
  const LocalReservationRecord({
    required this.operation, required this.branchId,
    required this.branchName, required this.items,
  });
  final OfflineOperation operation;
  final int branchId;
  final String branchName;
  final List<Map<String, dynamic>> items;
  int get totalCents => items.fold<int>(0, (sum, item) => sum +
    ((item['quantity'] as num?)?.toInt() ?? 0) *
    ((item['unit_price_cents'] as num?)?.toInt() ?? 0));
}
