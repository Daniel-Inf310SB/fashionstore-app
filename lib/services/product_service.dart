import 'dart:convert';

import '../models/product_detail.dart';
import '../repositories/public_endpoint_cache.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'tenant_context_service.dart';

class ProductDetailLoadResult {
  const ProductDetailLoadResult(this.detail, {required this.fromCache});
  final ProductDetail detail;
  final bool fromCache;
}

class ProductService {
  static Future<ProductDetail> getProductDetail(int productId, {int? branchId}) async =>
      (await getProductDetailWithSource(productId, branchId: branchId)).detail;

  static Future<ProductDetailLoadResult> getProductDetailWithSource(
    int productId, {int? branchId,
  }) async {
    final endpoint = Uri(
      path: '/store/products/$productId',
      queryParameters: {if (branchId != null) 'branch_id': '$branchId'},
    ).toString();
    final scopedEndpoint = await TenantContextService.withTenant(endpoint);
    const cache = PublicEndpointCache();
    Map<String, dynamic> json;
    var fromCache = false;
    try {
      final response = await ApiService.get(scopedEndpoint, requiresAuth: true);
      final data = _decode(response.body);
      if (response.statusCode != 200) {
        throw Exception(_detail(data, 'No se pudo cargar el producto.'));
      }
      if (data is! Map) throw const FormatException('Respuesta inválida del producto');
      json = Map<String, dynamic>.from(data);
      ProductDetail.fromJson(json); // Valida ANTES de guardar.
      try {
        await cache.save(endpoint: scopedEndpoint, branchId: branchId, json: json);
      } catch (error) {
        debugPrint('[FS-PRODUCTO] ERROR GUARDANDO CACHE: $error');
      }
    } catch (error) {
      if (!PublicEndpointCache.isOfflineFailure(error)) rethrow;
      final local = await cache.read(endpoint: scopedEndpoint, branchId: branchId);
      if (local == null) {
        debugPrint('[FS-DETALLE] CACHE MISS producto=$productId branch=$branchId');
        throw StateError('Este detalle todavía no fue descargado. Conéctate, abre el catálogo y deja finalizar la descarga de detalles antes de trabajar sin conexión.');
      }
      json = local;
      fromCache = true;
    }
    return ProductDetailLoadResult(ProductDetail.fromJson(json), fromCache: fromCache);
  }

  static dynamic _decode(String body) {
    if (body.trim().isEmpty) return null;

    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  static String _detail(dynamic data, String fallback) {
    if (data is Map && data['detail'] != null) {
      return data['detail'].toString();
    }

    return fallback;
  }
}
