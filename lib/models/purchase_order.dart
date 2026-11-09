class PurchaseListResponse {
  const PurchaseListResponse({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
  });

  final List<PurchaseOrder> items;
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;

  factory PurchaseListResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];

    return PurchaseListResponse(
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map((e) => PurchaseOrder.fromJson(
                    Map<String, dynamic>.from(e),
                  ))
              .toList()
          : const [],
      page: _toInt(json['page'], 1),
      pageSize: _toInt(json['page_size'], 5),
      total: _toInt(json['total']),
      totalPages: _toInt(json['total_pages']),
    );
  }
}

class PurchaseOrder {
  const PurchaseOrder({
    required this.id,
    required this.orderCode,
    required this.status,
    required this.subtotal,
    required this.discountAmount,
    required this.totalAmount,
    required this.deliveryType,
    required this.paymentExpiresAt,
    required this.createdAt,
    required this.totalItems,
    required this.totalUnits,
    required this.branch,
    required this.items,
    required this.payments,
    this.shippingAddress,
    this.trackingCode,
    this.readyForPickupAt,
    this.deliveredAt,
    this.receipt,
  });

  final int id;
  final String orderCode;
  final String status;

  final double subtotal;
  final double discountAmount;
  final double totalAmount;

  final String deliveryType;
  final String? shippingAddress;
  final String? trackingCode;

  final DateTime paymentExpiresAt;
  final DateTime createdAt;
  final DateTime? readyForPickupAt;
  /// Fecha real de entrega/retiro; nunca inferirla de createdAt.
  final DateTime? deliveredAt;

  final int totalItems;
  final int totalUnits;

  final PurchaseBranch branch;
  final List<PurchaseItem> items;
  final List<PurchasePayment> payments;
  final PurchaseReceipt? receipt;

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) {
    final rawBranch = json['branch'];
    final rawItems = json['items'];
    final rawPayments = json['payments'];
    final rawReceipt = json['receipt'];

    return PurchaseOrder(
      id: _toInt(json['id']),
      orderCode: json['order_code']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PENDING_PAYMENT',
      subtotal: _toDouble(json['subtotal']),
      discountAmount: _toDouble(json['discount_amount']),
      totalAmount: _toDouble(json['total_amount']),
      deliveryType: json['delivery_type']?.toString() ?? 'PICKUP',
      shippingAddress: json['shipping_address']?.toString(),
      trackingCode: json['tracking_code']?.toString(),
      paymentExpiresAt:
          _toDate(json['payment_expires_at']) ?? DateTime.now(),
      createdAt: _toDate(json['created_at']) ?? DateTime.now(),
      readyForPickupAt: _toDate(json['ready_for_pickup_at']),
      deliveredAt: _toDate(json['delivered_at'] ?? json['delivered_at_utc'] ?? json['handed_over_at']),
      totalItems: _toInt(json['total_items']),
      totalUnits: _toInt(json['total_units']),
      branch: rawBranch is Map
          ? PurchaseBranch.fromJson(
              Map<String, dynamic>.from(rawBranch),
            )
          : const PurchaseBranch(
              id: 0,
              name: 'Sucursal',
              address: '',
            ),
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map((e) => PurchaseItem.fromJson(
                    Map<String, dynamic>.from(e),
                  ))
              .toList()
          : const [],
      payments: rawPayments is List
          ? rawPayments
              .whereType<Map>()
              .map((e) => PurchasePayment.fromJson(
                    Map<String, dynamic>.from(e),
                  ))
              .toList()
          : const [],
      receipt: rawReceipt is Map
          ? PurchaseReceipt.fromJson(
              Map<String, dynamic>.from(rawReceipt),
            )
          : null,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'PENDING_PAYMENT':
        return 'Pendiente de pago';
      case 'PAYMENT_FAILED':
        return 'Pago fallido';
      case 'PAID':
        return 'Pagada';
      case 'PREPARING':
        return 'En preparación';
      case 'READY_FOR_PICKUP':
        return 'Lista para recoger';
      case 'SHIPPED':
        return 'Enviada';
      case 'DELIVERED':
        return 'Entregada';
      case 'COMPLETED':
        return 'Finalizada';
      case 'CANCELLED':
        return 'Cancelada';
      case 'REFUNDED':
        return 'Reembolsada';
      default:
        return status;
    }
  }

  String get deliveryLabel =>
      deliveryType == 'DELIVERY'
          ? 'Envío a domicilio'
          : 'Recojo en sucursal';

  bool get isReadyForPickup => status == 'READY_FOR_PICKUP';

  bool get canPay =>
      ['PENDING_PAYMENT', 'PAYMENT_FAILED'].contains(status) &&
      paymentExpiresAt.isAfter(DateTime.now());

  String get paymentActionLabel {
    final hasActive = payments.reversed.any(
      (p) => ['PENDING', 'PROCESSING'].contains(p.status),
    );

    if (hasActive) return 'Continuar pago';
    if (status == 'PAYMENT_FAILED') return 'Reintentar pago';
    return 'Pagar ahora';
  }

  String paymentExpirationLabel([DateTime? now]) {
    if (!['PENDING_PAYMENT', 'PAYMENT_FAILED'].contains(status)) {
      return '';
    }

    final remaining =
        paymentExpiresAt.difference(now ?? DateTime.now());

    if (remaining <= Duration.zero) {
      return 'Tiempo de pago vencido';
    }

    final minutes = remaining.inMinutes + 1;

    if (minutes < 60) {
      return 'Vence en $minutes min';
    }

    final hours = minutes ~/ 60;
    final rest = minutes % 60;

    return rest == 0
        ? 'Vence en $hours h'
        : 'Vence en $hours h $rest min';
  }

  bool paymentExpiringSoon([DateTime? now]) {
    if (!['PENDING_PAYMENT', 'PAYMENT_FAILED'].contains(status)) {
      return false;
    }

    final remaining =
        paymentExpiresAt.difference(now ?? DateTime.now());

    return remaining > Duration.zero &&
        remaining <= const Duration(minutes: 10);
  }
}

class PurchaseBranch {
  const PurchaseBranch({
    required this.id,
    required this.name,
    required this.address,
  });

  final int id;
  final String name;
  final String address;

  factory PurchaseBranch.fromJson(Map<String, dynamic> json) {
    return PurchaseBranch(
      id: _toInt(json['id']),
      name: json['name']?.toString() ?? 'Sucursal',
      address: json['address']?.toString() ?? '',
    );
  }
}

class PurchaseItem {
  const PurchaseItem({
    required this.id,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    required this.variant,
  });

  final int id;
  final int quantity;
  final double unitPrice;
  final double subtotal;
  final PurchaseVariant variant;

  factory PurchaseItem.fromJson(Map<String, dynamic> json) {
    final raw = json['product_variant'];

    return PurchaseItem(
      id: _toInt(json['id']),
      quantity: _toInt(json['quantity']),
      unitPrice: _toDouble(json['unit_price']),
      subtotal: _toDouble(json['subtotal']),
      variant: raw is Map
          ? PurchaseVariant.fromJson(
              Map<String, dynamic>.from(raw),
            )
          : const PurchaseVariant(
              sku: '',
              imageUrl: null,
              productName: 'Producto',
              coverImageUrl: null,
              size: '',
              color: '',
            ),
    );
  }
}

class PurchaseVariant {
  const PurchaseVariant({
    required this.sku,
    required this.imageUrl,
    required this.productName,
    required this.coverImageUrl,
    required this.size,
    required this.color,
  });

  final String sku;
  final String? imageUrl;
  final String productName;
  final String? coverImageUrl;
  final String size;
  final String color;

  factory PurchaseVariant.fromJson(Map<String, dynamic> json) {
    final product = json['product'];
    final size = json['size'];
    final color = json['color'];

    return PurchaseVariant(
      sku: json['sku']?.toString() ?? '',
      imageUrl: json['image_url']?.toString(),
      productName: product is Map
          ? product['name']?.toString() ?? 'Producto'
          : 'Producto',
      coverImageUrl: product is Map
          ? product['cover_image_url']?.toString()
          : null,
      size: size is Map ? size['name']?.toString() ?? '' : '',
      color: color is Map ? color['name']?.toString() ?? '' : '',
    );
  }

  String? get displayImageUrl {
    final own = imageUrl?.trim();
    if (own != null && own.isNotEmpty) return own;

    final cover = coverImageUrl?.trim();
    return cover != null && cover.isNotEmpty ? cover : null;
  }
}

class PurchasePayment {
  const PurchasePayment({
    required this.id,
    required this.paymentCode,
    required this.paymentMethod,
    required this.status,
    required this.amount,
    this.provider,
  });

  final int id;
  final String paymentCode;
  final String paymentMethod;
  final String status;
  final double amount;
  final String? provider;

  factory PurchasePayment.fromJson(Map<String, dynamic> json) {
    return PurchasePayment(
      id: _toInt(json['id']),
      paymentCode: json['payment_code']?.toString() ?? '',
      paymentMethod: json['payment_method']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PENDING',
      amount: _toDouble(json['amount']),
      provider: json['provider']?.toString(),
    );
  }

  String get statusLabel {
    switch (status) {
      case 'APPROVED':
        return 'Aprobado';
      case 'PROCESSING':
        return 'Procesando';
      case 'PENDING':
        return 'Pendiente';
      case 'FAILED':
        return 'Fallido';
      case 'REJECTED':
        return 'Rechazado';
      case 'CANCELLED':
        return 'Cancelado';
      case 'REFUNDED':
        return 'Reembolsado';
      default:
        return status;
    }
  }
}

class PurchaseReceipt {
  const PurchaseReceipt({
    required this.receiptNumber,
    required this.receiptType,
    required this.emailStatus,
    this.pdfUrl,
  });

  final String receiptNumber;
  final String receiptType;
  final String emailStatus;
  final String? pdfUrl;

  factory PurchaseReceipt.fromJson(Map<String, dynamic> json) {
    return PurchaseReceipt(
      receiptNumber: json['receipt_number']?.toString() ?? '',
      receiptType: json['receipt_type']?.toString() ?? '',
      emailStatus: json['email_status']?.toString() ?? '',
      pdfUrl: json['pdf_url']?.toString(),
    );
  }
}

int _toInt(dynamic value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
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
