import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/errors/api_exception.dart';
import '../../models/availability_model.dart';
import '../../models/branch.dart';
import '../../models/product.dart';
import 'api_service.dart';

/// Orden del catálogo. `apiValue` es el valor que espera el backend
/// en `sort_by`.
enum CatalogSortBy {
  name('name'),
  price('price'),
  createdAt('created_at');

  final String apiValue;

  const CatalogSortBy(this.apiValue);
}

/// Filtros del catálogo (CU25). Todos son opcionales.
class StoreCatalogFilters {
  final String? search;
  final String? audience;
  final String? category;
  final double? minPrice;
  final double? maxPrice;
  final bool? promotion;
  final bool? inStock;
  final int? branchId;
  final CatalogSortBy sortBy;
  final String sortOrder; // 'asc' | 'desc'

  const StoreCatalogFilters({
    this.search,
    this.audience,
    this.category,
    this.minPrice,
    this.maxPrice,
    this.promotion,
    this.inStock,
    this.branchId,
    this.sortBy = CatalogSortBy.name,
    this.sortOrder = 'asc',
  });

  /// Los campos con `null` conservan el valor actual. Para quitar un filtro
  /// se crea un `StoreCatalogFilters` nuevo (como hace la hoja de filtros).
  StoreCatalogFilters copyWith({
    String? search,
    String? audience,
    String? category,
    double? minPrice,
    double? maxPrice,
    bool? promotion,
    bool? inStock,
    int? branchId,
    CatalogSortBy? sortBy,
    String? sortOrder,
  }) {
    return StoreCatalogFilters(
      search: search ?? this.search,
      audience: audience ?? this.audience,
      category: category ?? this.category,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      promotion: promotion ?? this.promotion,
      inStock: inStock ?? this.inStock,
      branchId: branchId ?? this.branchId,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  /// Parámetros de query para `GET /store/catalog`.
  /// Solo se envían los filtros que tienen valor.
  Map<String, String> toQueryParameters({
    required int page,
    required int pageSize,
  }) {
    final trimmedSearch = search?.trim();
    final trimmedAudience = audience?.trim();
    final trimmedCategory = category?.trim();

    return {
      'page': '$page',
      'page_size': '$pageSize',
      if (trimmedSearch != null && trimmedSearch.isNotEmpty)
        'search': trimmedSearch,
      if (trimmedAudience != null && trimmedAudience.isNotEmpty)
        'audience': trimmedAudience,
      if (trimmedCategory != null && trimmedCategory.isNotEmpty)
        'category': trimmedCategory,
      if (minPrice != null) 'min_price': '$minPrice',
      if (maxPrice != null) 'max_price': '$maxPrice',
      if (promotion != null) 'promotion': '$promotion',
      if (inStock != null) 'in_stock': '$inStock',
      if (branchId != null) 'branch_id': '$branchId',
      'sort_by': sortBy.apiValue,
      'sort_order': sortOrder,
    };
  }
}

/// Una página del catálogo.
class StoreCatalogPage {
  final List<StoreCatalogProduct> items;
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;

  const StoreCatalogPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
  });

  factory StoreCatalogPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];

    return StoreCatalogPage(
      items: rawItems
          .map((e) => StoreCatalogProduct.fromJson(e as Map<String, dynamic>))
          .toList(),
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? rawItems.length,
      total: json['total'] as int? ?? rawItems.length,
      totalPages: json['total_pages'] as int? ?? 1,
    );
  }
}

/// Módulo 6 - Catálogo del cliente.
///
/// Todos estos endpoints son públicos (no llevan token).
///   CU24 / CU25 -> GET /store/catalog
///   CU26        -> GET /store/products/{id}
///   CU27        -> GET /store/products/{id}/availability
///   Sucursales  -> GET /store/branches
class StoreCatalogService {
  StoreCatalogService._();

  static const int defaultPageSize = 12;
  static const Duration _timeout = Duration(seconds: 20);

  // -----------------------------------------------------------
  // Sucursales activas (para el filtro por sucursal)
  // -----------------------------------------------------------
  static Future<List<StoreBranch>> getBranches() async {
    final response = await ApiService.get('/store/branches').timeout(_timeout);
    final data = _decode(response) as Map<String, dynamic>;

    final items = data['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => StoreBranch.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // -----------------------------------------------------------
  // CU24 / CU25 - Catálogo con búsqueda y filtros
  // -----------------------------------------------------------
  static Future<StoreCatalogPage> getCatalog({
    StoreCatalogFilters filters = const StoreCatalogFilters(),
    int page = 1,
    int pageSize = defaultPageSize,
  }) async {
    final endpoint = Uri(
      path: '/store/catalog',
      queryParameters: filters.toQueryParameters(
        page: page,
        pageSize: pageSize,
      ),
    ).toString();

    final response = await ApiService.get(endpoint).timeout(_timeout);
    return StoreCatalogPage.fromJson(_decode(response) as Map<String, dynamic>);
  }

  // -----------------------------------------------------------
  // CU26 - Detalle de prenda
  // -----------------------------------------------------------
  static Future<StoreProductDetail> getProductDetail(
      int productId, {
        int? branchId,
      }) async {
    final endpoint = Uri(
      path: '/store/products/$productId',
      queryParameters: {
        if (branchId != null) 'branch_id': '$branchId',
      },
    ).toString();

    final response = await ApiService.get(endpoint).timeout(_timeout);
    return StoreProductDetail.fromJson(
      _decode(response) as Map<String, dynamic>,
    );
  }

  // -----------------------------------------------------------
  // CU27 - Disponibilidad de una variante por sucursal
  // -----------------------------------------------------------
  static Future<ProductVariantAvailability> getAvailability(
      int productId, {
        required int variantId,
        int? cityId,
      }) async {
    final endpoint = Uri(
      path: '/store/products/$productId/availability',
      queryParameters: {
        'variant_id': '$variantId',
        if (cityId != null) 'city_id': '$cityId',
      },
    ).toString();

    final response = await ApiService.get(endpoint).timeout(_timeout);
    return ProductVariantAvailability.fromJson(
      _decode(response) as Map<String, dynamic>,
    );
  }

  // -----------------------------------------------------------
  // Helper: valida el status y decodifica en UTF-8.
  // Se usa `bodyBytes` porque FastAPI no envía `charset` en el
  // Content-Type y así se evitan tildes y "ñ" rotas ("NiÃ±o").
  // -----------------------------------------------------------
  static dynamic _decode(http.Response response) {
    throwIfError(response);
    return jsonDecode(utf8.decode(response.bodyBytes));
  }
}