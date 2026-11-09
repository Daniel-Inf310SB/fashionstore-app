import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../core/offline/offline_database.dart';
import '../services/offline_reservation_service.dart';

/// Borrador de carrito exclusivamente LOCAL. No es compra ni reserva.
/// Nunca se reenvía automáticamente como POST porque /carts/me/items
/// no tiene idempotencia comprobada en el backend actual.
class OfflineCartEntry {
  const OfflineCartEntry({required this.variantId, required this.productId,
    required this.productName, required this.variantLabel,
    required this.unitPriceCents, required this.quantity});
  final int variantId;
  final int productId;
  final String productName;
  final String variantLabel;
  final int unitPriceCents;
  final int quantity;
  int get totalCents => unitPriceCents * quantity;

  factory OfflineCartEntry.fromRow(Map<String, Object?> row) => OfflineCartEntry(
    variantId: row['variant_id'] as int,
    productId: row['product_id'] as int,
    productName: row['product_name'] as String,
    variantLabel: row['variant_label'] as String,
    unitPriceCents: row['unit_price_cents'] as int,
    quantity: row['quantity'] as int,
  );
}

class OfflineCartRepository {
  const OfflineCartRepository();

  /// Cuenta local de unidades para la sucursal y usuario activos.
  static final ValueNotifier<int> draftUnitsNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<int> mutationNotifier = ValueNotifier<int>(0);

  Future<void> refreshCount(int branchId) async {
    try {
      final scope = await OfflineReservationService.requireScope(branchId);
      final db = await OfflineDatabase.instance.database;
      final result = await db.rawQuery(
        'SELECT COALESCE(SUM(quantity), 0) AS total FROM offline_cart_drafts '
        'WHERE tenant_id=? AND branch_id=? AND user_id=?', scope.args);
      draftUnitsNotifier.value = (result.first['total'] as num?)?.toInt() ?? 0;
    } catch (_) {
      draftUnitsNotifier.value = 0;
    }
  }


  Future<List<OfflineCartEntry>> list(int branchId) async {
    final scope = await OfflineReservationService.requireScope(branchId);
    final db = await OfflineDatabase.instance.database;
    final rows = await db.query('offline_cart_drafts',
      where: 'tenant_id=? AND branch_id=? AND user_id=?', whereArgs: scope.args,
      orderBy: 'updated_at DESC');
    return rows.map(OfflineCartEntry.fromRow).toList();
  }

  Future<void> add({required int branchId, required int productId,
    required int variantId, required String productName,
    required String variantLabel, required int unitPriceCents,
    required int quantity}) async {
    if (variantId <= 0 || productId <= 0 || quantity <= 0 || unitPriceCents < 0) {
      throw ArgumentError('Producto, cantidad o precio inválido');
    }
    final scope = await OfflineReservationService.requireScope(branchId);
    final db = await OfflineDatabase.instance.database;
    await db.transaction((tx) async {
      final existing = await tx.query('offline_cart_drafts',
        columns: ['quantity'], where: 'tenant_id=? AND branch_id=? AND user_id=? AND variant_id=?',
        whereArgs: [...scope.args, variantId], limit: 1);
      final oldQty = existing.isEmpty ? 0 : existing.first['quantity'] as int;
      await tx.insert('offline_cart_drafts', {
        'tenant_id': scope.tenantId, 'branch_id': scope.branchId,
        'user_id': scope.userId, 'variant_id': variantId,
        'product_id': productId, 'product_name': productName,
        'variant_label': variantLabel, 'unit_price_cents': unitPriceCents,
        'quantity': oldQty + quantity,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
    await refreshCount(branchId);
    mutationNotifier.value++;
  }

  Future<void> setQuantity({required int branchId, required int variantId,
    required int quantity}) async {
    if (quantity <= 0) {
      await remove(branchId: branchId, variantId: variantId);
      return;
    }
    final scope = await OfflineReservationService.requireScope(branchId);
    final db = await OfflineDatabase.instance.database;
    await db.update('offline_cart_drafts', {
      'quantity': quantity,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, where: 'tenant_id=? AND branch_id=? AND user_id=? AND variant_id=?',
      whereArgs: [...scope.args, variantId]);
    await refreshCount(branchId);
    mutationNotifier.value++;
  }

  Future<void> remove({required int branchId, required int variantId}) async {
    final scope = await OfflineReservationService.requireScope(branchId);
    final db = await OfflineDatabase.instance.database;
    await db.delete('offline_cart_drafts',
      where: 'tenant_id=? AND branch_id=? AND user_id=? AND variant_id=?',
      whereArgs: [...scope.args, variantId]);
    await refreshCount(branchId);
    mutationNotifier.value++;
  }
  /// Una vez iniciado un envío, jamás se repite automáticamente si queda
  /// respuesta incierta. Se conserva evidencia hasta resolver el caso.
  Future<bool> requiresReview(int branchId, int variantId) async {
    final scope = await OfflineReservationService.requireScope(branchId);
    final db = await OfflineDatabase.instance.database;
    final rows = await db.query('offline_cart_transfers',
      where: 'tenant_id=? AND branch_id=? AND user_id=? AND variant_id=?',
      whereArgs: [...scope.args, variantId], limit: 1);
    return rows.isNotEmpty;
  }

  Future<void> markTransferStarted({required int branchId,
    required OfflineCartEntry draft, required int targetQuantity,
    int? remoteItemId}) async {
    final scope = await OfflineReservationService.requireScope(branchId);
    final db = await OfflineDatabase.instance.database;
    await db.insert('offline_cart_transfers', {
      'tenant_id': scope.tenantId, 'branch_id': scope.branchId,
      'user_id': scope.userId, 'variant_id': draft.variantId,
      'expected_quantity': draft.quantity, 'target_quantity': targetQuantity,
      'remote_item_id': remoteItemId, 'status': 'REVIEW',
      'started_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<void> transferSucceeded({required int branchId,
    required OfflineCartEntry draft}) async {
    final scope = await OfflineReservationService.requireScope(branchId);
    final db = await OfflineDatabase.instance.database;
    await db.transaction((tx) async {
      final rows = await tx.query('offline_cart_drafts',
        columns: ['quantity'],
        where: 'tenant_id=? AND branch_id=? AND user_id=? AND variant_id=?',
        whereArgs: [...scope.args, draft.variantId], limit: 1);
      if (rows.isNotEmpty && rows.first['quantity'] == draft.quantity) {
        await tx.delete('offline_cart_drafts',
          where: 'tenant_id=? AND branch_id=? AND user_id=? AND variant_id=?',
          whereArgs: [...scope.args, draft.variantId]);
        await tx.delete('offline_cart_transfers',
          where: 'tenant_id=? AND branch_id=? AND user_id=? AND variant_id=?',
          whereArgs: [...scope.args, draft.variantId]);
      } else {
        await tx.update('offline_cart_transfers', {
          'last_error': 'El borrador cambió durante el envío; revisar manualmente.'},
          where: 'tenant_id=? AND branch_id=? AND user_id=? AND variant_id=?',
          whereArgs: [...scope.args, draft.variantId]);
      }
    });
    await refreshCount(branchId);
    mutationNotifier.value++;
  }

}
