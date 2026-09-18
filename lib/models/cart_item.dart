import '../core/utils/son_utils.dart';

// =============================================================
// REFERENCIAS SIMPLES
// =============================================================

class CartCustomer {
  final int id;
  final String firstName;
  final String? lastName;
  final String email;
  final String? phone;

  const CartCustomer({
    required this.id,
    required this.firstName,
    required this.email,
    this.lastName,
    this.phone,
  });

  factory CartCustomer.fromJson(Map<String, dynamic> json) {
    return CartCustomer(
      id: json['id'] as int,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String?,
      email: json['email'] as String,
      phone: json['phone'] as String?,
    );
  }
}

class CartBranch {
  final int id;
  final String name;
  final String address;
  final String? phone;
  final int cityId;

  const CartBranch({
    required this.id,
    required this.name,
    required this.address,
    required this.cityId,
    this.phone,
  });

  factory CartBranch.fromJson(Map<String, dynamic> json) {
    return CartBranch(
      id: json['id'] as int,
      name: json['name'] as String,
      address: json['address'] as String,
      phone: json['phone'] as String?,
      cityId: json['city_id'] as int,
    );
  }
}

class CartProduct {
  final int id;
  final String code;
  final String name;
  final String? brand;
  final String? coverImageUrl;
  final double basePrice;

  const CartProduct({
    required this.id,
    required this.code,
    required this.name,
    required this.basePrice,
    this.brand,
    this.coverImageUrl,
  });

  factory CartProduct.fromJson(Map<String, dynamic> json) {
    return CartProduct(
      id: json['id'] as int,
      code: json['code'] as String,
      name: json['name'] as String,
      brand: json['brand'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      basePrice: parseDouble(json['base_price']),
    );
  }
}

class CartSize {
  final int id;
  final String name;

  const CartSize({required this.id, required this.name});

  factory CartSize.fromJson(Map<String, dynamic> json) {
    return CartSize(id: json['id'] as int, name: json['name'] as String);
  }
}

class CartColor {
  final int id;
  final String name;
  final String? hexCode;

  const CartColor({required this.id, required this.name, this.hexCode});

  factory CartColor.fromJson(Map<String, dynamic> json) {
    return CartColor(
      id: json['id'] as int,
      name: json['name'] as String,
      hexCode: json['hex_code'] as String?,
    );
  }
}

// =============================================================
// VARIANTE DENTRO DEL CARRITO
// =============================================================

class CartVariant {
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

  /// Imagen a mostrar: la de la variante si existe, si no la portada del producto.
  String? get displayImageUrl => imageUrl ?? product.coverImageUrl;

  factory CartVariant.fromJson(Map<String, dynamic> json) {
    return CartVariant(
      id: json['id'] as int,
      sku: json['sku'] as String,
      productId: json['product_id'] as int,
      sizeId: json['size_id'] as int,
      colorId: json['color_id'] as int,
      imageUrl: json['image_url'] as String?,
      additionalPrice: parseDoubleOrNull(json['additional_price']),
      product: CartProduct.fromJson(json['product'] as Map<String, dynamic>),
      size: CartSize.fromJson(json['size'] as Map<String, dynamic>),
      color: CartColor.fromJson(json['color'] as Map<String, dynamic>),
    );
  }
}

// =============================================================
// ITEM DEL CARRITO
// =============================================================

class CartLineItem {
  final int id;
  final int cartId;
  final int productVariantId;
  final int quantity;
  final double unitPrice;
  final double subtotal;
  final CartVariant productVariant;

  const CartLineItem({
    required this.id,
    required this.cartId,
    required this.productVariantId,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    required this.productVariant,
  });

  factory CartLineItem.fromJson(Map<String, dynamic> json) {
    return CartLineItem(
      id: json['id'] as int,
      cartId: json['cart_id'] as int,
      productVariantId: json['product_variant_id'] as int,
      quantity: json['quantity'] as int,
      unitPrice: parseDouble(json['unit_price']),
      subtotal: parseDouble(json['subtotal']),
      productVariant:
      CartVariant.fromJson(json['product_variant'] as Map<String, dynamic>),
    );
  }
}

// =============================================================
// CARRITO
// =============================================================

class CartStatus {
  static const String active = 'ACTIVE';
  static const String converted = 'CONVERTED';
  static const String abandoned = 'ABANDONED';
}

class Cart {
  final int id;
  final String cartCode;
  final int customerId;
  final int? branchId;
  final String status;
  final int totalItems;
  final int totalUnits;
  final double totalAmount;
  final CartCustomer customer;
  final CartBranch? branch;
  final List<CartLineItem> items;

  const Cart({
    required this.id,
    required this.cartCode,
    required this.customerId,
    required this.status,
    required this.totalItems,
    required this.totalUnits,
    required this.totalAmount,
    required this.customer,
    required this.items,
    this.branchId,
    this.branch,
  });

  factory Cart.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];

    return Cart(
      id: json['id'] as int,
      cartCode: json['cart_code'] as String,
      customerId: json['customer_id'] as int,
      branchId: json['branch_id'] as int?,
      status: json['status'] as String,
      totalItems: json['total_items'] as int? ?? 0,
      totalUnits: json['total_units'] as int? ?? 0,
      totalAmount: parseDouble(json['total_amount']),
      customer: CartCustomer.fromJson(json['customer'] as Map<String, dynamic>),
      branch: json['branch'] != null
          ? CartBranch.fromJson(json['branch'] as Map<String, dynamic>)
          : null,
      items: rawItems
          .map((e) => CartLineItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// =============================================================
// RESPUESTAS DE `GET /carts/me` Y `GET /carts/me/count`
// =============================================================

class MyCart {
  final int branchId;
  final bool hasCart;
  final int totalItems;
  final int totalUnits;
  final double totalAmount;
  final Cart? cart;

  const MyCart({
    required this.branchId,
    required this.hasCart,
    required this.totalItems,
    required this.totalUnits,
    required this.totalAmount,
    this.cart,
  });

  factory MyCart.fromJson(Map<String, dynamic> json) {
    return MyCart(
      branchId: json['branch_id'] as int,
      hasCart: json['has_cart'] as bool? ?? false,
      totalItems: json['total_items'] as int? ?? 0,
      totalUnits: json['total_units'] as int? ?? 0,
      totalAmount: parseDouble(json['total_amount']),
      cart: json['cart'] != null
          ? Cart.fromJson(json['cart'] as Map<String, dynamic>)
          : null,
    );
  }
}

class CartCount {
  final int branchId;
  final int totalItems;
  final int totalUnits;

  const CartCount({
    required this.branchId,
    required this.totalItems,
    required this.totalUnits,
  });

  factory CartCount.fromJson(Map<String, dynamic> json) {
    return CartCount(
      branchId: json['branch_id'] as int,
      totalItems: json['total_items'] as int? ?? 0,
      totalUnits: json['total_units'] as int? ?? 0,
    );
  }
}