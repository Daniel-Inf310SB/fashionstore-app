class PosPurchaseList {
  const PosPurchaseList({
    required this.items,
    required this.total,
    required this.page,
    required this.totalPages,
  });

  final List<PosPurchase> items;
  final int total;
  final int page;
  final int totalPages;

  factory PosPurchaseList.fromJson(Map<String, dynamic> json) => PosPurchaseList(
        items: ((json['items'] as List?) ?? const [])
            .whereType<Map>()
            .map((x) => PosPurchase.fromJson(Map<String, dynamic>.from(x)))
            .toList(),
        total: (json['total'] as num?)?.toInt() ?? 0,
        page: (json['page'] as num?)?.toInt() ?? 1,
        totalPages: (json['total_pages'] as num?)?.toInt() ?? 0,
      );
}

class PosPurchase {
  const PosPurchase({
    required this.id,
    required this.code,
    required this.status,
    required this.amount,
    required this.date,
    required this.branch,
    required this.units,
    required this.paymentMethod,
    required this.items,
  });

  final int id;
  final String code;
  final String status;
  final double amount;
  final DateTime date;
  final String branch;
  final int units;
  final String? paymentMethod;
  final List<PosPurchaseItem> items;

  factory PosPurchase.fromJson(Map<String, dynamic> json) {
    final branch = json['branch'];
    final payments = (json['payments'] as List?) ?? const [];
    final approved = payments.whereType<Map>().where((p) => p['status'] == 'APPROVED');
    final payment = approved.isNotEmpty ? approved.first : null;
    return PosPurchase(
      id: (json['id'] as num?)?.toInt() ?? 0,
      code: json['sale_code']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      amount: double.tryParse('${json['total_amount'] ?? 0}') ?? 0,
      date: DateTime.tryParse('${json['created_at'] ?? ''}') ?? DateTime.now(),
      branch: branch is Map ? (branch['name']?.toString() ?? 'Sucursal') : 'Sucursal',
      units: (json['total_units'] as num?)?.toInt() ?? 0,
      paymentMethod: payment?['payment_method']?.toString(),
      items: ((json['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((i) => PosPurchaseItem.fromJson(Map<String, dynamic>.from(i)))
          .toList(),
    );
  }

  String get paymentLabel => switch (paymentMethod) {
        'CASH' => 'Efectivo',
        'CARD' => 'Tarjeta',
        'QR' => 'QR',
        'TRANSFER' => 'Transferencia',
        _ => 'Sin método registrado',
      };

  String get statusLabel => switch (status) {
        'PAID' => 'Pagada',
        'REFUNDED' => 'Reembolsada',
        'CANCELLED' => 'Cancelada',
        'PENDING' => 'Pendiente',
        _ => status,
      };
}

class PosPurchaseItem {
  const PosPurchaseItem({
    required this.id,
    required this.productVariantId,
    required this.name,
    required this.sku,
    required this.size,
    required this.color,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.imageUrl,
  });

  final int id;
  final int productVariantId;
  final String name;
  final String sku;
  final String size;
  final String color;
  final int quantity;
  final double unitPrice;
  final double subtotal;
  final String? imageUrl;

  factory PosPurchaseItem.fromJson(Map<String, dynamic> json) {
    final variant = json['product_variant'];
    final product = variant is Map ? variant['product'] : null;
    final size = variant is Map ? variant['size'] : null;
    final color = variant is Map ? variant['color'] : null;
    final image = json['image_url'] ??
        (variant is Map ? variant['image_url'] : null) ??
        (product is Map ? product['cover_image_url'] : null);
    final quantity = (json['quantity'] as num?)?.toInt() ?? 0;
    final unitPrice = double.tryParse('${json['unit_price'] ?? 0}') ?? 0;
    return PosPurchaseItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      productVariantId: (json['product_variant_id'] as num?)?.toInt() ??
          (variant is Map ? (variant['id'] as num?)?.toInt() ?? 0 : 0),
      name: product is Map ? (product['name']?.toString() ?? 'Producto') : 'Producto',
      sku: variant is Map ? (variant['sku']?.toString() ?? '') : '',
      size: size is Map ? (size['name']?.toString() ?? '') : '',
      color: color is Map ? (color['name']?.toString() ?? '') : '',
      quantity: quantity,
      unitPrice: unitPrice,
      subtotal: double.tryParse('${json['subtotal'] ?? unitPrice * quantity}') ?? 0,
      imageUrl: image?.toString(),
    );
  }
}
