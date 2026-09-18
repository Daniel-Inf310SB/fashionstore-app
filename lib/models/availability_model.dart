import 'product.dart';

/// Stock de una variante en una sucursal concreta.
class BranchAvailability {
  final int branchId;
  final String branchName;
  final int cityId;
  final String cityName;
  final String address;
  final String? phone;
  final int availableQuantity;
  final bool hasStock;

  const BranchAvailability({
    required this.branchId,
    required this.branchName,
    required this.cityId,
    required this.cityName,
    required this.address,
    required this.availableQuantity,
    required this.hasStock,
    this.phone,
  });

  factory BranchAvailability.fromJson(Map<String, dynamic> json) {
    return BranchAvailability(
      branchId: json['branch_id'] as int,
      branchName: json['branch_name'] as String,
      cityId: json['city_id'] as int,
      cityName: json['city_name'] as String,
      address: json['address'] as String? ?? '',
      phone: json['phone'] as String?,
      availableQuantity: json['available_quantity'] as int? ?? 0,
      hasStock: json['has_stock'] as bool? ?? false,
    );
  }
}

/// Respuesta de `GET /store/products/{id}/availability?variant_id=...` (CU27).
class ProductVariantAvailability {
  final int productId;
  final String productName;
  final int variantId;
  final String sku;
  final StoreSize size;
  final StoreColor color;
  final int totalAvailable;
  final int availableBranches;
  final List<BranchAvailability> branches;

  const ProductVariantAvailability({
    required this.productId,
    required this.productName,
    required this.variantId,
    required this.sku,
    required this.size,
    required this.color,
    required this.totalAvailable,
    required this.availableBranches,
    required this.branches,
  });

  factory ProductVariantAvailability.fromJson(Map<String, dynamic> json) {
    final rawBranches = json['branches'] as List<dynamic>? ?? [];

    return ProductVariantAvailability(
      productId: json['product_id'] as int,
      productName: json['product_name'] as String,
      variantId: json['variant_id'] as int,
      sku: json['sku'] as String,
      size: StoreSize.fromJson(json['size'] as Map<String, dynamic>),
      color: StoreColor.fromJson(json['color'] as Map<String, dynamic>),
      totalAvailable: json['total_available'] as int? ?? 0,
      availableBranches: json['available_branches'] as int? ?? 0,
      branches: rawBranches
          .map((e) => BranchAvailability.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}