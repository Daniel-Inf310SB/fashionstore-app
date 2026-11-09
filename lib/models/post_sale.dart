class PostSaleEligibility {
  const PostSaleEligibility({
    required this.sourceChannel,
    required this.sourceId,
    required this.sourceCode,
    required this.eligible,
    required this.reason,
    required this.branchId,
    required this.currency,
    required this.items,
    this.returnDeadline,
    this.returnWindowDays = 7,
  });

  final String sourceChannel;
  final int sourceId;
  final String? sourceCode;
  final bool eligible;
  final String? reason;
  final int branchId;
  final String currency;
  final List<PostSaleEligibleItem> items;
  final DateTime? returnDeadline;
  final int returnWindowDays;

  factory PostSaleEligibility.fromJson(Map<String, dynamic> json) {
    return PostSaleEligibility(
      sourceChannel: json['source_channel']?.toString() ?? '',
      sourceId: _psInt(json['source_id']),
      sourceCode: json['source_code']?.toString(),
      eligible: json['eligible'] == true,
      reason: json['reason']?.toString(),
      branchId: _psInt(json['branch_id']),
      currency: json['currency']?.toString() ?? 'BOB',
      returnDeadline: _psDate(json['return_deadline']),
      returnWindowDays: _psInt(json['return_window_days'], 7),
      items: (json['items'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => PostSaleEligibleItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class PostSaleEligibleItem {
  const PostSaleEligibleItem({
    required this.sourceItemId,
    required this.purchasedQuantity,
    required this.alreadyCommittedQuantity,
    required this.availableQuantity,
    required this.unitPrice,
    required this.subtotal,
  });

  final int sourceItemId;
  final int purchasedQuantity;
  final int alreadyCommittedQuantity;
  final int availableQuantity;
  final double unitPrice;
  final double subtotal;

  factory PostSaleEligibleItem.fromJson(Map<String, dynamic> json) {
    return PostSaleEligibleItem(
      sourceItemId: _psInt(json['source_item_id']),
      purchasedQuantity: _psInt(json['purchased_quantity']),
      alreadyCommittedQuantity: _psInt(json['already_committed_quantity']),
      availableQuantity: _psInt(json['available_quantity']),
      unitPrice: _psDouble(json['unit_price']),
      subtotal: _psDouble(json['subtotal']),
    );
  }
}

class PostSaleSourceItem {
  const PostSaleSourceItem({
    required this.id,
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
  final String name;
  final String sku;
  final String size;
  final String color;
  final int quantity;
  final double unitPrice;
  final double subtotal;
  final String? imageUrl;
}

class PostSaleCase {
  const PostSaleCase({
    required this.id,
    required this.caseCode,
    required this.sourceChannel,
    required this.sourceId,
    required this.resolutionType,
    required this.status,
    required this.reason,
    required this.originalAmount,
    required this.replacementAmount,
    required this.differenceAmount,
    required this.settlementKind,
    required this.settlementAmount,
    required this.settlementStatus,
    required this.createdAt,
    required this.items,
    required this.replacementItems,
    required this.events,
    this.staffNote,
    this.reviewedAt,
    this.receivedAt,
    this.inspectedAt,
    this.completedAt,
    this.settlement,
  });

  final int id;
  final String caseCode;
  final String sourceChannel;
  final int sourceId;
  final String resolutionType;
  final String status;
  final String reason;
  final String? staffNote;
  final double originalAmount;
  final double replacementAmount;
  final double differenceAmount;
  final String settlementKind;
  final double settlementAmount;
  final String settlementStatus;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final DateTime? receivedAt;
  final DateTime? inspectedAt;
  final DateTime? completedAt;
  final List<PostSaleCaseItem> items;
  final List<PostSaleReplacementItem> replacementItems;
  final List<PostSaleEvent> events;
  final PostSaleSettlement? settlement;

  factory PostSaleCase.fromJson(Map<String, dynamic> json) {
    final settlement = json['settlement'];
    return PostSaleCase(
      id: _psInt(json['id']),
      caseCode: json['case_code']?.toString() ?? 'POSTVENTA-${json['id'] ?? ''}',
      sourceChannel: json['source_channel']?.toString() ?? 'ONLINE',
      sourceId: _psInt(json['source_id'] ?? json['order_id'] ?? json['sale_id']),
      resolutionType: json['resolution_type']?.toString() ?? 'REFUND',
      status: json['status']?.toString() ?? 'REQUESTED',
      reason: json['reason']?.toString() ?? '',
      staffNote: json['staff_note']?.toString(),
      originalAmount: _psDouble(json['original_amount']),
      replacementAmount: _psDouble(json['replacement_amount']),
      differenceAmount: _psDouble(json['difference_amount']),
      settlementKind: json['settlement_kind']?.toString() ?? 'NONE',
      settlementAmount: _psDouble(json['settlement_amount']),
      settlementStatus: json['settlement_status']?.toString() ?? 'NOT_REQUIRED',
      createdAt: _psDate(json['created_at']) ?? DateTime.now(),
      reviewedAt: _psDate(json['reviewed_at']),
      receivedAt: _psDate(json['received_at']),
      inspectedAt: _psDate(json['inspected_at']),
      completedAt: _psDate(json['completed_at']),
      items: (json['items'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => PostSaleCaseItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      replacementItems: (json['replacement_items'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => PostSaleReplacementItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      events: (json['events'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => PostSaleEvent.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      settlement: settlement is Map
          ? PostSaleSettlement.fromJson(Map<String, dynamic>.from(settlement))
          : null,
    );
  }

  String get channelLabel => sourceChannel == 'POS' ? 'Compra presencial' : 'Pedido online';
  String get resolutionLabel => resolutionType == 'EXCHANGE' ? 'Cambio de prendas' : 'Devolución de dinero';

  String get statusLabel => switch (status) {
    'REQUESTED' => 'En revisión',
    'APPROVED' => 'Aprobada · lleva tus prendas a la sucursal',
    'REJECTED' => 'No aprobada',
    'RECEIVED' => 'Prendas recibidas',
    'INSPECTED' => 'Inspección completada',
    'AWAITING_SETTLEMENT' => 'Pendiente de liquidación',
    'COMPLETED' => 'Finalizada',
    'CANCELLED' => 'Cancelada',
    _ => status,
  };

  bool get canCancel => status == 'REQUESTED';
}

class PostSaleCaseItem {
  const PostSaleCaseItem({
    required this.id,
    required this.sourceItemId,
    required this.quantity,
    required this.originalUnitPaid,
    required this.originalTotal,
    this.condition,
    this.inspectionNote,
  });

  final int id;
  final int sourceItemId;
  final int quantity;
  final double originalUnitPaid;
  final double originalTotal;
  final String? condition;
  final String? inspectionNote;

  factory PostSaleCaseItem.fromJson(Map<String, dynamic> json) => PostSaleCaseItem(
    id: _psInt(json['id']),
    sourceItemId: _psInt(json['source_item_id']),
    quantity: _psInt(json['quantity']),
    originalUnitPaid: _psDouble(json['original_unit_paid']),
    originalTotal: _psDouble(json['original_total']),
    condition: json['condition']?.toString(),
    inspectionNote: json['inspection_note']?.toString(),
  );
}

class PostSaleReplacementItem {
  const PostSaleReplacementItem({
    required this.productVariantId,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.productName,
    this.productCode,
    this.sku,
    this.size,
    this.color,
    this.imageUrl,
  });

  final String? productName;
  final String? productCode;
  final String? sku;
  final String? size;
  final String? color;
  final String? imageUrl;
  final int productVariantId;
  final int quantity;
  final double unitPrice;
  final double subtotal;

  factory PostSaleReplacementItem.fromJson(Map<String, dynamic> json) => PostSaleReplacementItem(
    productVariantId: _psInt(json['product_variant_id']),
    productName: json['product_name']?.toString(),
    productCode: json['product_code']?.toString(),
    sku: json['sku']?.toString(),
    size: json['size']?.toString(),
    color: json['color']?.toString(),
    imageUrl: json['image_url']?.toString(),
    quantity: _psInt(json['quantity']),
    unitPrice: _psDouble(json['unit_price']),
    subtotal: _psDouble(json['subtotal']),
  );
}

class PostSaleSettlement {
  const PostSaleSettlement({
    required this.kind,
    required this.amount,
    required this.currency,
    required this.status,
    this.method,
    this.mode,
    this.reference,
    this.completedAt,
  });

  final String kind;
  final double amount;
  final String currency;
  final String status;
  final String? method;
  final String? mode;
  final String? reference;
  final DateTime? completedAt;

  factory PostSaleSettlement.fromJson(Map<String, dynamic> json) => PostSaleSettlement(
    kind: json['kind']?.toString() ?? '',
    amount: _psDouble(json['amount']),
    currency: json['currency']?.toString() ?? 'BOB',
    status: json['status']?.toString() ?? 'PROCESSING',
    method: json['method']?.toString(),
    mode: json['mode']?.toString(),
    reference: json['reference']?.toString(),
    completedAt: _psDate(json['completed_at']),
  );

  String get statusLabel => switch (status) {
    'PROCESSING' => 'En proceso',
    'COMPLETED' => 'Completado',
    'FAILED' => 'No completado',
    'MANUAL_REVIEW' => 'En revisión manual',
    _ => status,
  };
}

class PostSaleEvent {
  const PostSaleEvent({
    required this.action,
    required this.createdAt,
    this.fromStatus,
    this.toStatus,
    this.note,
  });

  final String action;
  final DateTime createdAt;
  final String? fromStatus;
  final String? toStatus;
  final String? note;

  factory PostSaleEvent.fromJson(Map<String, dynamic> json) => PostSaleEvent(
    action: json['action']?.toString() ?? '',
    createdAt: _psDate(json['created_at']) ?? DateTime.now(),
    fromStatus: json['from_status']?.toString(),
    toStatus: json['to_status']?.toString(),
    note: json['note']?.toString(),
  );

  String get actionLabel => switch (action) {
    'REQUESTED' => 'Solicitud enviada',
    'APPROVED' => 'Solicitud aprobada',
    'REJECTED' => 'Solicitud rechazada',
    'RECEIVED' => 'Productos recibidos en sucursal',
    'INSPECTED' => 'Inspección completada',
    'EXCHANGE_QUOTED' => 'Cambio cotizado',
    'DIFFERENCE_COLLECTED' => 'Diferencia cobrada',
    'DEMO_REFUND_CONFIRMED' => 'Reintegro demo confirmado',
    'EXTERNAL_REFUND_RECORDED' => 'Reintegro externo registrado',
    'STRIPE_REFUND_PROCESSING' => 'Reembolso Stripe en proceso',
    'CANCELLED' => 'Solicitud cancelada',
    _ => action.replaceAll('_', ' ').toLowerCase(),
  };
}

int _psInt(dynamic value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _psDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _psDate(dynamic value) {
  final raw = value?.toString();
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}
