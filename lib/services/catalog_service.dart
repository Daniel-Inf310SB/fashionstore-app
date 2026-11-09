import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../models/catalog_models.dart';
import '../models/product.dart';
import 'api_service.dart';
import 'tenant_context_service.dart';

class CatalogService {
  static Future<CatalogPageResponse> getCatalog({
    Future<void> Function(Uri, Map<String, dynamic>)? onSuccessfulResponse,
    int page = 1,
    int pageSize = 20,
    int? branchId,
    String? search,
    CatalogFilterState filters = const CatalogFilterState(),
  }) async {
    final endpoint = await buildCatalogEndpoint(
      page: page, pageSize: pageSize, branchId: branchId,
      search: search, filters: filters,
    );
    final response = await ApiService.get(endpoint, requiresAuth: true);

    final decoded = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(_detail(decoded, 'No se pudo cargar el catálogo'));
    }

    if (decoded is! Map) {
      throw Exception('Respuesta inválida del catálogo');
    }

    final json = Map<String, dynamic>.from(decoded);
    final result = CatalogPageResponse.fromJson(json);
    debugPrint('[FS-CATALOGO] HTTP ${response.statusCode}: ' 'items=${result.items.length} total=${result.total} endpoint=$endpoint');
    if (onSuccessfulResponse != null) {
      // La caché nunca debe impedir que el catálogo online funcione.
      try {
        await onSuccessfulResponse(Uri.parse(endpoint), json);
      } catch (error, stack) {
        debugPrint('[FS-SQLITE] ERROR en callback caché: $error');
        debugPrintStack(stackTrace: stack);
      }
    }
    return result;
  }

  /// La misma URL se utiliza al guardar y consultar SQLite.
  static Future<String> buildCatalogEndpoint({
    int page = 1,
    int pageSize = 20,
    int? branchId,
    String? search,
    CatalogFilterState filters = const CatalogFilterState(),
  }) async {
    final query = <String, String>{
      'page': '$page',
      'page_size': '$pageSize',
      'sort_by': filters.sortBy,
      'sort_order': filters.sortOrder,
      if (branchId != null) 'branch_id': '$branchId',
      if (search != null && search.trim().isNotEmpty)
        'search': search.trim(),
      if (filters.audience != null && filters.audience!.trim().isNotEmpty)
        'audience': filters.audience!.trim(),
      if (filters.category != null && filters.category!.trim().isNotEmpty)
        'category': filters.category!.trim(),
      if (filters.minPrice != null) 'min_price': '${filters.minPrice}',
      if (filters.maxPrice != null) 'max_price': '${filters.maxPrice}',
      if (filters.onlyPromotions) 'promotion': 'true',
      if (filters.promotionId != null)
        'promotion_id': '${filters.promotionId}',
      if (filters.collectionId != null)
        'collection_id': '${filters.collectionId}',
      if (filters.seasonId != null)
        'season_id': '${filters.seasonId}',
      if (filters.inStock) 'in_stock': 'true',
    };

    final endpoint = Uri(
      path: '/store/catalog',
      queryParameters: query,
    ).toString();

    return TenantContextService.withTenant(endpoint);
  }

  static Future<CatalogFilterMetadata> loadFilterMetadata() async {
    final results = await Future.wait([
      _getMerchandising('/store/collections?page=1&page_size=100'),
      _getMerchandising('/store/seasons?page=1&page_size=100'),
      _getMerchandising('/store/promotions?page=1&page_size=100'),
      _getCatalogTags(),
    ]);

    final tags = results[3] as _CatalogTags;

    return CatalogFilterMetadata(
      categories: tags.categories,
      audiences: tags.audiences,
      collections:
          results[0] as List<CatalogMerchandisingOption>,
      seasons:
          results[1] as List<CatalogMerchandisingOption>,
      promotions:
          results[2] as List<CatalogMerchandisingOption>,
    );
  }

  static Future<List<CatalogMerchandisingOption>> _getMerchandising(
    String endpoint,
  ) async {
    try {
      final scopedEndpoint = await TenantContextService.withTenant(endpoint);
    final response = await ApiService.get(scopedEndpoint, requiresAuth: true);

      if (response.statusCode != 200) {
        return const [];
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map || decoded['items'] is! List) {
        return const [];
      }

      return (decoded['items'] as List)
          .whereType<Map>()
          .map(
            (item) => CatalogMerchandisingOption.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .where(
            (item) => item.id > 0 && item.name.trim().isNotEmpty,
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<_CatalogTags> _getCatalogTags() async {
    try {
      final endpoint = await TenantContextService.withTenant(
        '/store/catalog?page=1&page_size=100&sort_by=name&sort_order=asc',
      );
      final response = await ApiService.get(endpoint, requiresAuth: true);

      if (response.statusCode != 200) {
        return const _CatalogTags();
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map || decoded['items'] is! List) {
        return const _CatalogTags();
      }

      final products = (decoded['items'] as List)
          .whereType<Map>()
          .map(
            (item) => Product.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();

      final categories = products
          .map((item) => item.category.name.trim())
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      final audiences = products
          .map((item) => item.audience.name.trim())
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      return _CatalogTags(
        categories: categories,
        audiences: audiences,
      );
    } catch (_) {
      return const _CatalogTags();
    }
  }

  static String _detail(
    dynamic decoded,
    String fallback,
  ) {
    if (decoded is Map && decoded['detail'] != null) {
      return decoded['detail'].toString();
    }

    return fallback;
  }
}

class _CatalogTags {
  const _CatalogTags({
    this.categories = const [],
    this.audiences = const [],
  });

  final List<String> categories;
  final List<String> audiences;
}
