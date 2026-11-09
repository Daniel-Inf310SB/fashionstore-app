class MyCartResponse {
  const MyCartResponse({
    required this.branchId,
    required this.hasCart,
    required this.totalItems,
    required this.totalUnits,
    required this.totalAmount,
    this.cart,
  });

  final int branchId;
  final bool hasCart;
  final int totalItems;
  final int totalUnits;
  final double totalAmount;
  final ShoppingCart? cart;

  factory MyCartResponse.fromJson(Map<String, dynamic> json) {
    final rawCart = json['cart'];

    return MyCartResponse(
      branchId: (json['branch_id'] as num?)?.toInt() ?? 0,
      hasCart: json['has_cart'] == true,
      totalItems: (json['total_items'] as num?)?.toInt() ?? 0,
      totalUnits: (json['total_units'] as num?)?.toInt() ?? 0,
      totalAmount: _toDouble(json['total_amount']),
      cart: rawCart is Map
          ? ShoppingCart.fromJson(
              Map<String, dynamic>.from(rawCart),
            )
          : null,
    );
  }
}

class CartCountResponse {
  const CartCountResponse({
    required this.branchId,
    required this.totalItems,
    required this.totalUnits,
  });

  final int branchId;
  final int totalItems;
  final int totalUnits;

  factory CartCountResponse.fromJson(Map<String, dynamic> json) {
    return CartCountResponse(
      branchId: (json['branch_id'] as num?)?.toInt() ?? 0,
      totalItems: (json['total_items'] as num?)?.toInt() ?? 0,
      totalUnits: (json['total_units'] as num?)?.toInt() ?? 0,
    );
  }
}

class CartActionResponse {
  const CartActionResponse({
    required this.message,
    required this.cart,
  });

  final String message;
  final ShoppingCart cart;

  factory CartActionResponse.fromJson(Map<String, dynamic> json) {
    final rawCart = json['cart'];

    if (rawCart is! Map) {
      throw const FormatException(
        'La respuesta no contiene el carrito actualizado.',
      );
    }

    return CartActionResponse(
      message: json['message']?.toString() ?? 'Carrito actualizado.',
      cart: ShoppingCart.fromJson(
        Map<String, dynamic>.from(rawCart),
      ),
    );
  }
}

class CartClearResponse {
  const CartClearResponse({
    required this.message,
    required this.branchId,
    required this.removedItems,
    required this.totalItems,
    required this.totalUnits,
  });

  final String message;
  final int branchId;
  final int removedItems;
  final int totalItems;
  final int totalUnits;

  factory CartClearResponse.fromJson(Map<String, dynamic> json) {
    return CartClearResponse(
      message: json['message']?.toString() ?? 'Carrito vacío.',
      branchId: (json['branch_id'] as num?)?.toInt() ?? 0,
      removedItems: (json['removed_items'] as num?)?.toInt() ?? 0,
      totalItems: (json['total_items'] as num?)?.toInt() ?? 0,
      totalUnits: (json['total_units'] as num?)?.toInt() ?? 0,
    );
  }
}

class ShoppingCart {
  const ShoppingCart({
    required this.id,
    required this.cartCode,
    required this.customerId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.totalItems,
    required this.totalUnits,
    required this.originalTotalAmount,
    required this.discountAmount,
    required this.totalAmount,
    required this.customer,
    required this.items,
    this.branchId,
    this.branch,
  });

  final int id;
  final String cartCode;
  final int customerId;
  final int? branchId;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  final int totalItems;
  final int totalUnits;
  final double originalTotalAmount;
  final double discountAmount;
  final double totalAmount;

  final CartCustomer customer;
  final CartBranch? branch;
  final List<CartItem> items;

  bool get hasDiscount => discountAmount > 0.0001;

  factory ShoppingCart.fromJson(Map<String, dynamic> json) {
    final rawCustomer = json['customer'];
    final rawBranch = json['branch'];
    final rawItems = json['items'];

    return ShoppingCart(
      id: (json['id'] as num?)?.toInt() ?? 0,
      cartCode: json['cart_code']?.toString() ?? '',
      customerId: (json['customer_id'] as num?)?.toInt() ?? 0,
      branchId: (json['branch_id'] as num?)?.toInt(),
      status: json['status']?.toString() ?? 'ACTIVE',
      createdAt: _toDate(json['created_at']),
      updatedAt: _toDate(json['updated_at']),
      totalItems: (json['total_items'] as num?)?.toInt() ?? 0,
      totalUnits: (json['total_units'] as num?)?.toInt() ?? 0,
      originalTotalAmount:
          _toDouble(json['original_total_amount']),
      discountAmount: _toDouble(json['discount_amount']),
      totalAmount: _toDouble(json['total_amount']),
      customer: rawCustomer is Map
          ? CartCustomer.fromJson(
              Map<String, dynamic>.from(rawCustomer),
            )
          : const CartCustomer(
              id: 0,
              firstName: '',
              email: '',
            ),
      branch: rawBranch is Map
          ? CartBranch.fromJson(
              Map<String, dynamic>.from(rawBranch),
            )
          : null,
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map(
                (item) => CartItem.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
          : const [],
    );
  }
}

class CartCustomer {
  const CartCustomer({
    required this.id,
    required this.firstName,
    required this.email,
    this.lastName,
    this.phone,
  });

  final int id;
  final String firstName;
  final String? lastName;
  final String email;
  final String? phone;

  factory CartCustomer.fromJson(Map<String, dynamic> json) {
    return CartCustomer(
      id: (json['id'] as num?)?.toInt() ?? 0,
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString(),
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString(),
    );
  }
}

class CartBranch {
  const CartBranch({
    required this.id,
    required this.name,
    required this.address,
    required this.cityId,
    this.phone,
  });

  final int id;
  final String name;
  final String address;
  final String? phone;
  final int cityId;

  factory CartBranch.fromJson(Map<String, dynamic> json) {
    return CartBranch(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? 'Sucursal',
      address: json['address']?.toString() ?? '',
      phone: json['phone']?.toString(),
      cityId: (json['city_id'] as num?)?.toInt() ?? 0,
    );
  }
}

class CartItem {
  const CartItem({
    required this.id,
    required this.cartId,
    required this.productVariantId,
    required this.quantity,
    required this.originalUnitPrice,
    required this.unitPrice,
    required this.discountAmount,
    required this.originalSubtotal,
    required this.subtotal,
    required this.hasDiscount,
    required this.productVariant,
    this.promotion,
  });

  final int id;
  final int cartId;
  final int productVariantId;
  final int quantity;

  final double originalUnitPrice;
  final double unitPrice;
  final double discountAmount;
  final double originalSubtotal;
  final double subtotal;

  final bool hasDiscount;
  final CartPromotion? promotion;
  final CartVariant productVariant;

  String? get imageUrl {
    final own = productVariant.imageUrl?.trim();
    if (own != null && own.isNotEmpty) return own;

    final cover = productVariant.product.coverImageUrl?.trim();
    return cover != null && cover.isNotEmpty ? cover : null;
  }

  String get promotionLabel {
    final promo = promotion;

    if (!hasDiscount || promo == null) return '';

    if (promo.discountType.toUpperCase() == 'PERCENTAGE') {
      final value = promo.discountValue;
      return '-${value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2)}%';
    }

    return '-Bs ${promo.discountValue.toStringAsFixed(2)}';
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    final rawPromotion = json['promotion'];
    final rawVariant = json['product_variant'];

    return CartItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      cartId: (json['cart_id'] as num?)?.toInt() ?? 0,
      productVariantId:
          (json['product_variant_id'] as num?)?.toInt() ?? 0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      originalUnitPrice:
          _toDouble(json['original_unit_price']),
      unitPrice: _toDouble(json['unit_price']),
      discountAmount: _toDouble(json['discount_amount']),
      originalSubtotal:
          _toDouble(json['original_subtotal']),
      subtotal: _toDouble(json['subtotal']),
      hasDiscount: json['has_discount'] == true,
      promotion: rawPromotion is Map
          ? CartPromotion.fromJson(
              Map<String, dynamic>.from(rawPromotion),
            )
          : null,
      productVariant: rawVariant is Map
          ? CartVariant.fromJson(
              Map<String, dynamic>.from(rawVariant),
            )
          : const CartVariant(
              id: 0,
              sku: '',
              productId: 0,
              sizeId: 0,
              colorId: 0,
              product: CartProduct(
                id: 0,
                code: '',
                name: 'Producto',
                basePrice: 0,
              ),
              size: CartSize(id: 0, name: ''),
              color: CartColor(id: 0, name: ''),
            ),
    );
  }
}

class CartPromotion {
  const CartPromotion({
    required this.id,
    required this.name,
    required this.discountType,
    required this.discountValue,
  });

  final int id;
  final String name;
  final String discountType;
  final double discountValue;

  factory CartPromotion.fromJson(Map<String, dynamic> json) {
    return CartPromotion(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      discountType: json['discount_type']?.toString() ?? '',
      discountValue: _toDouble(json['discount_value']),
    );
  }
}

class CartVariant {
  const CartVariant({
    required this.id,
    required this.sku,
    required this.productId,
    required this.sizeId,
    required this.colorId,
    required this.product,
    required this.size,
    required this.color,
    this.imageUrl,
    this.additionalPrice,
  });

  final int id;
  final String sku;
  final int productId;
  final int sizeId;
  final int colorId;
  final String? imageUrl;
  final double? additionalPrice;

  final CartProduct product;
  final CartSize size;
  final CartColor color;

  factory CartVariant.fromJson(Map<String, dynamic> json) {
    final rawProduct = json['product'];
    final rawSize = json['size'];
    final rawColor = json['color'];

    return CartVariant(
      id: (json['id'] as num?)?.toInt() ?? 0,
      sku: json['sku']?.toString() ?? '',
      productId: (json['product_id'] as num?)?.toInt() ?? 0,
      sizeId: (json['size_id'] as num?)?.toInt() ?? 0,
      colorId: (json['color_id'] as num?)?.toInt() ?? 0,
      imageUrl: json['image_url']?.toString(),
      additionalPrice: json['additional_price'] == null
          ? null
          : _toDouble(json['additional_price']),
      product: rawProduct is Map
          ? CartProduct.fromJson(
              Map<String, dynamic>.from(rawProduct),
            )
          : const CartProduct(
              id: 0,
              code: '',
              name: 'Producto',
              basePrice: 0,
            ),
      size: rawSize is Map
          ? CartSize.fromJson(
              Map<String, dynamic>.from(rawSize),
            )
          : const CartSize(id: 0, name: ''),
      color: rawColor is Map
          ? CartColor.fromJson(
              Map<String, dynamic>.from(rawColor),
            )
          : const CartColor(id: 0, name: ''),
    );
  }
}

class CartProduct {
  const CartProduct({
    required this.id,
    required this.code,
    required this.name,
    required this.basePrice,
    this.brand,
    this.coverImageUrl,
  });

  final int id;
  final String code;
  final String name;
  final String? brand;
  final String? coverImageUrl;
  final double basePrice;

  factory CartProduct.fromJson(Map<String, dynamic> json) {
    return CartProduct(
      id: (json['id'] as num?)?.toInt() ?? 0,
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Producto',
      brand: json['brand']?.toString(),
      coverImageUrl: json['cover_image_url']?.toString(),
      basePrice: _toDouble(json['base_price']),
    );
  }
}

class CartSize {
  const CartSize({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  factory CartSize.fromJson(Map<String, dynamic> json) {
    return CartSize(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
    );
  }
}

class CartColor {
  const CartColor({
    required this.id,
    required this.name,
    this.hexCode,
  });

  final int id;
  final String name;
  final String? hexCode;

  factory CartColor.fromJson(Map<String, dynamic> json) {
    return CartColor(
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

DateTime? _toDate(dynamic value) {
  final raw = value?.toString();
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}
