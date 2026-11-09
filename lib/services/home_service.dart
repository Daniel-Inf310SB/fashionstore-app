import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/home_models.dart';
import '../models/product.dart';
import '../repositories/public_endpoint_cache.dart';
import 'api_service.dart';
import 'product_service.dart';
import 'tenant_context_service.dart';

class HomeLoadResult {
  const HomeLoadResult(this.data, {required this.fromCache});
  final HomeData data;
  final bool fromCache;
}

class HomeService {
  static Future<HomeData> loadHome({int? branchId}) async =>
      (await loadHomeWithSource(branchId: branchId)).data;

  static Future<HomeLoadResult> loadHomeWithSource({int? branchId}) async {
    if (branchId == null) {
      throw StateError('Selecciona una sucursal para ver el inicio.');
    }
    final endpoint = await TenantContextService.withTenant(
      Uri(path: '/store/home', queryParameters: {'branch_id': '$branchId'}).toString(),
    );
    const cache = PublicEndpointCache();
    Map<String, dynamic> payload;
    var fromCache = false;
    try {
      final response = await ApiService.get(endpoint, requiresAuth: true)
          .timeout(const Duration(seconds: 18));
      if (response.statusCode != 200) {
        String message = 'No se pudo cargar el inicio (${response.statusCode}).';
        try {
          final body = jsonDecode(response.body);
          if (body is Map && body['detail'] != null) message = body['detail'].toString();
        } catch (_) {}
        throw StateError(message);
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['new_arrivals'] is! List ||
          decoded['categories'] is! List || decoded['banners'] is! List) {
        throw const FormatException('El endpoint /store/home devolvió datos inválidos.');
      }
      payload = Map<String, dynamic>.from(decoded);
      // No bloquear una respuesta online por fallos en el caché.
      try { await cache.save(endpoint: endpoint, branchId: branchId, json: payload); }
      catch (error) { debugPrint('[FS-HOME] Caché: $error'); }
    } catch (error) {
      if (!PublicEndpointCache.isOfflineFailure(error) &&
          error is! TimeoutException) rethrow;
      final stored = await cache.read(endpoint: endpoint, branchId: branchId);
      if (stored == null) rethrow;
      payload = stored;
      fromCache = true;
    }
    final data = HomeData.fromStoreJson(payload);
    if (!fromCache) {
      // No sobrecargar el servidor: sólo precargamos detalles de novedades.
      unawaited(_cacheDetails(data.featuredProducts.take(6).toList(), branchId));
    }
    return HomeLoadResult(data, fromCache: fromCache);
  }

  static Future<void> _cacheDetails(List<Product> products, int branchId) async {
    for (var i = 0; i < products.length; i += 3) {
      await Future.wait(products.skip(i).take(3).map((product) async {
        if (product.id <= 0) return;
        try {
          await ProductService.getProductDetailWithSource(
            product.id, branchId: branchId,
          ).timeout(const Duration(seconds: 8));
        } catch (error) {
          debugPrint('[FS-HOME] No se pudo guardar detalle ${product.id}: $error');
        }
      }));
    }
  }
}
