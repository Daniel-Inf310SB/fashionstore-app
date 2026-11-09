class CatalogTag {
  const CatalogTag({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  factory CatalogTag.fromJson(Map<String, dynamic> json) {
    return CatalogTag(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
    );
  }
}

class CatalogPromotion {
  const CatalogPromotion({
    required this.id,
    required this.name,
    required this.discountType,
    required this.discountValue,
  });

  final int id;
  final String name;
  final String discountType;
  final double discountValue;

  factory CatalogPromotion.fromJson(Map<String, dynamic> json) {
    return CatalogPromotion(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      discountType: json['discount_type']?.toString() ?? '',
      discountValue: _toDouble(json['discount_value']),
    );
  }
}

class Product {
  const Product({
    required this.id,
    required this.code,
    required this.name,
    required this.basePrice,
    required this.minPrice,
    required this.maxPrice,
    required this.originalMinPrice,
    required this.originalMaxPrice,
    required this.hasDiscount,
    required this.category,
    required this.audience,
    required this.variantCount,
    required this.availableVariants,
    required this.totalAvailable,
    required this.hasStock,
    this.description,
    this.brand,
    this.coverImageUrl,
    this.promotion,
  });

  final int id;
  final String code;
  final String name;
  final String? description;
  final String? brand;

  final double basePrice;
  final double minPrice;
  final double maxPrice;
  final double originalMinPrice;
  final double originalMaxPrice;

  final bool hasDiscount;
  final CatalogPromotion? promotion;
  final String? coverImageUrl;

  final CatalogTag category;
  final CatalogTag audience;

  final int variantCount;
  final int availableVariants;
  final int totalAvailable;
  final bool hasStock;

  factory Product.fromJson(Map<String, dynamic> json) {
    final rawCategory = json['category'];
    final rawAudience = json['audience'];
    final rawPromotion = json['promotion'];

    return Product(
      id: (json['id'] as num?)?.toInt() ?? 0,
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      brand: json['brand']?.toString(),
      basePrice: _toDouble(json['base_price']),
      minPrice: _toDouble(json['min_price']),
      maxPrice: _toDouble(json['max_price']),
      originalMinPrice: _toDouble(json['original_min_price']),
      originalMaxPrice: _toDouble(json['original_max_price']),
      hasDiscount: json['has_discount'] == true,
      promotion: rawPromotion is Map
          ? CatalogPromotion.fromJson(
              Map<String, dynamic>.from(rawPromotion),
            )
          : null,
      coverImageUrl: json['cover_image_url']?.toString(),
      category: rawCategory is Map
          ? CatalogTag.fromJson(
              Map<String, dynamic>.from(rawCategory),
            )
          : CatalogTag(
              id: (json['category_id'] as num?)?.toInt() ?? 0,
              name: '',
            ),
      audience: rawAudience is Map
          ? CatalogTag.fromJson(
              Map<String, dynamic>.from(rawAudience),
            )
          : CatalogTag(
              id: (json['audience_id'] as num?)?.toInt() ?? 0,
              name: '',
            ),
      variantCount: (json['variant_count'] as num?)?.toInt() ?? 0,
      availableVariants:
          (json['available_variants'] as num?)?.toInt() ?? 0,
      totalAvailable: (json['total_available'] as num?)?.toInt() ?? 0,
      hasStock: json['has_stock'] == true,
    );
  }
}

double _toDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value?.toString() ?? '') ?? 0;
}
