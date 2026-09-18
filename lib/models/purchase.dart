import '../core/utils/son_utils.dart';

// =============================================================
// ESTADOS DE LA COMPRA (CU33 / CU34)
// =============================================================

class OrderStatus {
  static const String pendingPayment = 'PENDING_PAYMENT';
  static const String paid = 'PAID';
  static const String processing = 'PROCESSING';
  static const String ready = 'READY';
  static const String completed = 'COMPLETED';
  static const String cancelled = 'CANCELLED';
  static const String paymentFailed = 'PAYMENT_FAILED';
}

/// Etiqueta en español para mostrar en la UI.
String orderStatusLabel(String status) {
  switch (status) {
    case OrderStatus.pendingPayment:
      return 'Pago pendiente';
    case OrderStatus.paid:
      return 'Pagada';
    case OrderStatus.processing:
      return 'En preparación';
    case OrderStatus.ready:
      return 'Lista para recoger';
    case OrderStatus.completed:
      return 'Completada';
    case OrderStatus.cancelled:
      return 'Cancelada';
    case OrderStatus.paymentFailed:
      return 'Pago fallido';
    default:
      return status;
  }
}

// =============================================================
// PAGO / MÉTODO ASOCIADOS A LA COMPRA (solo lectura desde el
// cliente: CU38/CU39 son operaciones de administración en el
// backend, `/payments/*` exige rol ADMINISTRADOR).
// =============================================================

String paymentMethodLabel(String method) {
  switch (method) {
    case 'CASH':
      return 'Efectivo';
    case 'CARD':
      return 'Tarjeta';
    case 'QR':
      return 'QR';
    case 'TRANSFER':
      return 'Transferencia';
    default:
      return method;
  }
}

String paymentStatusLabel(String status) {
  switch (status) {
    case 'PENDING':
      return 'Pendiente';
    case 'PROCESSING':
      return 'Procesando';
    case 'APPROVED':
      return 'Aprobado';
    case 'REJECTED':
      return 'Rechazado';
    case 'FAILED':
      return 'Fallido';
    case 'CANCELLED':
      return 'Cancelado';
    case 'REFUNDED':
      return 'Reembolsado';
    default:
      return status;
  }
}

// =============================================================
// REFERENCIAS SIMPLES
// =============================================================

class OrderCustomer {
  final int id;
  final String firstName;
  final String? lastName;
  final String email;
  final String? phone;
  final String? documentNumber;

  const OrderCustomer({
    required this.id,
    required this.firstName,
    required this.email,
    this.lastName,
    this.phone,
    this.documentNumber,
  });

  factory OrderCustomer.fromJson(Map<String, dynamic> json) {
    return OrderCustomer(
      id: json['id'] as int,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String?,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      documentNumber: json['document_number'] as String?,
    );
  }
}

class OrderBranch {
  final int id;
  final String name;
  final String address;
  final String? phone;
  final int cityId;

  const OrderBranch({
    required this.id,
    required this.name,
    required this.address,
    required this.cityId,
    this.phone,
  });

  factory OrderBranch.fromJson(Map<String, dynamic> json) {
    return OrderBranch(
      id: json['id'] as int,
      name: json['name'] as String,
      address: json['address'] as String,
      phone: json['phone'] as String?,
      cityId: json['city_id'] as int,
    );
  }
}

class OrderProduct {
  final int id;
  final String code;
  final String name;
  final String? brand;
  final String? coverImageUrl;

  const OrderProduct({
    required this.id,
    required this.code,
    required this.name,
    this.brand,
    this.coverImageUrl,
  });

  factory OrderProduct.fromJson(Map<String, dynamic> json) {
    return OrderProduct(
      id: json['id'] as int,
      code: json['code'] as String,
      name: json['name'] as String,
      brand: json['brand'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
    );
  }
}

class OrderSize {
  final int id;
  final String name;

  const OrderSize({required this.id, required this.name});

  factory OrderSize.fromJson(Map<String, dynamic> json) {
    return OrderSize(id: json['id'] as int, name: json['name'] as String);
  }
}

class OrderColor {
  final int id;
  final String name;
  final String? hexCode;

  const OrderColor({required this.id, required this.name, this.hexCode});

  factory OrderColor.fromJson(Map<String, dynamic> json) {
    return OrderColor(
      id: json['id'] as int,
      name: json['name'] as String,
      hexCode: json['hex_code'] as String?,
    );
  }
}

class OrderVariant {
  final int id;
  final String sku;
  final int productId;
  final int sizeId;
  final int colorId;
  final String? imageUrl;
  final OrderProduct product;
  final OrderSize size;
  final OrderColor color;

  const OrderVariant({
    required this.id,
    required this.sku,
    required this.productId,
    required this.sizeId,
    required this.colorId,
    required this.product,
    required this.size,
    required this.color,
    this.imageUrl,
  });

  /// Imagen a mostrar: la de la variante si existe, si no la portada del producto.
  String? get displayImageUrl => imageUrl ?? product.coverImageUrl;

  factory OrderVariant.fromJson(Map<String, dynamic> json) {
    return OrderVariant(
      id: json['id'] as int,
      sku: json['sku'] as String,
      productId: json['product_id'] as int,
      sizeId: json['size_id'] as int,
      colorId: json['color_id'] as int,
      imageUrl: json['image_url'] as String?,
      product: OrderProduct.fromJson(json['product'] as Map<String, dynamic>),
      size: OrderSize.fromJson(json['size'] as Map<String, dynamic>),
      color: OrderColor.fromJson(json['color'] as Map<String, dynamic>),
    );
  }
}

// =============================================================
// PRENDA DENTRO DE LA COMPRA
// =============================================================

class OrderLineItem {
  final int id;
  final int orderId;
  final int productVariantId;
  final int quantity;
  final double unitPrice;
  final double subtotal;
  final DateTime createdAt;
  final OrderVariant productVariant;

  const OrderLineItem({
    required this.id,
    required this.orderId,
    required this.productVariantId,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    required this.createdAt,
    required this.productVariant,
  });

  factory OrderLineItem.fromJson(Map<String, dynamic> json) {
    return OrderLineItem(
      id: json['id'] as int,
      orderId: json['order_id'] as int,
      productVariantId: json['product_variant_id'] as int,
      quantity: json['quantity'] as int,
      unitPrice: parseDouble(json['unit_price']),
      subtotal: parseDouble(json['subtotal']),
      createdAt: DateTime.parse(json['created_at'] as String),
      productVariant: OrderVariant.fromJson(
        json['product_variant'] as Map<String, dynamic>,
      ),
    );
  }
}

// =============================================================
// PAGO ASOCIADO (viene embebido en la orden; no hay un endpoint
// propio del cliente todavía, ver OrderService).
// =============================================================

class OrderPayment {
  final int id;
  final String paymentCode;
  final String paymentMethod;
  final String channel;
  final String? provider;
  final double amount;
  final String currency;
  final String status;
  final String? externalTransactionId;
  final DateTime? paidAt;
  final DateTime createdAt;

  const OrderPayment({
    required this.id,
    required this.paymentCode,
    required this.paymentMethod,
    required this.channel,
    required this.amount,
    required this.currency,
    required this.status,
    required this.createdAt,
    this.provider,
    this.externalTransactionId,
    this.paidAt,
  });

  factory OrderPayment.fromJson(Map<String, dynamic> json) {
    return OrderPayment(
      id: json['id'] as int,
      paymentCode: json['payment_code'] as String,
      paymentMethod: json['payment_method'] as String,
      channel: json['channel'] as String,
      provider: json['provider'] as String?,
      amount: parseDouble(json['amount']),
      currency: json['currency'] as String,
      status: json['status'] as String,
      externalTransactionId: json['external_transaction_id'] as String?,
      paidAt: json['paid_at'] != null
          ? DateTime.tryParse(json['paid_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

// =============================================================
// COMPROBANTE (CU37 - se muestra solo si ya fue emitido)
// =============================================================

class OrderReceipt {
  final int id;
  final String receiptNumber;
  final String receiptType;
  final double subtotal;
  final double discountAmount;
  final double totalAmount;
  final String paymentMethod;
  final String currency;
  final String? pdfUrl;
  final String emailStatus;
  final DateTime issuedAt;

  const OrderReceipt({
    required this.id,
    required this.receiptNumber,
    required this.receiptType,
    required this.subtotal,
    required this.discountAmount,
    required this.totalAmount,
    required this.paymentMethod,
    required this.currency,
    required this.emailStatus,
    required this.issuedAt,
    this.pdfUrl,
  });

  factory OrderReceipt.fromJson(Map<String, dynamic> json) {
    return OrderReceipt(
      id: json['id'] as int,
      receiptNumber: json['receipt_number'] as String,
      receiptType: json['receipt_type'] as String,
      subtotal: parseDouble(json['subtotal']),
      discountAmount: parseDouble(json['discount_amount']),
      totalAmount: parseDouble(json['total_amount']),
      paymentMethod: json['payment_method'] as String,
      currency: json['currency'] as String,
      pdfUrl: json['pdf_url'] as String?,
      emailStatus: json['email_status'] as String,
      issuedAt: DateTime.parse(json['issued_at'] as String),
    );
  }
}

// =============================================================
// COMPRA DIGITAL (CU33 / CU34)
// =============================================================

class Order {
  final int id;
  final String orderCode;
  final int customerId;
  final int branchId;
  final String status;
  final double subtotal;
  final double discountAmount;
  final double totalAmount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int totalItems;
  final int totalUnits;
  final OrderCustomer customer;
  final OrderBranch branch;
  final List<OrderLineItem> items;
  final List<OrderPayment> payments;
  final OrderReceipt? receipt;

  const Order({
    required this.id,
    required this.orderCode,
    required this.customerId,
    required this.branchId,
    required this.status,
    required this.subtotal,
    required this.discountAmount,
    required this.totalAmount,
    required this.createdAt,
    required this.updatedAt,
    required this.totalItems,
    required this.totalUnits,
    required this.customer,
    required this.branch,
    required this.items,
    this.payments = const [],
    this.receipt,
  });

  /// Intento de pago más reciente asociado a la compra, si existe.
  OrderPayment? get latestPayment => payments.isEmpty ? null : payments.last;

  factory Order.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    final rawPayments = json['payments'] as List<dynamic>? ?? [];

    return Order(
      id: json['id'] as int,
      orderCode: json['order_code'] as String,
      customerId: json['customer_id'] as int,
      branchId: json['branch_id'] as int,
      status: json['status'] as String,
      subtotal: parseDouble(json['subtotal']),
      discountAmount: parseDouble(json['discount_amount']),
      totalAmount: parseDouble(json['total_amount']),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      totalItems: json['total_items'] as int? ?? 0,
      totalUnits: json['total_units'] as int? ?? 0,
      customer:
      OrderCustomer.fromJson(json['customer'] as Map<String, dynamic>),
      branch: OrderBranch.fromJson(json['branch'] as Map<String, dynamic>),
      items: rawItems
          .map((e) => OrderLineItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      payments: rawPayments
          .map((e) => OrderPayment.fromJson(e as Map<String, dynamic>))
          .toList(),
      receipt: json['receipt'] != null
          ? OrderReceipt.fromJson(json['receipt'] as Map<String, dynamic>)
          : null,
    );
  }
}

class OrderPage {
  final List<Order> items;
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;

  const OrderPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
  });

  factory OrderPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];

    return OrderPage(
      items: rawItems
          .map((e) => Order.fromJson(e as Map<String, dynamic>))
          .toList(),
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? rawItems.length,
      total: json['total'] as int? ?? rawItems.length,
      totalPages: json['total_pages'] as int? ?? 1,
    );
  }
}