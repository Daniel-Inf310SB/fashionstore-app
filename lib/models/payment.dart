class PaymentMethodOption {
  const PaymentMethodOption({
    required this.code,
    required this.name,
    required this.provider,
    required this.enabled,
    this.description,
  });

  final String code;
  final String name;
  final String provider;
  final bool enabled;
  final String? description;

  factory PaymentMethodOption.fromJson(Map<String, dynamic> json) {
    return PaymentMethodOption(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      provider: json['provider']?.toString() ?? '',
      enabled: json['enabled'] == true,
      description: json['description']?.toString(),
    );
  }
}

class ElectronicPayment {
  const ElectronicPayment({
    required this.id,
    required this.paymentCode,
    required this.sourceType,
    required this.sourceCode,
    required this.paymentMethod,
    required this.channel,
    required this.amount,
    required this.currency,
    required this.status,
    required this.branch,
    required this.createdAt,
    required this.updatedAt,
    this.orderId,
    this.saleId,
    this.userId,
    this.provider,
    this.externalTransactionId,
    this.externalReference,
    this.failureReason,
    this.paidAt,
  });

  final int id;
  final String paymentCode;

  final int? orderId;
  final int? saleId;
  final int? userId;

  final String sourceType;
  final String sourceCode;
  final String paymentMethod;
  final String channel;
  final String? provider;

  final double amount;
  final String currency;
  final String status;

  final String? externalTransactionId;
  final String? externalReference;
  final String? failureReason;
  final DateTime? paidAt;

  final PaymentBranch branch;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ElectronicPayment.fromJson(Map<String, dynamic> json) {
    final rawBranch = json['branch'];

    return ElectronicPayment(
      id: (json['id'] as num?)?.toInt() ?? 0,
      paymentCode: json['payment_code']?.toString() ?? '',
      orderId: (json['order_id'] as num?)?.toInt(),
      saleId: (json['sale_id'] as num?)?.toInt(),
      userId: (json['user_id'] as num?)?.toInt(),
      sourceType: json['source_type']?.toString() ?? '',
      sourceCode: json['source_code']?.toString() ?? '',
      paymentMethod: json['payment_method']?.toString() ?? '',
      channel: json['channel']?.toString() ?? '',
      provider: json['provider']?.toString(),
      amount: _toDouble(json['amount']),
      currency: json['currency']?.toString() ?? 'BOB',
      status: json['status']?.toString() ?? 'PENDING',
      externalTransactionId:
          json['external_transaction_id']?.toString(),
      externalReference:
          json['external_reference']?.toString(),
      failureReason: json['failure_reason']?.toString(),
      paidAt: _toDate(json['paid_at']),
      branch: rawBranch is Map
          ? PaymentBranch.fromJson(
              Map<String, dynamic>.from(rawBranch),
            )
          : const PaymentBranch(
              id: 0,
              name: 'Sucursal',
              address: '',
              cityId: 0,
            ),
      createdAt: _toDate(json['created_at']) ?? DateTime.now(),
      updatedAt: _toDate(json['updated_at']) ?? DateTime.now(),
    );
  }
}

class PaymentBranch {
  const PaymentBranch({
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

  factory PaymentBranch.fromJson(Map<String, dynamic> json) {
    return PaymentBranch(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? 'Sucursal',
      address: json['address']?.toString() ?? '',
      phone: json['phone']?.toString(),
      cityId: (json['city_id'] as num?)?.toInt() ?? 0,
    );
  }
}

class StripePaymentIntentResponse {
  const StripePaymentIntentResponse({
    required this.payment,
    required this.clientSecret,
    required this.publishableKey,
  });

  final ElectronicPayment payment;
  final String clientSecret;
  final String publishableKey;

  factory StripePaymentIntentResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawPayment = json['payment'];

    if (rawPayment is! Map) {
      throw const FormatException(
        'Stripe no devolvió un pago válido.',
      );
    }

    return StripePaymentIntentResponse(
      payment: ElectronicPayment.fromJson(
        Map<String, dynamic>.from(rawPayment),
      ),
      clientSecret: json['client_secret']?.toString() ?? '',
      publishableKey: json['publishable_key']?.toString() ?? '',
    );
  }
}

class PaymentStatusResponse {
  const PaymentStatusResponse({
    required this.id,
    required this.paymentCode,
    required this.sourceType,
    required this.sourceCode,
    required this.status,
    required this.paymentMethod,
    required this.amount,
    required this.currency,
    required this.updatedAt,
    this.provider,
    this.externalTransactionId,
    this.failureReason,
    this.paidAt,
  });

  final int id;
  final String paymentCode;
  final String sourceType;
  final String sourceCode;
  final String status;
  final String paymentMethod;
  final double amount;
  final String currency;
  final String? provider;
  final String? externalTransactionId;
  final String? failureReason;
  final DateTime? paidAt;
  final DateTime updatedAt;

  factory PaymentStatusResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    return PaymentStatusResponse(
      id: (json['id'] as num?)?.toInt() ?? 0,
      paymentCode: json['payment_code']?.toString() ?? '',
      sourceType: json['source_type']?.toString() ?? '',
      sourceCode: json['source_code']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      paymentMethod: json['payment_method']?.toString() ?? '',
      amount: _toDouble(json['amount']),
      currency: json['currency']?.toString() ?? 'BOB',
      provider: json['provider']?.toString(),
      externalTransactionId:
          json['external_transaction_id']?.toString(),
      failureReason: json['failure_reason']?.toString(),
      paidAt: _toDate(json['paid_at']),
      updatedAt: _toDate(json['updated_at']) ?? DateTime.now(),
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
