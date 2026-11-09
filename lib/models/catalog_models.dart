import 'product.dart';

class CatalogPageResponse {
  const CatalogPageResponse({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
  });

  final List<Product> items;
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;

  factory CatalogPageResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];

    return CatalogPageResponse(
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map(
                (item) => Product.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
          : <Product>[],
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['page_size'] as num?)?.toInt() ?? 20,
      total: (json['total'] as num?)?.toInt() ?? 0,
      totalPages: (json['total_pages'] as num?)?.toInt() ?? 0,
    );
  }
}

class CatalogMerchandisingOption {
  const CatalogMerchandisingOption({
    required this.id,
    required this.name,
    required this.productCount,
    this.description,
  });

  final int id;
  final String name;
  final String? description;
  final int productCount;

  factory CatalogMerchandisingOption.fromJson(
    Map<String, dynamic> json,
  ) {
    return CatalogMerchandisingOption(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      productCount: (json['product_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class CatalogFilterMetadata {
  const CatalogFilterMetadata({
    required this.categories,
    required this.audiences,
    required this.collections,
    required this.seasons,
    required this.promotions,
  });

  final List<String> categories;
  final List<String> audiences;
  final List<CatalogMerchandisingOption> collections;
  final List<CatalogMerchandisingOption> seasons;
  final List<CatalogMerchandisingOption> promotions;
}

class CatalogFilterState {
  const CatalogFilterState({
    this.category,
    this.audience,
    this.minPrice,
    this.maxPrice,
    this.inStock = false,
    this.onlyPromotions = false,
    this.promotionId,
    this.collectionId,
    this.seasonId,
    this.sortBy = 'created_at',
    this.sortOrder = 'desc',
  });

  final String? category;
  final String? audience;
  final double? minPrice;
  final double? maxPrice;
  final bool inStock;
  final bool onlyPromotions;
  final int? promotionId;
  final int? collectionId;
  final int? seasonId;
  final String sortBy;
  final String sortOrder;

  bool get hasFilters =>
      category != null ||
      audience != null ||
      minPrice != null ||
      maxPrice != null ||
      inStock ||
      onlyPromotions ||
      promotionId != null ||
      collectionId != null ||
      seasonId != null;

  int get activeCount {
    var count = 0;
    if (category != null) count++;
    if (audience != null) count++;
    if (minPrice != null || maxPrice != null) count++;
    if (inStock) count++;
    if (onlyPromotions || promotionId != null) count++;
    if (collectionId != null) count++;
    if (seasonId != null) count++;
    return count;
  }

  CatalogFilterState copyWith({
    String? category,
    bool clearCategory = false,
    String? audience,
    bool clearAudience = false,
    double? minPrice,
    bool clearMinPrice = false,
    double? maxPrice,
    bool clearMaxPrice = false,
    bool? inStock,
    bool? onlyPromotions,
    int? promotionId,
    bool clearPromotionId = false,
    int? collectionId,
    bool clearCollectionId = false,
    int? seasonId,
    bool clearSeasonId = false,
    String? sortBy,
    String? sortOrder,
  }) {
    return CatalogFilterState(
      category: clearCategory ? null : (category ?? this.category),
      audience: clearAudience ? null : (audience ?? this.audience),
      minPrice: clearMinPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
      inStock: inStock ?? this.inStock,
      onlyPromotions: onlyPromotions ?? this.onlyPromotions,
      promotionId:
          clearPromotionId ? null : (promotionId ?? this.promotionId),
      collectionId:
          clearCollectionId ? null : (collectionId ?? this.collectionId),
      seasonId: clearSeasonId ? null : (seasonId ?? this.seasonId),
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  CatalogFilterState clearAll() {
    return CatalogFilterState(
      sortBy: sortBy,
      sortOrder: sortOrder,
    );
  }
}
