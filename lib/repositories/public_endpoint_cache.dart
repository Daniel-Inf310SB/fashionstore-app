import 'package:flutter/foundation.dart';

import '../core/network/app_error_message.dart';
import '../core/offline/offline_database.dart';
import 'public_catalog_cache_scope.dart';

/// Solo para respuestas públicas por empresa/sucursal. Nunca usar para datos
/// privados (carrito, pedidos, reservas, identidad, pagos o tokens).
class PublicEndpointCache {
  const PublicEndpointCache();

  Future<Map<String, dynamic>?> read({
    required String endpoint,
    required int? branchId,
  }) async {
    final scope = await PublicCatalogCacheScope.resolve(branchId: branchId);
    final result = await OfflineDatabase.instance.getCatalogSnapshot(
      scope: scope, cacheKey: 'public:${_key(endpoint)}',
    );
    debugPrint('[FS-OFFLINE] ${result == null ? 'CACHE MISS' : 'CACHE HIT'} $endpoint');
    return result;
  }

  Future<void> save({
    required String endpoint,
    required int? branchId,
    required Map<String, dynamic> json,
  }) async {
    final scope = await PublicCatalogCacheScope.resolve(branchId: branchId);
    await OfflineDatabase.instance.putCatalogSnapshot(
      scope: scope, cacheKey: 'public:${_key(endpoint)}', data: json,
    );
    debugPrint('[FS-OFFLINE] GUARDADO OK $endpoint');
  }

  String _key(String endpoint) {
    final uri = Uri.parse(endpoint);
    final params = uri.queryParametersAll.entries.toList()
      ..sort((a,b) => a.key.compareTo(b.key));
    return Uri(path: uri.path, queryParameters: {
      for (final item in params) item.key: ([...item.value]..sort()).join(','),
    }).toString();
  }

  /// Solo si falló la red. HTTP 401/403 y fallos de formato NO habilitan caché.
  static bool isOfflineFailure(Object error) => error is AppNetworkException;
}
