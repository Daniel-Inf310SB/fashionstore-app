import 'dart:convert';

import '../models/order.dart';
import 'api_service.dart';

class OrderService {
  static const String _baseUrl = '/orders';

  static Future<CheckoutPreview> getCheckoutPreview(
    int cartId,
  ) async {
    final response = await ApiService.get(
      '$_baseUrl/checkout/$cartId',
      requiresAuth: true,
    );

    final data = _decode(response.body);

    if (response.statusCode != 200) {
      throw Exception(
        _detail(data, 'No pudimos preparar el checkout.'),
      );
    }

    if (data is! Map) {
      throw Exception('Respuesta inválida del checkout.');
    }

    return CheckoutPreview.fromJson(
      Map<String, dynamic>.from(data),
    );
  }

  static Future<CustomerOrder> createOrder({
    required int cartId,
    required String deliveryType,
    String? shippingAddress,
  }) async {
    final response = await ApiService.post(
      _baseUrl,
      requiresAuth: true,
      body: {
        'cart_id': cartId,
        'delivery_type': deliveryType,
        'shipping_address':
            deliveryType == 'DELIVERY'
                ? _nullableText(shippingAddress)
                : null,
      },
    );

    final data = _decode(response.body);

    if (response.statusCode != 200 &&
        response.statusCode != 201) {
      throw Exception(
        _detail(data, 'No se pudo crear la compra.'),
      );
    }

    if (data is! Map) {
      throw Exception('Respuesta inválida al crear la compra.');
    }

    return CustomerOrder.fromJson(
      Map<String, dynamic>.from(data),
    );
  }

  static Future<CustomerOrder> getOrder(
    int orderId,
  ) async {
    final response = await ApiService.get(
      '$_baseUrl/$orderId',
      requiresAuth: true,
    );

    final data = _decode(response.body);

    if (response.statusCode != 200) {
      throw Exception(
        _detail(data, 'No se pudo cargar la compra.'),
      );
    }

    if (data is! Map) {
      throw Exception('Respuesta inválida de la compra.');
    }

    return CustomerOrder.fromJson(
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

  static String? _nullableText(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }
}
