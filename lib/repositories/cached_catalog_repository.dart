import 'package:flutter/foundation.dart';

import '../core/network/app_error_message.dart';
import '../core/offline/offline_database.dart';
import '../models/catalog_models.dart';
import '../services/catalog_service.dart';
import '../services/product_service.dart';
import 'offline_catalog_repository.dart';
import 'public_catalog_cache_scope.dart';

class CatalogLoadResult {
  const CatalogLoadResult(this.page, {required this.fromCache});
  final CatalogPageResponse page;
  final bool fromCache;
}

/// API primero: no confía en un estado de conectividad que puede ser antiguo.
/// Si el transporte falla, intenta recuperar exactamente la misma consulta
/// desde SQLite. Nunca devuelve datos de otro tenant ni mezcla filtros.
class CachedCatalogRepository {
  CachedCatalogRepository({OfflineCatalogRepository? local})
      : _local = local ?? OfflineCatalogRepository();

  final OfflineCatalogRepository _local;

  Future<CatalogLoadResult> load({
    int page = 1,
    int pageSize = 20,
    int? branchId,
    String? search,
    CatalogFilterState filters = const CatalogFilterState(),
  }) async {
    final endpoint = await CatalogService.buildCatalogEndpoint(
      page: page,
      pageSize: pageSize,
      branchId: branchId,
      search: search,
      filters: filters,
    );
    final requestUri = Uri.parse(endpoint);
    final scope = await PublicCatalogCacheScope.resolve(branchId: branchId);
    debugPrint('[FS-CATALOGO] Consultando API: $endpoint');

    Future<CatalogLoadResult> readLocal() async {
      debugPrint('[FS-SQLITE] Buscando catálogo tenant=${scope.tenantId} '
          'sucursal=${scope.branchId} clave=$endpoint');
      final local = await _local.readCatalog(scope: scope, requestUri: requestUri);
      if (local == null) {
        debugPrint('[FS-SQLITE] CACHE MISS: no existe esta página y filtros');
        throw StateError('CATALOG_NOT_CACHED');
      }
      debugPrint('[FS-SQLITE] CACHE HIT: ${local.items.length} productos '
          '(total=${local.total})');
      return CatalogLoadResult(local, fromCache: true);
    }

    try {
      final api = await CatalogService.getCatalog(
        page: page,
        pageSize: pageSize,
        branchId: branchId,
        search: search,
        filters: filters,
        onSuccessfulResponse: (uri, json) async {
          // Si SQLite falla se informa en consola, pero NO se rompe el catálogo.
          try {
            await _local.saveCatalog(
              scope: scope,
              requestUri: uri,
              responseJson: json,
            );
            debugPrint('[FS-SQLITE] GUARDADO OK: ${apiItemCount(json)} '
                'productos tenant=${scope.tenantId} '
                'sucursal=${scope.branchId} uri=$uri');
          } catch (error, stack) {
            debugPrint('[FS-SQLITE] ERROR GUARDANDO: $error');
            debugPrintStack(stackTrace: stack);
          }
        },
      );
      // Descarga también las variantes y el detalle de CADA producto de esta
      // página. Un catálogo en caché sin detalle no sirve para reservar offline.
      // La descarga es limitada a 4 peticiones concurrentes y nunca bloquea
      // el catálogo en caso de que falle alguno de los productos.
      final productIds = api.items.map((p) => p.id).where((id) => id > 0).toSet().toList();
      var downloaded = 0;
      for (var start = 0; start < productIds.length; start += 4) {
        final batch = productIds.skip(start).take(4);
        final results = await Future.wait(batch.map((id) async {
          try {
            await ProductService.getProductDetailWithSource(id, branchId: branchId)
                .timeout(const Duration(seconds: 6));
            return true;
          } catch (error) {
            debugPrint('[FS-DETALLE] No se pudo descargar producto $id: $error');
            return false;
          }
        }));
        downloaded += results.where((ok) => ok).length;
      }
      debugPrint('[FS-DETALLE] Descargados $downloaded/${productIds.length} detalles para uso offline');
      debugPrint('[FS-CATALOGO] API OK: ${api.items.length} productos '
          'total=${api.total} page=${api.page}');
      return CatalogLoadResult(api, fromCache: false);
    } on AppNetworkException catch (error) {
      debugPrint('[FS-CATALOGO] API SIN CONEXIÓN: $error');
      return readLocal();
    }
  }

  static int apiItemCount(Map<String, dynamic> data) =>
      data['items'] is List ? (data['items'] as List).length : 0;
}
