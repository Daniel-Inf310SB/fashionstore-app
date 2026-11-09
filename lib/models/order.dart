class CheckoutPreview {
  const CheckoutPreview({
    required this.cartId,
    required this.branchId,
    required this.branchName,
    required this.items,
    required this.totalItems,
    required this.totalUnits,
    required this.subtotal,
    required this.discountAmount,
    required this.totalAmount,
    required this.currency,
  });

  final int cartId;
  final int branchId;
  final String branchName;
  final List<CheckoutItem> items;
  final int totalItems;
  final int totalUnits;
  final double subtotal;
  final double discountAmount;
  final double totalAmount;
  final String currency;

  factory CheckoutPreview.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];

    return CheckoutPreview(
      cartId: (json['cart_id'] as num?)?.toInt() ?? 0,
      branchId: (json['branch_id'] as num?)?.toInt() ?? 0,
      branchName: json['branch_name']?.toString() ?? '',
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map(
                (item) => CheckoutItem.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
          : const [],
      totalItems: (json['total_items'] as num?)?.toInt() ?? 0,
      totalUnits: (json['total_units'] as num?)?.toInt() ?? 0,
      subtotal: _toDouble(json['subtotal']),
      discountAmount: _toDouble(json['discount_amount']),
      totalAmount: _toDouble(json['total_amount']),
      currency: json['currency']?.toString() ?? 'BOB',
    );
  }
}

class CheckoutItem {
  const CheckoutItem({
    required this.productVariantId,
    required this.sku,
    required this.productName,
    required this.size,
    required this.color,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  final int productVariantId;
  final String sku;
  final String productName;
  final String size;
  final String color;
  final int quantity;
  final double unitPrice;
  final double subtotal;

  factory CheckoutItem.fromJson(Map<String, dynamic> json) {
    return CheckoutItem(
      productVariantId:
          (json['product_variant_id'] as num?)?.toInt() ?? 0,
      sku: json['sku']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? 'Producto',
      size: json['size']?.toString() ?? '',
      color: json['color']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: _toDouble(json['unit_price']),
      subtotal: _toDouble(json['subtotal']),
    );
  }
}

class CustomerOrder {
  const CustomerOrder({
    required this.id,
    required this.orderCode,
    required this.customerId,
    required this.branchId,
    required this.status,
    required this.subtotal,
    required this.discountAmount,
    required this.totalAmount,
    required this.deliveryType,
    required this.paymentExpiresAt,
    required this.createdAt,
    required this.updatedAt,
    required this.totalItems,
    required this.totalUnits,
    required this.branch,
    required this.items,
    this.shippingAddress,
    this.trackingCode,
    this.paidAt,
    this.readyForPickupAt,
    this.shippedAt,
    this.deliveredAt,
    this.completedAt,
    this.cancelledAt,
  });

  final int id;
  final String orderCode;
  final int customerId;
  final int branchId;
  final String status;

  final double subtotal;
  final double discountAmount;
  final double totalAmount;

  final String deliveryType;
  final String? shippingAddress;
  final String? trackingCode;

  final DateTime? paidAt;
  final DateTime? readyForPickupAt;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;

  final DateTime paymentExpiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  final int totalItems;
  final int totalUnits;

  final OrderBranch branch;
  final List<OrderItem> items;

  factory CustomerOrder.fromJson(Map<String, dynamic> json) {
    final rawBranch = json['branch'];
    final rawItems = json['items'];

    return CustomerOrder(
      id: (json['id'] as num?)?.toInt() ?? 0,
      orderCode: json['order_code']?.toString() ?? '',
      customerId: (json['customer_id'] as num?)?.toInt() ?? 0,
      branchId: (json['branch_id'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'PENDING_PAYMENT',
      subtotal: _toDouble(json['subtotal']),
      discountAmount: _toDouble(json['discount_amount']),
      totalAmount: _toDouble(json['total_amount']),
      deliveryType: json['delivery_type']?.toString() ?? 'PICKUP',
      shippingAddress: json['shipping_address']?.toString(),
      trackingCode: json['tracking_code']?.toString(),
      paidAt: _toDate(json['paid_at']),
      readyForPickupAt: _toDate(json['ready_for_pickup_at']),
      shippedAt: _toDate(json['shipped_at']),
      deliveredAt: _toDate(json['delivered_at']),
      completedAt: _toDate(json['completed_at']),
      cancelledAt: _toDate(json['cancelled_at']),
      paymentExpiresAt:
          _toDate(json['payment_expires_at']) ?? DateTime.now(),
      createdAt: _toDate(json['created_at']) ?? DateTime.now(),
      updatedAt: _toDate(json['updated_at']) ?? DateTime.now(),
      totalItems: (json['total_items'] as num?)?.toInt() ?? 0,
      totalUnits: (json['total_units'] as num?)?.toInt() ?? 0,
      branch: rawBranch is Map
          ? OrderBranch.fromJson(Map<String, dynamic>.from(rawBranch))
          : const OrderBranch(
              id: 0,
              name: 'Sucursal',
              address: '',
              cityId: 0,
            ),
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map(
                (item) => OrderItem.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
          : const [],
    );
  }

  bool get pendingPayment =>
      status == 'PENDING_PAYMENT' || status == 'PAYMENT_FAILED';

  String get deliveryLabel =>
      deliveryType == 'DELIVERY' ? 'Envío a domicilio' : 'Recoger en sucursal';
}

class OrderBranch {
  const OrderBranch({
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

  factory OrderBranch.fromJson(Map<String, dynamic> json) {
    return OrderBranch(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? 'Sucursal',
      address: json['address']?.toString() ?? '',
      phone: json['phone']?.toString(),
      cityId: (json['city_id'] as num?)?.toInt() ?? 0,
    );
  }
}

class OrderItem {
  const OrderItem({
    required this.id,
    required this.orderId,
    required this.productVariantId,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  final int id;
  final int orderId;
  final int productVariantId;
  final int quantity;
  final double unitPrice;
  final double subtotal;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      orderId: (json['order_id'] as num?)?.toInt() ?? 0,
      productVariantId:
          (json['product_variant_id'] as num?)?.toInt() ?? 0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: _toDouble(json['unit_price']),
      subtotal: _toDouble(json['subtotal']),
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
