import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../models/branch.dart';
import '../core/network/app_error_message.dart';
import '../core/offline/offline_database.dart';
import '../repositories/public_catalog_cache_scope.dart';
import 'api_service.dart';
import 'tenant_context_service.dart';

class BranchService {
  static Future<List<StoreBranch>> getStoreBranches() async {
    final endpoint = await TenantContextService.withTenant(
      '/store/branches?page=1&page_size=100',
    );
    final scope = await PublicCatalogCacheScope.resolve();
    try {
      debugPrint('[FS-SUCURSALES] Consultando API: $endpoint');
      final response = await ApiService.get(endpoint, requiresAuth: true);
      dynamic data;
      try {
        data = jsonDecode(response.body);
      } catch (_) {
        data = null;
      }
      if (response.statusCode != 200) {
        debugPrint('[FS-SUCURSALES] HTTP ${response.statusCode}');
        throw Exception(
          data is Map && data['detail'] != null
              ? data['detail'].toString()
              : 'No se pudieron cargar las sucursales.',
        );
      }
      final rawItems = data is Map ? data['items'] : data;
      if (rawItems is! List) {
        throw const FormatException('Respuesta de sucursales inválida');
      }
      final branches = _parseBranches(rawItems);
      debugPrint('[FS-SUCURSALES] API OK: ${branches.length} sucursales');
      try {
        await OfflineDatabase.instance.putCatalogSnapshot(
          scope: scope,
          cacheKey: 'public:branches:v1',
          data: {'items': branches.map((e) => e.toJson()).toList()},
        );
        debugPrint('[FS-SQLITE] Sucursales guardadas: ${branches.length}');
      } catch (error, stack) {
        debugPrint('[FS-SQLITE] ERROR guardando sucursales: $error');
        debugPrintStack(stackTrace: stack);
      }
      return branches;
    } on AppNetworkException catch (error) {
      debugPrint('[FS-SUCURSALES] API no accesible: $error');
      final snapshot = await OfflineDatabase.instance.getCatalogSnapshot(
        scope: scope,
        cacheKey: 'public:branches:v1',
      );
      final raw = snapshot?['items'];
      if (raw is List) {
        final branches = _parseBranches(raw);
        debugPrint('[FS-SQLITE] Sucursales recuperadas: ${branches.length}');
        return branches;
      }
      debugPrint('[FS-SQLITE] Sin caché de sucursales');
      rethrow;
    }
  }

  static List<StoreBranch> _parseBranches(List raw) {
    final branches = raw.whereType<Map>().map((item) =>
        StoreBranch.fromJson(Map<String, dynamic>.from(item)))
        .where((branch) => branch.isActive).toList();
    branches.sort((a, b) {
      final city = a.city.name.compareTo(b.city.name);
      return city != 0 ? city : a.name.compareTo(b.name);
    });
    return branches;
  }

}
