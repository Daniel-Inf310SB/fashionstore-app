import '../core/utils/son_utils.dart';

// =============================================================
// ESTADOS
// =============================================================

class ReservationStatus {
  static const String pending = 'PENDING';
  static const String confirmed = 'CONFIRMED';
  static const String preparing = 'PREPARING';
  static const String ready = 'READY';
  static const String attended = 'ATTENDED';
  static const String completed = 'COMPLETED';
  static const String cancelled = 'CANCELLED';
  static const String expired = 'EXPIRED';
}

/// Etiqueta en español para mostrar en la UI.
String reservationStatusLabel(String status) {
  switch (status) {
    case ReservationStatus.pending:
      return 'Pendiente';
    case ReservationStatus.confirmed:
      return 'Confirmada';
    case ReservationStatus.preparing:
      return 'En preparación';
    case ReservationStatus.ready:
      return 'Lista para recoger';
    case ReservationStatus.attended:
      return 'Atendida';
    case ReservationStatus.completed:
      return 'Completada';
    case ReservationStatus.cancelled:
      return 'Cancelada';
    case ReservationStatus.expired:
      return 'Expirada';
    default:
      return status;
  }
}

// =============================================================
// REFERENCIAS SIMPLES
// =============================================================

class ReservationCustomer {
  final int id;
  final String firstName;
  final String? lastName;
  final String email;
  final String? phone;

  const ReservationCustomer({
    required this.id,
    required this.firstName,
    required this.email,
    this.lastName,
    this.phone,
  });

  factory ReservationCustomer.fromJson(Map<String, dynamic> json) {
    return ReservationCustomer(
      id: json['id'] as int,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String?,
      email: json['email'] as String,
      phone: json['phone'] as String?,
    );
  }
}

class ReservationBranch {
  final int id;
  final String name;
  final String address;
  final String? phone;
  final int cityId;

  const ReservationBranch({
    required this.id,
    required this.name,
    required this.address,
    required this.cityId,
    this.phone,
  });

  factory ReservationBranch.fromJson(Map<String, dynamic> json) {
    return ReservationBranch(
      id: json['id'] as int,
      name: json['name'] as String,
      address: json['address'] as String,
      phone: json['phone'] as String?,
      cityId: json['city_id'] as int,
    );
  }
}

class ReservationProduct {
  final int id;
  final String code;
  final String name;
  final String? brand;
  final String? coverImageUrl;

  const ReservationProduct({
    required this.id,
    required this.code,
    required this.name,
    this.brand,
    this.coverImageUrl,
  });

  factory ReservationProduct.fromJson(Map<String, dynamic> json) {
    return ReservationProduct(
      id: json['id'] as int,
      code: json['code'] as String,
      name: json['name'] as String,
      brand: json['brand'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
    );
  }
}

class ReservationSize {
  final int id;
  final String name;

  const ReservationSize({required this.id, required this.name});

  factory ReservationSize.fromJson(Map<String, dynamic> json) {
    return ReservationSize(id: json['id'] as int, name: json['name'] as String);
  }
}

class ReservationColor {
  final int id;
  final String name;
  final String? hexCode;

  const ReservationColor({required this.id, required this.name, this.hexCode});

  factory ReservationColor.fromJson(Map<String, dynamic> json) {
    return ReservationColor(
      id: json['id'] as int,
      name: json['name'] as String,
      hexCode: json['hex_code'] as String?,
    );
  }
}

class ReservationVariant {
  final int id;
  final String sku;
  final int productId;
  final int sizeId;
  final int colorId;
  final String? imageUrl;
  final ReservationProduct product;
  final ReservationSize size;
  final ReservationColor color;

  const ReservationVariant({
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

  String? get displayImageUrl => imageUrl ?? product.coverImageUrl;

  factory ReservationVariant.fromJson(Map<String, dynamic> json) {
    return ReservationVariant(
      id: json['id'] as int,
      sku: json['sku'] as String,
      productId: json['product_id'] as int,
      sizeId: json['size_id'] as int,
      colorId: json['color_id'] as int,
      imageUrl: json['image_url'] as String?,
      product:
      ReservationProduct.fromJson(json['product'] as Map<String, dynamic>),
      size: ReservationSize.fromJson(json['size'] as Map<String, dynamic>),
      color: ReservationColor.fromJson(json['color'] as Map<String, dynamic>),
    );
  }
}

// =============================================================
// PRENDA DENTRO DE LA RESERVA
// =============================================================

class ReservationLineItem {
  final int id;
  final int reservationId;
  final int productVariantId;
  final int quantity;
  final double unitPrice;
  final double subtotal;
  final String status;
  final ReservationVariant productVariant;

  const ReservationLineItem({
    required this.id,
    required this.reservationId,
    required this.productVariantId,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    required this.status,
    required this.productVariant,
  });

  factory ReservationLineItem.fromJson(Map<String, dynamic> json) {
    return ReservationLineItem(
      id: json['id'] as int,
      reservationId: json['reservation_id'] as int,
      productVariantId: json['product_variant_id'] as int,
      quantity: json['quantity'] as int,
      unitPrice: parseDouble(json['unit_price']),
      subtotal: parseDouble(json['subtotal']),
      status: json['status'] as String,
      productVariant: ReservationVariant.fromJson(
        json['product_variant'] as Map<String, dynamic>,
      ),
    );
  }
}

// =============================================================
// RESERVA
// =============================================================

class Reservation {
  final int id;
  final String reservationCode;
  final int customerId;
  final int branchId;
  final String status;
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
  final ReservationCustomer customer;
  final ReservationBranch branch;
  final List<ReservationLineItem> items;

  const Reservation({
    required this.id,
    required this.reservationCode,
    required this.customerId,
    required this.branchId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.isActive,
    required this.canCancel,
    required this.totalItems,
    required this.totalUnits,
    required this.totalAmount,
    required this.customer,
    required this.branch,
    required this.items,
    this.notes,
    this.expiresAt,
    this.preparedAt,
    this.attendedAt,
    this.completedAt,
    this.cancelledAt,
  });

  factory Reservation.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];

    DateTime? parseDate(String? key) =>
        json[key] != null ? DateTime.tryParse(json[key] as String) : null;

    return Reservation(
      id: json['id'] as int,
      reservationCode: json['reservation_code'] as String,
      customerId: json['customer_id'] as int,
      branchId: json['branch_id'] as int,
      status: json['status'] as String,
      notes: json['notes'] as String?,
      expiresAt: parseDate('expires_at'),
      preparedAt: parseDate('prepared_at'),
      attendedAt: parseDate('attended_at'),
      completedAt: parseDate('completed_at'),
      cancelledAt: parseDate('cancelled_at'),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isActive: json['is_active'] as bool? ?? false,
      canCancel: json['can_cancel'] as bool? ?? false,
      totalItems: json['total_items'] as int? ?? 0,
      totalUnits: json['total_units'] as int? ?? 0,
      totalAmount: parseDouble(json['total_amount']),
      customer:
      ReservationCustomer.fromJson(json['customer'] as Map<String, dynamic>),
      branch: ReservationBranch.fromJson(json['branch'] as Map<String, dynamic>),
      items: rawItems
          .map((e) => ReservationLineItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ReservationPage {
  final List<Reservation> items;
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;

  const ReservationPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
  });

  factory ReservationPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];

    return ReservationPage(
      items: rawItems
          .map((e) => Reservation.fromJson(e as Map<String, dynamic>))
          .toList(),
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? rawItems.length,
      total: json['total'] as int? ?? rawItems.length,
      totalPages: json['total_pages'] as int? ?? 1,
    );
  }
}

class ReservationCount {
  final int totalAll;
  final int totalActive;
  final int pending;
  final int confirmed;
  final int preparing;
  final int ready;
  final int attended;

  const ReservationCount({
    required this.totalAll,
    required this.totalActive,
    required this.pending,
    required this.confirmed,
    required this.preparing,
    required this.ready,
    required this.attended,
  });

  factory ReservationCount.fromJson(Map<String, dynamic> json) {
    return ReservationCount(
      totalAll: json['total_all'] as int? ?? 0,
      totalActive: json['total_active'] as int? ?? 0,
      pending: json['pending'] as int? ?? 0,
      confirmed: json['confirmed'] as int? ?? 0,
      preparing: json['preparing'] as int? ?? 0,
      ready: json['ready'] as int? ?? 0,
      attended: json['attended'] as int? ?? 0,
    );
  }
}