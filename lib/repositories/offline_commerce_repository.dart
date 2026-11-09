import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../core/offline/offline_database.dart';

/// SQLite repository only. Network sync will be implemented separately.
/// Prices are INTEGER cents, never floating point.
class OfflineCommerceRepository {
  OfflineCommerceRepository({OfflineDatabase? storage})
      : _storage = storage ?? OfflineDatabase.instance;

  final OfflineDatabase _storage;

  static String _now() => DateTime.now().toUtc().toIso8601String();

  static void _validScope(OfflineScope scope) {
    if (scope.tenantId <= 0 || scope.branchId <= 0 || scope.userId <= 0) {
      throw ArgumentError('Invalid tenant/branch/user context');
    }
  }

  /// Read POS catalog from /sales/catalog response `items`.
  /// All pages should be collected by the API layer before this call.
  /// Snapshots are upserted: local pending transactions are never deleted.
  Future<void> savePosCatalog({
    required OfflineScope scope,
    required List<Map<String, dynamic>> items,
  }) async {
    _validScope(scope);
    final db = await _storage.database;
    final now = _now();
    await db.transaction((txn) async {
      for (final item in items) {
        final productId = (item['product_id'] as num).toInt();
        final variantId = (item['product_variant_id'] as num).toInt();
        final priceCents = _toCents(item['unit_price']);
        final available = (item['available_quantity'] as num).toInt();
        if (productId <= 0 || variantId <= 0 || available < 0) {
          throw FormatException('Invalid POS catalog row');
        }
        final productData = <String, Object?>{
          'tenant_id': scope.tenantId,
          'branch_id': scope.branchId,
          'user_id': scope.userId,
          'product_id': productId,
          'code': item['product_code'] as String,
          'name': item['product_name'] as String,
          'brand': item['brand'],
          'category_id': null,
          'cover_image_url': item['image_url'],
          'synced_at': now,
        };
        // REPLACE elimina y reinserta la fila padre en SQLite, rompiendo
        // la FK de variantes ya descargadas en actualizaciones sucesivas.
        final updated = await txn.update('offline_products', productData,
          where: 'tenant_id = ? AND branch_id = ? AND user_id = ? AND product_id = ?',
          whereArgs: [...scope.args, productId]);
        if (updated == 0) {
          await txn.insert('offline_products', productData,
            conflictAlgorithm: ConflictAlgorithm.abort);
        }
        await txn.insert('offline_variants', {
          'tenant_id': scope.tenantId,
          'branch_id': scope.branchId,
          'user_id': scope.userId,
          'variant_id': variantId,
          'product_id': productId,
          'sku': item['sku'] as String,
          'size_name': item['size_name'],
          'color_name': item['color_name'],
          'image_url': item['image_url'],
          'unit_price_cents': priceCents,
          'known_available': available,
          'synced_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  /// Save customers returned by /sales/customers. Only minimum data.
  Future<void> saveCustomers({
    required OfflineScope scope,
    required List<Map<String, dynamic>> customers,
  }) async {
    _validScope(scope);
    final db = await _storage.database;
    final now = _now();
    await db.transaction((txn) async {
      for (final customer in customers) {
        await txn.insert('offline_customers', {
          'tenant_id': scope.tenantId,
          'branch_id': scope.branchId,
          'user_id': scope.userId,
          'customer_id': (customer['id'] as num).toInt(),
          'first_name': customer['first_name'] as String,
          'last_name': customer['last_name'],
          'email': customer['email'],
          'synced_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> saveBranch({
    required OfflineScope scope,
    required String name,
    String? address,
  }) async {
    _validScope(scope);
    final db = await _storage.database;
    await db.insert('offline_branches', {
      'tenant_id': scope.tenantId,
      'branch_id': scope.branchId,
      'user_id': scope.userId,
      'name': name,
      'address': address,
      'synced_at': _now(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, Object?>>> listKnownVariants(OfflineScope scope) async {
    _validScope(scope);
    final db = await _storage.database;
    return db.rawQuery('''
      SELECT v.variant_id, v.product_id, v.sku, v.size_name, v.color_name,
             v.unit_price_cents, v.known_available, v.synced_at,
             p.name AS product_name, p.code AS product_code
      FROM offline_variants v JOIN offline_products p
        ON p.tenant_id = v.tenant_id AND p.branch_id = v.branch_id
       AND p.user_id = v.user_id AND p.product_id = v.product_id
      WHERE v.tenant_id = ? AND v.branch_id = ? AND v.user_id = ?
      ORDER BY p.name, v.sku
    ''', scope.args);
  }

  Future<List<Map<String, Object?>>> listCustomers(OfflineScope scope) async {
    _validScope(scope);
    final db = await _storage.database;
    return db.query('offline_customers',
      where: 'tenant_id = ? AND branch_id = ? AND user_id = ?',
      whereArgs: scope.args, orderBy: 'first_name, last_name');
  }

  /// Inserts a sale/reservation with its details AND queue row in one transaction.
  /// `operationId` is an externally generated UUID v4, reused on every retry.
  /// For sales only use CASH; do not call Stripe offline.
  /// The payload must match the chosen FastAPI endpoint before sync is enabled.
  Future<void> savePendingTransaction({
    required OfflineScope scope,
    required String operationId,
    required String operationType,
    required List<OfflineLine> lines,
    int? customerId,
    String? paymentMethod,
    Map<String, dynamic> payloadExtra = const {},
    Map<String, dynamic>? localDisplay,
  }) async {
    _validScope(scope);
    if (operationType != 'SALE_CREATE' && operationType != 'RESERVATION_CREATE') {
      throw ArgumentError('Operation not supported');
    }
    final uuidV4 = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$');
    if (!uuidV4.hasMatch(operationId)) throw ArgumentError('UUID v4 required');
    if (lines.isEmpty) throw ArgumentError('At least one item required');
    if (lines.any((e) => e.variantId <= 0 || e.quantity <= 0 || e.unitPriceCents < 0)) {
      throw ArgumentError('Invalid item values');
    }
    if (lines.map((e) => e.variantId).toSet().length != lines.length) {
      throw ArgumentError('Duplicated variant; combine quantities first');
    }
    if (operationType == 'SALE_CREATE' && paymentMethod != 'CASH') {
      throw ArgumentError('Offline sales must be cash');
    }
    final total = lines.fold<int>(0, (sum, e) => sum + e.quantity * e.unitPriceCents);
    final items = lines.map((e) => <String, dynamic>{
      'product_variant_id': e.variantId,
      'quantity': e.quantity,
      if (operationType == 'SALE_CREATE')
        'expected_unit_price': (e.unitPriceCents / 100).toStringAsFixed(2),
    }).toList();
    final payload = <String, dynamic>{
      'client_operation_id': operationId,
      'branch_id': scope.branchId,
      if (customerId != null) 'customer_id': customerId,
      'items': items,
      ...payloadExtra,
    };
    // A caller cannot override operation identity or scope through extras.
    payload['client_operation_id'] = operationId;
    payload['branch_id'] = scope.branchId;
    payload['items'] = items;
    if (customerId != null) {
      payload['customer_id'] = customerId;
    } else {
      payload.remove('customer_id');
    }
    // El tenant y el usuario proceden del contexto autorizado, nunca de extras.
    payload.remove('tenant_id');
    payload.remove('user_id');
    final now = _now();
    final db = await _storage.database;
    await db.transaction((txn) async {
      // Intentional strict insert; never silently overwrite an existing UUID.
      await txn.insert('offline_operations', {
        'id': operationId, 'tenant_id': scope.tenantId,
        'branch_id': scope.branchId, 'user_id': scope.userId,
        'operation_type': operationType, 'payload_json': jsonEncode(payload),
        'status': OfflineDatabase.pending, 'attempts': 0,
        'created_at': now, 'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.abort);
      await txn.insert('offline_transactions', {
        'id': operationId, 'tenant_id': scope.tenantId,
        'branch_id': scope.branchId, 'user_id': scope.userId,
        'transaction_type': operationType, 'customer_id': customerId,
        'total_cents': total, 'payment_method': paymentMethod,
        'created_at': now,
      });
      if (operationType == 'RESERVATION_CREATE' && localDisplay != null) {
        await txn.insert('offline_reservation_display', {
          'operation_id': operationId, 'tenant_id': scope.tenantId,
          'branch_id': scope.branchId, 'user_id': scope.userId,
          'display_json': jsonEncode(localDisplay),
        });
      }
      for (final line in lines) {
        await txn.insert('offline_transaction_items', {
          'transaction_id': operationId,
          'variant_id': line.variantId, 'quantity': line.quantity,
          'unit_price_cents': line.unitPriceCents,
        });
      }
    });
  }

  Future<List<OfflineOperation>> pendingOperations(OfflineScope scope) =>
      _storage.getOperations(scope: scope, status: OfflineDatabase.pending);

  Future<List<OfflineOperation>> allOperations(OfflineScope scope) =>
      _storage.getOperations(scope: scope);

  Future<List<Map<String, Object?>>> transactionItems({
    required OfflineScope scope, required String operationId,
  }) async {
    final db = await _storage.database;
    return db.rawQuery('''
      SELECT i.* FROM offline_transaction_items i
      JOIN offline_transactions t ON t.id = i.transaction_id
      WHERE t.id = ? AND t.tenant_id = ? AND t.branch_id = ? AND t.user_id = ?
    ''', [operationId, ...scope.args]);
  }

  Future<Map<String, dynamic>?> reservationDisplay({
    required OfflineScope scope, required String operationId,
  }) async {
    final db = await _storage.database;
    final rows = await db.query('offline_reservation_display',
      columns: ['display_json'],
      where: 'operation_id=? AND tenant_id=? AND branch_id=? AND user_id=?',
      whereArgs: [operationId, ...scope.args], limit: 1);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(jsonDecode(rows.first['display_json'] as String) as Map);
  }

  static int _toCents(Object? value) {
    // Decimal from API can be a string or a number; parse base-10 exactly.
    final text = value.toString();
    final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(text);
    if (match == null) throw FormatException('Invalid monetary amount: $text');
    return int.parse(match.group(1)!) * 100 +
        int.parse((match.group(2) ?? '0').padRight(2, '0'));
  }
}

class OfflineLine {
  const OfflineLine({required this.variantId, required this.quantity, required this.unitPriceCents});
  final int variantId;
  final int quantity;
  final int unitPriceCents;
}
