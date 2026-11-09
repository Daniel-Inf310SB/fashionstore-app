import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Almacenamiento local de FashionStore (CU65).
///
/// No guarda contraseñas, tokens, datos de pago ni confirma inventario.
/// TODAS las operaciones requieren un contexto explícito; nunca compartir
/// registros de un usuario/tenant/sucursal con otro.
class OfflineScope {
  const OfflineScope({
    required this.tenantId,
    required this.branchId,
    required this.userId,
  }) : assert(tenantId > 0),
       assert(branchId > 0),
       assert(userId > 0);

  final int tenantId;
  final int branchId;
  final int userId;

  List<Object> get args => [tenantId, branchId, userId];
}

class OfflineOperation {
  const OfflineOperation({
    required this.id,
    required this.type,
    required this.payload,
    required this.status,
    required this.attempts,
    required this.createdAt,
    required this.updatedAt,
    this.lastError,
  });

  final String id;
  final String type;
  final Map<String, dynamic> payload;
  final String status;
  final int attempts;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastError;

  factory OfflineOperation.fromRow(Map<String, Object?> row) =>
      OfflineOperation(
        id: row['id']! as String,
        type: row['operation_type']! as String,
        payload: Map<String, dynamic>.from(
          jsonDecode(row['payload_json']! as String) as Map,
        ),
        status: row['status']! as String,
        attempts: row['attempts']! as int,
        createdAt: DateTime.parse(row['created_at']! as String),
        updatedAt: DateTime.parse(row['updated_at']! as String),
        lastError: row['last_error'] as String?,
      );
}

class OfflineDatabase {
  OfflineDatabase._();

  static final OfflineDatabase instance = OfflineDatabase._();
  static const _dbName = 'fashionstore_offline.db';
  static const _version = 6;
  static const pending = 'LOCAL_PENDING';
  static const synced = 'SYNCED';
  static const conflict = 'CONFLICT';
  static const rejected = 'REJECTED';
  static const _statuses = {pending, synced, conflict, rejected};
  static const _operationTypes = {'RESERVATION_CREATE', 'SALE_CREATE'};

  Database? _database;
  Future<Database>? _opening;

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    return _opening ??= _open()
        .then((db) {
          _database = db;
          return db;
        })
        .whenComplete(() => _opening = null);
  }

  Future<Database> _open() async {
    final location = p.join(await getDatabasesPath(), _dbName);
    return openDatabase(
      location,
      version: _version,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE catalog_snapshots (
            tenant_id INTEGER NOT NULL,
            branch_id INTEGER NOT NULL,
            user_id INTEGER NOT NULL,
            cache_key TEXT NOT NULL,
            data_json TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            PRIMARY KEY (tenant_id, branch_id, user_id, cache_key)
          )
        ''');
        await db.execute('''
          CREATE TABLE offline_operations (
            id TEXT NOT NULL PRIMARY KEY,
            tenant_id INTEGER NOT NULL,
            branch_id INTEGER NOT NULL,
            user_id INTEGER NOT NULL,
            operation_type TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'LOCAL_PENDING',
            attempts INTEGER NOT NULL DEFAULT 0,
            last_error TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE INDEX idx_offline_operations_scope_status
          ON offline_operations(tenant_id, branch_id, user_id, status, created_at)
        ''');
        await _createCommercialTables(db);
        await _createDraftCartTable(db);
        await _createCartTransferTable(db);
        await _createAccountSnapshots(db);
        await _createReservationDetails(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createCommercialTables(db);
        if (oldVersion < 3) await _createDraftCartTable(db);
        if (oldVersion < 4) await _createCartTransferTable(db);
        if (oldVersion < 5) await _createAccountSnapshots(db);
        if (oldVersion < 6) await _createReservationDetails(db);
      },
    );
  }

  // Schema v2; do not delete existing v1 pending operations on upgrade.
  static Future<void> _createCommercialTables(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS offline_branches (tenant_id INTEGER NOT NULL, branch_id INTEGER NOT NULL, user_id INTEGER NOT NULL, name TEXT NOT NULL, address TEXT, synced_at TEXT NOT NULL, PRIMARY KEY(tenant_id,branch_id,user_id))''');
    await db.execute('''CREATE TABLE IF NOT EXISTS offline_products (tenant_id INTEGER NOT NULL, branch_id INTEGER NOT NULL, user_id INTEGER NOT NULL, product_id INTEGER NOT NULL, code TEXT NOT NULL, name TEXT NOT NULL, brand TEXT, category_id INTEGER, cover_image_url TEXT, synced_at TEXT NOT NULL, PRIMARY KEY(tenant_id,branch_id,user_id,product_id))''');
    await db.execute('''CREATE TABLE IF NOT EXISTS offline_variants (tenant_id INTEGER NOT NULL,branch_id INTEGER NOT NULL,user_id INTEGER NOT NULL,variant_id INTEGER NOT NULL,product_id INTEGER NOT NULL,sku TEXT NOT NULL,size_name TEXT,color_name TEXT,image_url TEXT,unit_price_cents INTEGER NOT NULL CHECK(unit_price_cents>=0),known_available INTEGER NOT NULL CHECK(known_available>=0),synced_at TEXT NOT NULL,PRIMARY KEY(tenant_id,branch_id,user_id,variant_id),FOREIGN KEY(tenant_id,branch_id,user_id,product_id) REFERENCES offline_products(tenant_id,branch_id,user_id,product_id))''');
    await db.execute('''CREATE TABLE IF NOT EXISTS offline_customers (tenant_id INTEGER NOT NULL,branch_id INTEGER NOT NULL,user_id INTEGER NOT NULL,customer_id INTEGER NOT NULL,first_name TEXT NOT NULL,last_name TEXT,email TEXT,synced_at TEXT NOT NULL,PRIMARY KEY(tenant_id,branch_id,user_id,customer_id))''');
    await db.execute('''CREATE TABLE IF NOT EXISTS offline_transactions (id TEXT NOT NULL PRIMARY KEY,tenant_id INTEGER NOT NULL,branch_id INTEGER NOT NULL,user_id INTEGER NOT NULL,transaction_type TEXT NOT NULL CHECK(transaction_type IN ('SALE_CREATE','RESERVATION_CREATE')),customer_id INTEGER,total_cents INTEGER NOT NULL DEFAULT 0 CHECK(total_cents>=0),payment_method TEXT,created_at TEXT NOT NULL,FOREIGN KEY(id) REFERENCES offline_operations(id) ON DELETE RESTRICT)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS offline_transaction_items (id INTEGER PRIMARY KEY AUTOINCREMENT,transaction_id TEXT NOT NULL,variant_id INTEGER NOT NULL,quantity INTEGER NOT NULL CHECK(quantity>0),unit_price_cents INTEGER NOT NULL CHECK(unit_price_cents>=0),FOREIGN KEY(transaction_id) REFERENCES offline_transactions(id) ON DELETE CASCADE,UNIQUE(transaction_id,variant_id))''');
    await db.execute('''CREATE INDEX IF NOT EXISTS idx_offline_variants_product ON offline_variants(tenant_id,branch_id,user_id,product_id)''');
    await db.execute('''CREATE INDEX IF NOT EXISTS idx_offline_transactions_scope ON offline_transactions(tenant_id,branch_id,user_id,created_at)''');
  }

  static Future<void> _createDraftCartTable(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS offline_cart_drafts (
      tenant_id INTEGER NOT NULL,
      branch_id INTEGER NOT NULL,
      user_id INTEGER NOT NULL,
      variant_id INTEGER NOT NULL,
      product_id INTEGER NOT NULL,
      product_name TEXT NOT NULL,
      variant_label TEXT NOT NULL,
      unit_price_cents INTEGER NOT NULL CHECK(unit_price_cents >= 0),
      quantity INTEGER NOT NULL CHECK(quantity > 0),
      updated_at TEXT NOT NULL,
      PRIMARY KEY(tenant_id, branch_id, user_id, variant_id)
    )''');
  }

  // Journal durable para evitar reenvíos automáticos ambiguos de POST/PATCH.
  // Hasta contar con idempotencia del backend, REVIEW requiere intervención.
  static Future<void> _createCartTransferTable(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS offline_cart_transfers (
      tenant_id INTEGER NOT NULL,
      branch_id INTEGER NOT NULL,
      user_id INTEGER NOT NULL,
      variant_id INTEGER NOT NULL,
      expected_quantity INTEGER NOT NULL,
      target_quantity INTEGER NOT NULL,
      remote_item_id INTEGER,
      status TEXT NOT NULL DEFAULT 'REVIEW',
      started_at TEXT NOT NULL,
      last_error TEXT,
      PRIMARY KEY (tenant_id, branch_id, user_id, variant_id)
    )''');
  }

  // Copias de lectura; NO son acciones pendientes y nunca se reenvían.
  static Future<void> _createAccountSnapshots(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS offline_cart_snapshots (
      tenant_id INTEGER NOT NULL, branch_id INTEGER NOT NULL,
      user_id INTEGER NOT NULL, data_json TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      PRIMARY KEY (tenant_id, branch_id, user_id)
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS offline_reservation_snapshots (
      tenant_id INTEGER NOT NULL, user_id INTEGER NOT NULL,
      query_key TEXT NOT NULL, data_json TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      PRIMARY KEY (tenant_id, user_id, query_key)
    )''');
  }

  static Future<void> _createReservationDetails(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS offline_reservation_display (
      operation_id TEXT PRIMARY KEY NOT NULL,
      tenant_id INTEGER NOT NULL, branch_id INTEGER NOT NULL,
      user_id INTEGER NOT NULL, display_json TEXT NOT NULL,
      FOREIGN KEY(operation_id) REFERENCES offline_operations(id) ON DELETE CASCADE
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS offline_reservation_detail_snapshots (
      tenant_id INTEGER NOT NULL, user_id INTEGER NOT NULL,
      reservation_id INTEGER NOT NULL, data_json TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      PRIMARY KEY(tenant_id,user_id,reservation_id)
    )''');
  }

  /// `cacheKey` identifica una consulta concreta (filtros y página incluidos).
  /// Guardar solo datos de catálogo públicos obtenidos de un API válido.
  Future<void> putCatalogSnapshot({
    required OfflineScope scope,
    required String cacheKey,
    required Map<String, dynamic> data,
  }) async {
    if (cacheKey.trim().isEmpty) throw ArgumentError('cacheKey obligatorio');
    final db = await database;
    await db.insert('catalog_snapshots', {
      'tenant_id': scope.tenantId,
      'branch_id': scope.branchId,
      'user_id': scope.userId,
      'cache_key': cacheKey,
      'data_json': jsonEncode(data),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getCatalogSnapshot({
    required OfflineScope scope,
    required String cacheKey,
  }) async {
    final db = await database;
    final rows = await db.query(
      'catalog_snapshots',
      columns: ['data_json'],
      where:
          'tenant_id = ? AND branch_id = ? AND user_id = ? AND cache_key = ?',
      whereArgs: [...scope.args, cacheKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(
      jsonDecode(rows.first['data_json']! as String) as Map,
    );
  }

  /// El ID debe generarse UNA sola vez (UUID v4) en la capa de negocio.
  /// Nunca cambiarlo al reintentar. No reemplaza una operación existente.
  Future<void> enqueue({
    required OfflineScope scope,
    required String operationId,
    required String operationType,
    required Map<String, dynamic> payload,
  }) async {
    if (operationId.trim().isEmpty) throw ArgumentError('ID obligatorio');
    if (!_operationTypes.contains(operationType)) {
      throw ArgumentError.value(operationType, 'operationType', 'No admitido');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final db = await database;
    await db.insert('offline_operations', {
      'id': operationId,
      'tenant_id': scope.tenantId,
      'branch_id': scope.branchId,
      'user_id': scope.userId,
      'operation_type': operationType,
      'payload_json': jsonEncode(payload),
      'status': pending,
      'attempts': 0,
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<List<OfflineOperation>> getOperations({
    required OfflineScope scope,
    String? status,
  }) async {
    if (status != null && !_statuses.contains(status)) {
      throw ArgumentError.value(status, 'status', 'No admitido');
    }
    final db = await database;
    final rows = await db.query(
      'offline_operations',
      where:
          'tenant_id = ? AND branch_id = ? AND user_id = ?${status == null ? '' : ' AND status = ?'}',
      whereArgs: [...scope.args, if (status != null) status],
      orderBy: 'created_at ASC',
    );
    return rows.map(OfflineOperation.fromRow).toList(growable: false);
  }

  /// Descubre las sucursales con operaciones locales del usuario/empresa.
  /// No consulta la API y no mezcla datos de otros usuarios o tenants.
  Future<List<int>> pendingReservationBranchIds({
    required int tenantId,
    required int userId,
  }) async {
    if (tenantId <= 0 || userId <= 0) return const [];
    final db = await database;
    final rows = await db.rawQuery("""
      SELECT DISTINCT branch_id FROM offline_operations
      WHERE tenant_id = ? AND user_id = ?
        AND operation_type = 'RESERVATION_CREATE'
        AND status = ?
      ORDER BY branch_id
    """, [tenantId, userId, pending]);
    return rows.map((row) => (row['branch_id'] as num).toInt()).toList();
  }

  /// Solo actualiza operaciones del mismo contexto. `attempted` representa
  /// un envío real; no incrementarlo cuando simplemente falta conexión.
  Future<bool> updateOperation({
    required OfflineScope scope,
    required String operationId,
    required String status,
    bool attempted = false,
    String? error,
  }) async {
    if (!_statuses.contains(status)) throw ArgumentError.value(status);
    final db = await database;
    final count = await db.rawUpdate(
      '''
      UPDATE offline_operations SET
        status = ?,
        attempts = attempts + ?,
        last_error = ?,
        updated_at = ?
      WHERE id = ? AND tenant_id = ? AND branch_id = ? AND user_id = ?
    ''',
      [
        status,
        attempted ? 1 : 0,
        error,
        DateTime.now().toUtc().toIso8601String(),
        operationId,
        ...scope.args,
      ],
    );
    return count == 1;
  }

  Future<bool> deleteOperation({
    required OfflineScope scope,
    required String operationId,
  }) async {
    final db = await database;
    return await db.delete(
          'offline_operations',
          where: 'id = ? AND tenant_id = ? AND branch_id = ? AND user_id = ?',
          whereArgs: [operationId, ...scope.args],
        ) ==
        1;
  }

  /// Para dispositivos compartidos: permite borrar SOLO datos de un contexto.
  /// No se invoca automáticamente al cerrar sesión: podría perder pendientes.
  Future<void> clearScope(OfflineScope scope) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final table in ['catalog_snapshots', 'offline_transaction_items', 'offline_transactions', 'offline_variants', 'offline_products', 'offline_customers', 'offline_branches', 'offline_operations']) {
        if (table == 'offline_transaction_items') {
          await txn.delete(table,
            where: 'transaction_id IN (SELECT id FROM offline_transactions WHERE tenant_id = ? AND branch_id = ? AND user_id = ?)',
            whereArgs: scope.args);
        } else {
          await txn.delete(table,
            where: 'tenant_id = ? AND branch_id = ? AND user_id = ?',
            whereArgs: scope.args);
        }
      }
    });
  }

  Future<void> close() async {
    final db = _database;
    _database = null;
    if (db != null && db.isOpen) await db.close();
  }
}
