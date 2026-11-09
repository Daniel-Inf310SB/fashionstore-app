import 'package:flutter/foundation.dart';

import '../core/offline/offline_database.dart';
import '../services/tenant_context_service.dart';
import 'public_endpoint_cache.dart';

import '../models/catalog_models.dart';
import '../services/catalog_service.dart';
import '../services/product_service.dart';
import 'offline_catalog_repository.dart';
import 'public_catalog_cache_scope.dart';

/// Descarga explícita del catálogo sin alterar la paginación visual.
/// Guarda páginas con la MISMA clave que usa CachedCatalogRepository (20/página)
/// y detalles mediante el mismo caché de ProductService.
class OfflineCatalogDownloadProgress {
  const OfflineCatalogDownloadProgress({
    required this.pages,
    required this.totalPages,
    required this.products,
    required this.totalProducts,
    required this.details,
    required this.failedDetails,
  });

  final int pages;
  final int totalPages;
  final int products;
  final int totalProducts;
  final int details;
  final int failedDetails;
}

class OfflineCatalogDownloadResult {
  const OfflineCatalogDownloadResult({
    required this.progress,
    required this.completed,
    required this.cancelled,
    this.error,
  });

  final OfflineCatalogDownloadProgress progress;
  final bool completed;
  final bool cancelled;
  final String? error;
}

class OfflineCatalogDownloadService {
  OfflineCatalogDownloadService({OfflineCatalogRepository? local})
      : _local = local ?? OfflineCatalogRepository();

  final OfflineCatalogRepository _local;
  static const int _pageSize = 20;
  static const int _maxPages = 1000;
  static const String _statusKey = 'offline:catalog:complete:v1';

  /// El indicador solo significa descarga íntegra VERIFICADA en SQLite,
  /// no que los precios o existencias sigan vigentes en el servidor.
  Future<OfflineCatalogDownloadProgress?> completedDownload({int? branchId}) async {
    final scope = await PublicCatalogCacheScope.resolve(branchId: branchId);
    // Verificar siempre los datos reales. Una descarga interrumpida posterior
    // no invalida un catálogo que ya estaba íntegramente almacenado.
    // El marcador por sí solo nunca se considera prueba de completitud.
    final firstUrl = await CatalogService.buildCatalogEndpoint(
      page: 1, pageSize: _pageSize, branchId: branchId,
    );
    final first = await _local.readCatalog(
      scope: scope, requestUri: Uri.parse(firstUrl),
    );
    if (first == null || first.totalPages <= 0 ||
        first.totalPages > _maxPages) return null;
    final ids = <int>{};
    for (var page = 1; page <= first.totalPages; page++) {
      final endpoint = await CatalogService.buildCatalogEndpoint(
        page: page, pageSize: _pageSize, branchId: branchId,
      );
      final snapshot = await _local.readCatalog(
        scope: scope, requestUri: Uri.parse(endpoint),
      );
      if (snapshot == null || snapshot.total != first.total ||
          snapshot.totalPages != first.totalPages) return null;
      ids.addAll(snapshot.items.map((p) => p.id).where((id) => id > 0));
    }
    if (ids.length != first.total) return null;
    for (final id in ids) {
      final endpoint = await TenantContextService.withTenant(Uri(
        path: '/store/products/$id',
        queryParameters: {if (branchId != null) 'branch_id': '$branchId'},
      ).toString());
      final detail = await const PublicEndpointCache().read(
        endpoint: endpoint, branchId: branchId,
      );
      if (detail == null) return null;
    }
    return OfflineCatalogDownloadProgress(
      pages: first.totalPages, totalPages: first.totalPages,
      products: ids.length, totalProducts: first.total,
      details: ids.length, failedDetails: 0,
    );
  }

  Future<OfflineCatalogDownloadResult> download({
    required int? branchId,
    required void Function(OfflineCatalogDownloadProgress) onProgress,
    required bool Function() isCancelled,
  }) async {
    final initialScope = await PublicCatalogCacheScope.resolve(branchId: branchId);
    // Nunca conservar un indicador de completado durante una nueva descarga.
    await OfflineDatabase.instance.putCatalogSnapshot(
      scope: initialScope, cacheKey: _statusKey,
      data: {'completed': false},
    );
    var pages = 0;
    var totalPages = 0;
    var products = 0;
    var totalProducts = 0;
    var details = 0;
    var cancelled = false;
    final successfulIds = <int>{};
    String? error;
    final allIds = <int>{};
    final failedIds = <int>{};

    OfflineCatalogDownloadProgress progress() => OfflineCatalogDownloadProgress(
          pages: pages,
          totalPages: totalPages,
          products: products,
          totalProducts: totalProducts,
          details: details,
          failedDetails: failedIds.length,
        );

    Future<void> checkScope() async {
      final scope = await PublicCatalogCacheScope.resolve(branchId: branchId);
      if (scope.tenantId != initialScope.tenantId ||
          scope.branchId != initialScope.branchId) {
        throw StateError('Cambió la empresa o sucursal. Reinicia la descarga.');
      }
    }

    // Una página a la vez: sin grandes peticiones ni acumulación de respuestas.
    try {
      for (var page = 1; page <= _maxPages; page++) {
        if (isCancelled()) { cancelled = true; break; }
        await checkScope();
        Object? saveFailure;
        final data = await CatalogService.getCatalog(
          page: page,
          pageSize: _pageSize,
          branchId: branchId,
          onSuccessfulResponse: (uri, json) async {
            try {
              await _local.saveCatalog(
                scope: initialScope,
                requestUri: uri,
                responseJson: json,
              );
            } catch (e) {
              saveFailure = e;
              rethrow;
            }
          },
        );
        if (saveFailure != null) {
          throw StateError('No se pudo guardar una página en SQLite: $saveFailure');
        }
        pages++;
        totalPages = data.totalPages;
        totalProducts = data.total;
        products += data.items.length;
        allIds.addAll(data.items.map((e) => e.id).where((id) => id > 0));
        onProgress(progress());

        // Detalles y variantes: máximo 4 descargas simultáneas.
        final ids = data.items.map((e) => e.id).where((id) => id > 0).toSet().toList();
        for (var i = 0; i < ids.length; i += 4) {
          if (isCancelled()) { cancelled = true; break; }
          await checkScope();
          final batch = ids.skip(i).take(4);
          await Future.wait(batch.map((id) async {
            try {
              final result = await ProductService.getProductDetailWithSource(
                id, branchId: branchId,
              ).timeout(const Duration(seconds: 12));
              // Una respuesta antigua en caché NO cuenta como descarga nueva.
              if (result.fromCache) throw StateError('Detalle no actualizado');
              if (successfulIds.add(id)) details++;
              failedIds.remove(id);
            } catch (e) {
              failedIds.add(id);
              debugPrint('[FS-DESCARGA] Detalle $id falló: $e');
            }
          }));
          onProgress(progress());
        }
        if (cancelled || data.items.isEmpty || page >= totalPages) break;
      }

      // Segunda oportunidad para fallos puntuales; jamás bloquea los demás.
      if (!cancelled && failedIds.isNotEmpty) {
        final retry = failedIds.toList();
        for (var i = 0; i < retry.length; i += 4) {
          if (isCancelled()) { cancelled = true; break; }
          await checkScope();
          await Future.wait(retry.skip(i).take(4).map((id) async {
            try {
              final result = await ProductService.getProductDetailWithSource(
                id, branchId: branchId,
              ).timeout(const Duration(seconds: 12));
              if (result.fromCache) throw StateError('Detalle no actualizado');
              if (successfulIds.add(id)) details++;
              failedIds.remove(id);
            } catch (e) {
              debugPrint('[FS-DESCARGA] Reintento detalle $id: $e');
            }
          }));
          onProgress(progress());
        }
      }
    } catch (e) {
      error = e.toString();
      debugPrint('[FS-DESCARGA] Descarga incompleta: $e');
    }
    if (!cancelled && error == null && pages >= _maxPages &&
        pages < totalPages) {
      error = 'El catálogo supera el límite de seguridad de $_maxPages páginas.';
    }
    final finished = !cancelled && error == null &&
        pages > 0 && pages >= totalPages &&
        failedIds.isEmpty && details >= allIds.length;
    if (finished) {
      await OfflineDatabase.instance.putCatalogSnapshot(
        scope: initialScope, cacheKey: _statusKey,
        data: {
          'completed': true, 'pages': pages, 'products': totalProducts,
          'details': details, 'downloaded_at': DateTime.now().toUtc().toIso8601String(),
        },
      );
    }
    var verified = false;
    if (finished) {
      try {
        verified = await completedDownload(branchId: branchId) != null;
      } catch (e) {
        debugPrint('[FS-DESCARGA] No se pudo validar caché completa: $e');
      }
    }
    return OfflineCatalogDownloadResult(
      progress: progress(),
      completed: verified,
      cancelled: cancelled,
      error: error,
    );
  }
}
