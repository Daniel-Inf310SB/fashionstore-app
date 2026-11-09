import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../core/offline/offline_database.dart';
import '../services/offline_reservation_service.dart';

/// Copias de SOLO LECTURA de respuestas válidas del backend.
/// Nunca se usan como operaciones a sincronizar ni como stock confirmado.
class AccountSnapshotRepository {
  const AccountSnapshotRepository();

  Future<({int tenantId, int userId})> _identity() async {
    final prefs = await SharedPreferences.getInstance();
    final tenantId = prefs.getInt('auth_tenant_id');
    final userId = int.tryParse(prefs.getString('auth_user_id') ?? '');
    if (tenantId == null || tenantId <= 0 || userId == null || userId <= 0) {
      throw StateError('Debes iniciar sesión para consultar los datos guardados.');
    }
    return (tenantId: tenantId, userId: userId);
  }

  Future<void> saveCart(int branchId, Map<String, dynamic> data) async {
    final scope = await OfflineReservationService.requireScope(branchId);
    final db = await OfflineDatabase.instance.database;
    await db.insert('offline_cart_snapshots', {
      'tenant_id': scope.tenantId, 'branch_id': scope.branchId,
      'user_id': scope.userId, 'data_json': jsonEncode(data),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> readCart(int branchId) async {
    final scope = await OfflineReservationService.requireScope(branchId);
    final db = await OfflineDatabase.instance.database;
    final rows = await db.query('offline_cart_snapshots',
      columns: ['data_json'],
      where: 'tenant_id=? AND branch_id=? AND user_id=?',
      whereArgs: scope.args, limit: 1);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(jsonDecode(rows.first['data_json'] as String) as Map);
  }

  Future<void> saveReservationDetail(int reservationId, Map<String, dynamic> data) async {
    final id = await _identity();
    final db = await OfflineDatabase.instance.database;
    await db.insert('offline_reservation_detail_snapshots', {
      'tenant_id': id.tenantId, 'user_id': id.userId,
      'reservation_id': reservationId, 'data_json': jsonEncode(data),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> readReservationDetail(int reservationId) async {
    final id = await _identity();
    final db = await OfflineDatabase.instance.database;
    final rows = await db.query('offline_reservation_detail_snapshots',
      columns: ['data_json'], where: 'tenant_id=? AND user_id=? AND reservation_id=?',
      whereArgs: [id.tenantId, id.userId, reservationId], limit: 1);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(jsonDecode(rows.first['data_json'] as String) as Map);
  }

  Future<void> saveReservations(String queryKey, Map<String, dynamic> data) async {
    final identity = await _identity();
    final db = await OfflineDatabase.instance.database;
    await db.insert('offline_reservation_snapshots', {
      'tenant_id': identity.tenantId, 'user_id': identity.userId,
      'query_key': queryKey, 'data_json': jsonEncode(data),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> readReservations(String queryKey) async {
    final identity = await _identity();
    final db = await OfflineDatabase.instance.database;
    final rows = await db.query('offline_reservation_snapshots',
      columns: ['data_json'], where: 'tenant_id=? AND user_id=? AND query_key=?',
      whereArgs: [identity.tenantId, identity.userId, queryKey], limit: 1);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(jsonDecode(rows.first['data_json'] as String) as Map);
  }
}
