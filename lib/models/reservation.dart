typedef ReservationStatus = String;

class ReservationListPage {
  const ReservationListPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
  });

  final List<Reservation> items;
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;

  factory ReservationListPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];

    return ReservationListPage(
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map(
                (item) => Reservation.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
          : <Reservation>[],
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['page_size'] as num?)?.toInt() ?? 6,
      total: (json['total'] as num?)?.toInt() ?? 0,
      totalPages: (json['total_pages'] as num?)?.toInt() ?? 0,
    );
  }
}

class ReservationCount {
  const ReservationCount({
    required this.totalAll,
    required this.totalActive,
    required this.pending,
    required this.confirmed,
    required this.preparing,
    required this.ready,
    required this.attended,
  });

  final int totalAll;
  final int totalActive;
  final int pending;
  final int confirmed;
  final int preparing;
  final int ready;
  final int attended;

  factory ReservationCount.fromJson(Map<String, dynamic> json) {
    return ReservationCount(
      totalAll: (json['total_all'] as num?)?.toInt() ?? 0,
      totalActive: (json['total_active'] as num?)?.toInt() ?? 0,
      pending: (json['pending'] as num?)?.toInt() ?? 0,
      confirmed: (json['confirmed'] as num?)?.toInt() ?? 0,
      preparing: (json['preparing'] as num?)?.toInt() ?? 0,
      ready: (json['ready'] as num?)?.toInt() ?? 0,
      attended: (json['attended'] as num?)?.toInt() ?? 0,
    );
  }
}

class Reservation {
  const Reservation({
    required this.id,
    required this.reservationCode,
    required this.customerId,
    required this.branchId,
    required this.status,
    required this.isActive,
    required this.canCancel,
    required this.totalItems,
    required this.totalUnits,
    required this.totalAmount,
    required this.branch,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
    this.notes,
    this.expiresAt,
    this.preparedAt,
    this.attendedAt,
    this.completedAt,
    this.cancelledAt,
  });

  final int id;
  final String reservationCode;
  final int customerId;
  final int branchId;
  final ReservationStatus status;
  final String? notes;
  final DateTime? expiresAt;
  final DateTime? preparedAt;
  final DateTime? attendedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  final bool isActive;
  final bool canCancel;

  final int totalItems;
  final int totalUnits;
  final double totalAmount;

  final ReservationBranch branch;
  final List<ReservationItem> items;

  factory Reservation.fromJson(Map<String, dynamic> json) {
    final rawBranch = json['branch'];
    final rawItems = json['items'];

    return Reservation(
      id: (json['id'] as num?)?.toInt() ?? 0,
      reservationCode: json['reservation_code']?.toString() ?? '',
      customerId: (json['customer_id'] as num?)?.toInt() ?? 0,
      branchId: (json['branch_id'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'PENDING',
      notes: json['notes']?.toString(),
      expiresAt: _date(json['expires_at']),
      preparedAt: _date(json['prepared_at']),
      attendedAt: _date(json['attended_at']),
      completedAt: _date(json['completed_at']),
      cancelledAt: _date(json['cancelled_at']),
      createdAt: _date(json['created_at']) ?? DateTime.now(),
      updatedAt: _date(json['updated_at']) ?? DateTime.now(),
      isActive: json['is_active'] == true,
      canCancel: json['can_cancel'] == true,
      totalItems: (json['total_items'] as num?)?.toInt() ?? 0,
      totalUnits: (json['total_units'] as num?)?.toInt() ?? 0,
      totalAmount: _double(json['total_amount']),
      branch: rawBranch is Map
          ? ReservationBranch.fromJson(
              Map<String, dynamic>.from(rawBranch),
            )
          : const ReservationBranch(
              id: 0,
              name: 'Sucursal',
              address: '',
              cityId: 0,
            ),
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map(
                (item) => ReservationItem.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
          : const [],
    );
  }

  bool get expirationRelevant =>
      status == 'CONFIRMED' ||
      status == 'PREPARING' ||
      status == 'READY';

  bool get expiredLocally {
    if (status == 'EXPIRED') return true;
    final value = expiresAt;
    if (value == null || !expirationRelevant) return false;
    return !value.isAfter(DateTime.now());
  }

  bool get expiringSoon {
    final value = expiresAt;
    if (value == null || !expirationRelevant) return false;

    final remaining = value.difference(DateTime.now());
    return !remaining.isNegative &&
        remaining <= const Duration(hours: 2);
  }

  String expirationLabel([DateTime? now]) {
    if (status == 'EXPIRED') return 'Reserva vencida';

    final value = expiresAt;
    if (value == null) {
      return status == 'PENDING'
          ? 'El plazo todavía no comenzó'
          : 'Sin fecha de vencimiento';
    }

    final reference = now ?? DateTime.now();
    final remaining = value.difference(reference);

    if (remaining <= Duration.zero) {
      return 'Reserva vencida';
    }

    final minutes = remaining.inMinutes + 1;

    if (minutes < 60) {
      return 'Vence en $minutes min';
    }

    final hours = minutes ~/ 60;
    final restMinutes = minutes % 60;

    if (hours < 24) {
      return restMinutes == 0
          ? 'Vence en $hours h'
          : 'Vence en $hours h $restMinutes min';
    }

    final days = hours ~/ 24;
    final restHours = hours % 24;

    return restHours == 0
        ? 'Vence en $days d'
        : 'Vence en $days d $restHours h';
  }

  String get statusLabel {
    switch (status) {
      case 'PENDING':
        return 'Pendiente';
      case 'CONFIRMED':
        return 'Confirmada';
      case 'PREPARING':
        return 'En preparación';
      case 'READY':
        return 'Lista para recoger';
      case 'ATTENDED':
        return 'Atendida';
      case 'COMPLETED':
        return 'Completada';
      case 'CANCELLED':
        return 'Cancelada';
      case 'EXPIRED':
        return 'Vencida';
      default:
        return status;
    }
  }
}

class ReservationBranch {
  const ReservationBranch({
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

  factory ReservationBranch.fromJson(Map<String, dynamic> json) {
    return ReservationBranch(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? 'Sucursal',
      address: json['address']?.toString() ?? '',
      phone: json['phone']?.toString(),
      cityId: (json['city_id'] as num?)?.toInt() ?? 0,
    );
  }
}

class ReservationItem {
  const ReservationItem({
    required this.id,
    required this.reservationId,
    required this.productVariantId,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    required this.status,
    required this.variant,
  });

  final int id;
  final int reservationId;
  final int productVariantId;
  final int quantity;
  final double unitPrice;
  final double subtotal;
  final String status;
  final ReservationVariant variant;

  factory ReservationItem.fromJson(Map<String, dynamic> json) {
    final rawVariant = json['product_variant'];

    return ReservationItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      reservationId: (json['reservation_id'] as num?)?.toInt() ?? 0,
      productVariantId:
          (json['product_variant_id'] as num?)?.toInt() ?? 0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: _double(json['unit_price']),
      subtotal: _double(json['subtotal']),
      status: json['status']?.toString() ?? 'PENDING',
      variant: rawVariant is Map
          ? ReservationVariant.fromJson(
              Map<String, dynamic>.from(rawVariant),
            )
          : const ReservationVariant(
              id: 0,
              sku: '',
              product: ReservationProduct(
                id: 0,
                code: '',
                name: 'Producto',
              ),
              size: ReservationTag(id: 0, name: ''),
              color: ReservationColor(id: 0, name: ''),
            ),
    );
  }
}

class ReservationVariant {
  const ReservationVariant({
    required this.id,
    required this.sku,
    required this.product,
    required this.size,
    required this.color,
    this.imageUrl,
  });

  final int id;
  final String sku;
  final String? imageUrl;
  final ReservationProduct product;
  final ReservationTag size;
  final ReservationColor color;

  factory ReservationVariant.fromJson(Map<String, dynamic> json) {
    final rawProduct = json['product'];
    final rawSize = json['size'];
    final rawColor = json['color'];

    return ReservationVariant(
      id: (json['id'] as num?)?.toInt() ?? 0,
      sku: json['sku']?.toString() ?? '',
      imageUrl: json['image_url']?.toString(),
      product: rawProduct is Map
          ? ReservationProduct.fromJson(
              Map<String, dynamic>.from(rawProduct),
            )
          : const ReservationProduct(
              id: 0,
              code: '',
              name: 'Producto',
            ),
      size: rawSize is Map
          ? ReservationTag.fromJson(
              Map<String, dynamic>.from(rawSize),
            )
          : const ReservationTag(id: 0, name: ''),
      color: rawColor is Map
          ? ReservationColor.fromJson(
              Map<String, dynamic>.from(rawColor),
            )
          : const ReservationColor(id: 0, name: ''),
    );
  }

  String? get displayImageUrl =>
      imageUrl?.trim().isNotEmpty == true
          ? imageUrl
          : product.coverImageUrl;
}

class ReservationProduct {
  const ReservationProduct({
    required this.id,
    required this.code,
    required this.name,
    this.brand,
    this.coverImageUrl,
  });

  final int id;
  final String code;
  final String name;
  final String? brand;
  final String? coverImageUrl;

  factory ReservationProduct.fromJson(Map<String, dynamic> json) {
    return ReservationProduct(
      id: (json['id'] as num?)?.toInt() ?? 0,
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Producto',
      brand: json['brand']?.toString(),
      coverImageUrl: json['cover_image_url']?.toString(),
    );
  }
}

class ReservationTag {
  const ReservationTag({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  factory ReservationTag.fromJson(Map<String, dynamic> json) {
    return ReservationTag(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
    );
  }
}

class ReservationColor extends ReservationTag {
  const ReservationColor({
    required super.id,
    required super.name,
    this.hexCode,
  });

  final String? hexCode;

  factory ReservationColor.fromJson(Map<String, dynamic> json) {
    return ReservationColor(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      hexCode: json['hex_code']?.toString(),
    );
  }
}

class ReservationItemRequest {
  const ReservationItemRequest({
    required this.productVariantId,
    required this.quantity,
  });

  final int productVariantId;
  final int quantity;

  Map<String, dynamic> toJson() {
    return {
      'product_variant_id': productVariantId,
      'quantity': quantity,
    };
  }
}

DateTime? _date(dynamic value) {
  final raw = value?.toString();
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}

double _double(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
