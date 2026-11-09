import '../models/catalog_models.dart';
import '../models/product.dart';
import '../services/catalog_service.dart';
import 'offline_catalog_repository.dart';
import 'public_catalog_cache_scope.dart';

/// API para resultados actuales; búsqueda sobre las páginas guardadas si falla
/// el servidor. Nunca mezcla empresas ni sucursales.
class CatalogSearchResult {
  const CatalogSearchResult(this.products, {
    required this.fromCache,
    this.totalPages = 1,
    this.total = 0,
  });

  final List<Product> products;
  final bool fromCache;
  final int totalPages;
  final int total;
}

class CatalogSearchRepository {
  final _local = OfflineCatalogRepository();

  Future<List<Product>> localProducts({int? branchId}) async {
    final scope = await PublicCatalogCacheScope.resolve(branchId: branchId);
    final found = <int, Product>{};
    for (var page = 1; page <= 1000; page++) {
      final endpoint = await CatalogService.buildCatalogEndpoint(
        page: page, pageSize: 20, branchId: branchId,
      );
      final cached = await _local.readCatalog(
        scope: scope, requestUri: Uri.parse(endpoint),
      );
      if (cached == null) break;
      for (final product in cached.items) {
        found[product.id] = product;
      }
      if (page >= cached.totalPages || cached.items.isEmpty) break;
    }
    return found.values.toList();
  }

  bool matches(Product product, String text) {
    final query = _normalize(text);
    if (query.isEmpty) return true;
    final content = _normalize([
      product.name, product.code, product.brand ?? '',
      product.category.name, product.audience.name,
      product.description ?? '',
    ].join(' '));
    return query.split(RegExp(r'\s+')).every(content.contains);
  }

  String _normalize(String s) {
    const accents = 'áéíóúüñ';
    const plain = 'aeiouun';
    var result = s.toLowerCase().trim();
    for (var i = 0; i < accents.length; i++) {
      result = result.replaceAll(accents[i], plain[i]);
    }
    return result;
  }

  Future<CatalogSearchResult> search(String query, {
    int? branchId,
    int page = 1,
    int pageSize = 20,
    bool onlyPromotions = false,
    bool inStock = false,
    String sortBy = 'name',
    String sortOrder = 'asc',
  }) async {
    try {
      final response = await CatalogService.getCatalog(
        page: page, pageSize: pageSize, branchId: branchId,
        search: query.trim().isEmpty ? null : query.trim(),
        filters: CatalogFilterState(
          onlyPromotions: onlyPromotions,
          inStock: inStock,
          sortBy: sortBy,
          sortOrder: sortOrder,
        ),
      );
      return CatalogSearchResult(
        response.items,
        fromCache: false,
        total: response.total,
        totalPages: response.totalPages,
      );
    } catch (_) {
      final products = await localProducts(branchId: branchId);
      final matchesList = products.where((p) =>
        matches(p, query) &&
        (!onlyPromotions || p.hasDiscount) &&
        (!inStock || p.hasStock),
      ).toList();
      int compare(Product a, Product b) {
        int result;
        switch (sortBy) {
          case 'price':
            result = a.minPrice.compareTo(b.minPrice);
            break;
          default:
            result = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        }
        return sortOrder == 'desc' ? -result : result;
      }
      matchesList.sort(compare);
      final totalPages = (matchesList.length / pageSize).ceil();
      final start = (page - 1) * pageSize;
      return CatalogSearchResult(
        start < matchesList.length
          ? matchesList.skip(start).take(pageSize).toList()
          : <Product>[],
        fromCache: true,
        total: matchesList.length,
        totalPages: totalPages,
      );
    }
  }
}
