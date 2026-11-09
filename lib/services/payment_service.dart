import 'dart:convert';

import '../models/payment.dart';
import 'api_service.dart';

class PaymentService {
  static const String _baseUrl = '/payments';

  static Future<List<PaymentMethodOption>>
      getPaymentMethods() async {
    final response = await ApiService.get(
      '$_baseUrl/methods',
      requiresAuth: true,
    );

    final data = _decode(response.body);

    if (response.statusCode != 200) {
      throw Exception(
        _detail(
          data,
          'No pudimos cargar los métodos de pago.',
        ),
      );
    }

    if (data is! Map || data['items'] is! List) {
      throw Exception(
        'Respuesta inválida de métodos de pago.',
      );
    }

    return (data['items'] as List)
        .whereType<Map>()
        .map(
          (item) => PaymentMethodOption.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .where((item) => item.enabled)
        .toList();
  }

  static Future<StripePaymentIntentResponse>
      createStripePaymentIntent(int orderId) async {
    final response = await ApiService.post(
      '$_baseUrl/stripe/payment-intent',
      requiresAuth: true,
      body: {
        'order_id': orderId,
      },
    );

    final data = _decode(response.body);

    if (response.statusCode != 200 &&
        response.statusCode != 201) {
      throw Exception(
        _detail(
          data,
          'No se pudo iniciar el pago con Stripe.',
        ),
      );
    }

    if (data is! Map) {
      throw Exception(
        'Respuesta inválida al iniciar Stripe.',
      );
    }

    final result = StripePaymentIntentResponse.fromJson(
      Map<String, dynamic>.from(data),
    );

    if (result.clientSecret.isEmpty ||
        result.publishableKey.isEmpty) {
      throw Exception(
        'Stripe no devolvió las credenciales públicas necesarias.',
      );
    }

    return result;
  }

  static Future<PaymentStatusResponse> getPaymentStatus(
    int paymentId,
  ) async {
    final response = await ApiService.get(
      '$_baseUrl/$paymentId/status',
      requiresAuth: true,
    );

    final data = _decode(response.body);

    if (response.statusCode != 200) {
      throw Exception(
        _detail(
          data,
          'No se pudo consultar el estado del pago.',
        ),
      );
    }

    if (data is! Map) {
      throw Exception(
        'Respuesta inválida del estado del pago.',
      );
    }

    return PaymentStatusResponse.fromJson(
      Map<String, dynamic>.from(data),
    );
  }

  /// El servidor verifica el PaymentIntent contra Stripe antes de confirmar.
  static Future<PaymentStatusResponse> reconcileStripePayment(int paymentId) async {
    final response = await ApiService.post(
      '$_baseUrl/$paymentId/reconcile',
      requiresAuth: true,
      body: <String, dynamic>{},
    );
    final data = _decode(response.body);
    if (response.statusCode != 200 || data is! Map) {
      throw Exception(_detail(data, 'No se pudo comprobar el pago con Stripe.'));
    }
    return PaymentStatusResponse.fromJson(Map<String, dynamic>.from(data));
  }

  static Future<ElectronicPayment> cancelPayment(
    int paymentId, {
    required String reason,
  }) async {
    final response = await ApiService.post(
      '$_baseUrl/$paymentId/cancel',
      requiresAuth: true,
      body: {
        'reason': reason.trim(),
      },
    );

    final data = _decode(response.body);

    if (response.statusCode != 200) {
      throw Exception(
        _detail(data, 'No se pudo cancelar el pago.'),
      );
    }

    if (data is! Map) {
      throw Exception(
        'Respuesta inválida al cancelar el pago.',
      );
    }

    return ElectronicPayment.fromJson(
      Map<String, dynamic>.from(data),
    );
  }

  static dynamic _decode(String body) {
    if (body.trim().isEmpty) return null;

    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  static String _detail(
    dynamic data,
    String fallback,
  ) {
    if (data is Map && data['detail'] != null) {
      return data['detail'].toString();
    }

    return fallback;
  }
}
