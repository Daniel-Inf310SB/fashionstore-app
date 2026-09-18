import '../core/utils/son_utils.dart';

// =============================================================
// REFERENCIAS SIMPLES
// =============================================================

class StoreCategory {
  final int id;
  final String name;

  const StoreCategory({required this.id, required this.name});

  factory StoreCategory.fromJson(Map<String, dynamic> json) {
    return StoreCategory(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }
}

class StoreAudience {
  final int id;
  final String name;

  const StoreAudience({required this.id, required this.name});

  factory StoreAudience.fromJson(Map<String, dynamic> json) {
    return StoreAudience(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }
}

class StoreSize {
  final int id;
  final String name;
  final String? description;
  final int sortOrder;

  const StoreSize({
    required this.id,
    required this.name,
    this.description,
    this.sortOrder = 0,
  });

  factory StoreSize.fromJson(Map<String, dynamic> json) {
    return StoreSize(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }
}

class StoreColor {
  final int id;
  final String name;
  final String? hexCode;

  const StoreColor({required this.id, required this.name, this.hexCode});

  factory StoreColor.fromJson(Map<String, dynamic> json) {
    return StoreColor(
      id: json['id'] as int,
      name: json['name'] as String,
      hexCode: json['hex_code'] as String?,
    );
  }
}

class StoreProductImage {
  final int id;
  final String imageUrl;
  final String? altText;
  final int sortOrder;
  final bool isPrimary;

  const StoreProductImage({
    required this.id,
    required this.imageUrl,
    this.altText,
    this.sortOrder = 0,
    this.isPrimary = false,
  });

  factory StoreProductImage.fromJson(Map<String, dynamic> json) {
    return StoreProductImage(
      id: json['id'] as int,
      imageUrl: json['image_url'] as String,
      altText: json['alt_text'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isPrimary: json['is_primary'] as bool? ?? false,
    );
  }
}

// =============================================================
// VARIANTE (talla + color)
// =============================================================

class StoreProductVariant {
  final int id;
  final String sku;
  final int sizeId;
  final int colorId;
  final double additionalPrice;
  final double finalPrice;
  final String? imageUrl;
  final StoreSize size;
  final StoreColor color;
  final int totalAvailable;
  final bool hasStock;

  const StoreProductVariant({
    required this.id,
    required this.sku,
    required this.sizeId,
    required this.colorId,
    required this.additionalPrice,
    required this.finalPrice,
    required this.size,
    required this.color,
    required this.totalAvailable,
    required this.hasStock,
    this.imageUrl,
  });

  factory StoreProductVariant.fromJson(Map<String, dynamic> json) {
    return StoreProductVariant(
      id: json['id'] as int,
      sku: json['sku'] as String,
      sizeId: json['size_id'] as int,
      colorId: json['color_id'] as int,
      additionalPrice: parseDouble(json['additional_price']),
      finalPrice: parseDouble(json['final_price']),
      imageUrl: json['image_url'] as String?,
      size: StoreSize.fromJson(json['size'] as Map<String, dynamic>),
      color: StoreColor.fromJson(json['color'] as Map<String, dynamic>),
      totalAvailable: json['total_available'] as int? ?? 0,
      hasStock: json['has_stock'] as bool? ?? false,
    );
  }
}

// =============================================================
// PRODUCTO EN EL LISTADO (CU24 / CU25)
// =============================================================

class StoreCatalogProduct {
  final int id;
  final String code;
  final String name;
  final String? description;
  final String? brand;
  final double basePrice;
  final double minPrice;
  final double maxPrice;
  final String? coverImageUrl;
  final StoreCategory category;
  final StoreAudience audience;
  final int variantCount;
  final int availableVariants;
  final int totalAvailable;
  final bool hasStock;

  const StoreCatalogProduct({
    required this.id,
    required this.code,
    required this.name,
    required this.basePrice,
    required this.minPrice,
    required this.maxPrice,
    required this.category,
    required this.audience,
    required this.variantCount,
    required this.availableVariants,
    required this.totalAvailable,
    required this.hasStock,
    this.description,
    this.brand,
    this.coverImageUrl,
  });

  /// `Bs 120.00` si todas las variantes cuestan lo mismo,
  /// o `Desde Bs 120.00` si hay variantes con recargo.
  String get priceLabel {
    return minPrice == maxPrice
        ? formatBs(minPrice)
        : 'Desde ${formatBs(minPrice)}';
  }

  factory StoreCatalogProduct.fromJson(Map<String, dynamic> json) {
    return StoreCatalogProduct(
      id: json['id'] as int,
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      brand: json['brand'] as String?,
      basePrice: parseDouble(json['base_price']),
      minPrice: parseDouble(json['min_price']),
      maxPrice: parseDouble(json['max_price']),
      coverImageUrl: json['cover_image_url'] as String?,
      category:
      StoreCategory.fromJson(json['category'] as Map<String, dynamic>),
      audience:
      StoreAudience.fromJson(json['audience'] as Map<String, dynamic>),
      variantCount: json['variant_count'] as int? ?? 0,
      availableVariants: json['available_variants'] as int? ?? 0,
      totalAvailable: json['total_available'] as int? ?? 0,
      hasStock: json['has_stock'] as bool? ?? false,
    );
  }
}

// =============================================================
// DETALLE DE PRODUCTO (CU26)
// =============================================================

class StoreProductDetail {
  final int id;
  final String code;
  final String name;
  final String? description;
  final String? brand;
  final double basePrice;
  final double minPrice;
  final double maxPrice;
  final String? coverImageUrl;
  final StoreCategory category;
  final StoreAudience audience;
  final List<StoreProductImage> images;
  final List<StoreProductVariant> variants;
  final int variantCount;
  final int availableVariants;
  final int totalAvailable;
  final bool hasStock;

  const StoreProductDetail({
    required this.id,
    required this.code,
    required this.name,
    required this.basePrice,
    required this.minPrice,
    required this.maxPrice,
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
  });

  String get priceLabel {
    return minPrice == maxPrice
        ? formatBs(minPrice)
        : 'Desde ${formatBs(minPrice)}';
  }

  /// Tallas distintas presentes en las variantes, ordenadas por `sort_order`.
  List<StoreSize> get availableSizes {
    final bySize = <int, StoreSize>{};
    for (final variant in variants) {
      bySize.putIfAbsent(variant.size.id, () => variant.size);
    }
    final sizes = bySize.values.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return sizes;
  }

  /// Colores distintos presentes en las variantes (orden de aparición).
  List<StoreColor> get availableColors {
    final byColor = <int, StoreColor>{};
    for (final variant in variants) {
      byColor.putIfAbsent(variant.color.id, () => variant.color);
    }
    return byColor.values.toList();
  }

  /// Variante exacta para una talla y un color. Devuelve `null` si falta
  /// alguno de los dos o si esa combinación no existe.
  StoreProductVariant? variantFor({int? sizeId, int? colorId}) {
    if (sizeId == null || colorId == null) return null;

    for (final variant in variants) {
      if (variant.sizeId == sizeId && variant.colorId == colorId) {
        return variant;
      }
    }
    return null;
  }

  factory StoreProductDetail.fromJson(Map<String, dynamic> json) {
    final rawImages = (json['images'] as List<dynamic>? ?? []);
    final rawVariants = (json['variants'] as List<dynamic>? ?? []);

    final images = rawImages
        .map((e) => StoreProductImage.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return StoreProductDetail(
      id: json['id'] as int,
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      brand: json['brand'] as String?,
      basePrice: parseDouble(json['base_price']),
      minPrice: parseDouble(json['min_price']),
      maxPrice: parseDouble(json['max_price']),
      coverImageUrl: json['cover_image_url'] as String?,
      category:
      StoreCategory.fromJson(json['category'] as Map<String, dynamic>),
      audience:
      StoreAudience.fromJson(json['audience'] as Map<String, dynamic>),
      images: images,
      variants: rawVariants
          .map((e) => StoreProductVariant.fromJson(e as Map<String, dynamic>))
          .toList(),
      variantCount: json['variant_count'] as int? ?? 0,
      availableVariants: json['available_variants'] as int? ?? 0,
      totalAvailable: json['total_available'] as int? ?? 0,
      hasStock: json['has_stock'] as bool? ?? false,
    );
  }
}