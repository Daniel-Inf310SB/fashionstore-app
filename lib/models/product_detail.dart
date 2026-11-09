class ProductDetail {
  const ProductDetail({
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
    required this.images,
    required this.variants,
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
  final ProductDetailPromotion? promotion;
  final String? coverImageUrl;

  final ProductDetailTag category;
  final ProductDetailTag audience;

  final List<ProductDetailImage> images;
  final List<ProductDetailVariant> variants;

  final int variantCount;
  final int availableVariants;
  final int totalAvailable;
  final bool hasStock;

  factory ProductDetail.fromJson(Map<String, dynamic> json) {
    final rawImages = json['images'];
    final rawVariants = json['variants'];
    final rawCategory = json['category'];
    final rawAudience = json['audience'];
    final rawPromotion = json['promotion'];

    return ProductDetail(
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
          ? ProductDetailPromotion.fromJson(
              Map<String, dynamic>.from(rawPromotion),
            )
          : null,
      coverImageUrl: json['cover_image_url']?.toString(),
      category: rawCategory is Map
          ? ProductDetailTag.fromJson(
              Map<String, dynamic>.from(rawCategory),
            )
          : const ProductDetailTag(id: 0, name: ''),
      audience: rawAudience is Map
          ? ProductDetailTag.fromJson(
              Map<String, dynamic>.from(rawAudience),
            )
          : const ProductDetailTag(id: 0, name: ''),
      images: rawImages is List
          ? rawImages
              .whereType<Map>()
              .map(
                (item) => ProductDetailImage.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
          : const [],
      variants: rawVariants is List
          ? rawVariants
              .whereType<Map>()
              .map(
                (item) => ProductDetailVariant.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
          : const [],
      variantCount: (json['variant_count'] as num?)?.toInt() ?? 0,
      availableVariants:
          (json['available_variants'] as num?)?.toInt() ?? 0,
      totalAvailable: (json['total_available'] as num?)?.toInt() ?? 0,
      hasStock: json['has_stock'] == true,
    );
  }

  List<String> get galleryUrls {
    final values = <String>{};

    final cover = coverImageUrl?.trim();
    if (cover != null && cover.isNotEmpty) {
      values.add(cover);
    }

    final sortedImages = [...images]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    for (final image in sortedImages) {
      final url = image.imageUrl.trim();
      if (url.isNotEmpty) values.add(url);
    }

    for (final variant in variants) {
      final url = variant.imageUrl?.trim();
      if (url != null && url.isNotEmpty) {
        values.add(url);
      }
    }

    return values.toList();
  }

  List<ProductDetailSize> get sizes {
    final map = <int, ProductDetailSize>{};

    for (final variant in variants) {
      map[variant.size.id] = variant.size;
    }

    final values = map.values.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return values;
  }

  List<ProductDetailColor> colorsForSize(int? sizeId) {
    final map = <int, ProductDetailColor>{};

    for (final variant in variants) {
      if (sizeId != null && variant.sizeId != sizeId) continue;
      map[variant.color.id] = variant.color;
    }

    return map.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  ProductDetailVariant? variantFor({
    required int? sizeId,
    required int? colorId,
  }) {
    if (sizeId == null || colorId == null) return null;

    for (final variant in variants) {
      if (variant.sizeId == sizeId &&
          variant.colorId == colorId) {
        return variant;
      }
    }

    return null;
  }
}

class ProductDetailTag {
  const ProductDetailTag({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  factory ProductDetailTag.fromJson(Map<String, dynamic> json) {
    return ProductDetailTag(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
    );
  }
}

class ProductDetailPromotion {
  const ProductDetailPromotion({
    required this.id,
    required this.name,
    required this.discountType,
    required this.discountValue,
  });

  final int id;
  final String name;
  final String discountType;
  final double discountValue;

  factory ProductDetailPromotion.fromJson(
    Map<String, dynamic> json,
  ) {
    return ProductDetailPromotion(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      discountType: json['discount_type']?.toString() ?? '',
      discountValue: _toDouble(json['discount_value']),
    );
  }
}

class ProductDetailImage {
  const ProductDetailImage({
    required this.id,
    required this.imageUrl,
    required this.sortOrder,
    required this.isPrimary,
    this.altText,
  });

  final int id;
  final String imageUrl;
  final String? altText;
  final int sortOrder;
  final bool isPrimary;

  factory ProductDetailImage.fromJson(Map<String, dynamic> json) {
    return ProductDetailImage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      imageUrl: json['image_url']?.toString() ?? '',
      altText: json['alt_text']?.toString(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isPrimary: json['is_primary'] == true,
    );
  }
}

class ProductDetailVariant {
  const ProductDetailVariant({
    required this.id,
    required this.sku,
    required this.sizeId,
    required this.colorId,
    required this.additionalPrice,
    required this.originalPrice,
    required this.finalPrice,
    required this.size,
    required this.color,
    required this.totalAvailable,
    required this.hasStock,
    this.imageUrl,
  });

  final int id;
  final String sku;
  final int sizeId;
  final int colorId;

  final double additionalPrice;
  final double originalPrice;
  final double finalPrice;

  final String? imageUrl;

  final ProductDetailSize size;
  final ProductDetailColor color;

  final int totalAvailable;
  final bool hasStock;

  factory ProductDetailVariant.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawSize = json['size'];
    final rawColor = json['color'];

    return ProductDetailVariant(
      id: (json['id'] as num?)?.toInt() ?? 0,
      sku: json['sku']?.toString() ?? '',
      sizeId: (json['size_id'] as num?)?.toInt() ?? 0,
      colorId: (json['color_id'] as num?)?.toInt() ?? 0,
      additionalPrice: _toDouble(json['additional_price']),
      originalPrice: _toDouble(json['original_price']),
      finalPrice: _toDouble(json['final_price']),
      imageUrl: json['image_url']?.toString(),
      size: rawSize is Map
          ? ProductDetailSize.fromJson(
              Map<String, dynamic>.from(rawSize),
            )
          : const ProductDetailSize(
              id: 0,
              name: '',
              sortOrder: 0,
            ),
      color: rawColor is Map
          ? ProductDetailColor.fromJson(
              Map<String, dynamic>.from(rawColor),
            )
          : const ProductDetailColor(
              id: 0,
              name: '',
            ),
      totalAvailable:
          (json['total_available'] as num?)?.toInt() ?? 0,
      hasStock: json['has_stock'] == true,
    );
  }

  String? resolveImage(ProductDetail product) {
    final own = imageUrl?.trim();

    if (own != null && own.isNotEmpty) {
      return own;
    }

    final cover = product.coverImageUrl?.trim();

    if (cover != null && cover.isNotEmpty) {
      return cover;
    }

    return null;
  }
}

class ProductDetailSize {
  const ProductDetailSize({
    required this.id,
    required this.name,
    required this.sortOrder,
  });

  final int id;
  final String name;
  final int sortOrder;

  factory ProductDetailSize.fromJson(Map<String, dynamic> json) {
    return ProductDetailSize(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

class ProductDetailColor {
  const ProductDetailColor({
    required this.id,
    required this.name,
    this.hexCode,
  });

  final int id;
  final String name;
  final String? hexCode;

  factory ProductDetailColor.fromJson(Map<String, dynamic> json) {
    return ProductDetailColor(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      hexCode: json['hex_code']?.toString(),
    );
  }
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
