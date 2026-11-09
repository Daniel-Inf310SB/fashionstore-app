class ReturnEligibleItem {
  const ReturnEligibleItem({required this.orderItemId,required this.availableQuantity,required this.purchasedQuantity,required this.alreadyRequestedQuantity});
  final int orderItemId, availableQuantity, purchasedQuantity, alreadyRequestedQuantity;
  factory ReturnEligibleItem.fromJson(Map<String,dynamic> j) => ReturnEligibleItem(
    orderItemId: (j['order_item_id'] as num).toInt(),
    availableQuantity: (j['available_quantity'] as num).toInt(),
    purchasedQuantity: (j['purchased_quantity'] as num).toInt(),
    alreadyRequestedQuantity: (j['already_requested_quantity'] as num).toInt(),
  );
}
class ReturnEligibility {
  const ReturnEligibility({
    required this.canRequest,
    required this.reason,
    required this.items,
    this.deliveredAt,
    this.deadline,
    this.windowDays = 7,
  });
  final bool canRequest;
  final String? reason;
  final List<ReturnEligibleItem> items;
  /// Fechas opcionales que FastAPI debe devolver al implementar la política.
  final DateTime? deliveredAt;
  final DateTime? deadline;
  final int windowDays;

  DateTime? get expiresAt => deadline ?? deliveredAt?.add(Duration(days: windowDays));
  bool get isExpired {
    final end = expiresAt;
    return end != null && !DateTime.now().isBefore(end);
  }
  bool get mayRequest => canRequest && !isExpired;

  factory ReturnEligibility.fromJson(Map<String, dynamic> j) => ReturnEligibility(
    canRequest: j['can_request'] == true,
    reason: j['reason']?.toString(),
    items: (j['items'] as List? ?? []).whereType<Map>().map((e) => ReturnEligibleItem.fromJson(Map<String, dynamic>.from(e))).toList(),
    deliveredAt: _returnDate(j['delivered_at']),
    deadline: _returnDate(j['return_deadline'] ?? j['return_expires_at'] ?? j['deadline']),
    windowDays: (j['return_window_days'] is num) ? (j['return_window_days'] as num).toInt() : 7,
  );
}

DateTime? _returnDate(dynamic value) {
  if (value == null || value.toString().trim().isEmpty) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}

class CustomerReturn {
  const CustomerReturn({required this.id,required this.orderId,required this.status,required this.reason,required this.createdAt,required this.items,this.adminNote});
  final int id,orderId;
  final String status, reason;
  final DateTime createdAt;
  final String? adminNote;
  final List<ReturnRequestItem> items;
  factory CustomerReturn.fromJson(Map<String,dynamic> j)=>CustomerReturn(
    id: (j['id'] as num).toInt(),orderId: (j['order_id'] as num).toInt(),
    status: j['status']?.toString() ?? 'REQUESTED',reason: j['reason']?.toString() ?? '',
    adminNote: j['admin_note']?.toString(),createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '') ?? DateTime.now(),
    items:(j['items'] as List? ?? []).whereType<Map>().map((e)=>ReturnRequestItem.fromJson(Map<String,dynamic>.from(e))).toList(),
  );
  String get statusLabel => switch(status) {
    'REQUESTED'=>'En revisión', 'APPROVED'=>'Aprobada', 'REJECTED'=>'Rechazada',
    'RECEIVED'=>'Productos recibidos','CANCELLED'=>'Cancelada', _=>status
  };
}
class ReturnRequestItem {
  const ReturnRequestItem({required this.orderItemId,required this.quantity});
  final int orderItemId,quantity;
  factory ReturnRequestItem.fromJson(Map<String,dynamic> j)=>ReturnRequestItem(orderItemId:(j['order_item_id'] as num).toInt(),quantity:(j['quantity'] as num).toInt());
}
class ReturnRefundStatus {
  const ReturnRefundStatus({required this.status,this.amount,this.currency});
  final String status;
  final String? amount,currency;
  factory ReturnRefundStatus.fromJson(Map<String,dynamic> j)=>ReturnRefundStatus(status:j['status']?.toString() ?? 'NOT_STARTED',amount:j['amount']?.toString(),currency:j['currency']?.toString());
}
