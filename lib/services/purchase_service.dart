import 'dart:convert';

import '../models/purchase_order.dart';
import 'api_service.dart';

class PurchaseService {
  static Future<PurchaseListResponse> getMyOrders({
    int page = 1,
    int pageSize = 5,
    String? status,
    String? paymentMethod,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'page_size': '$pageSize',
      'sort_by': 'created_at',
      'sort_order': 'desc',
      if (status != null && status.isNotEmpty) 'status': status,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (dateFrom != null)
        'date_from': DateTime(
          dateFrom.year,
          dateFrom.month,
          dateFrom.day,
        ).toUtc().toIso8601String(),
      if (dateTo != null)
        'date_to': DateTime(
          dateTo.year,
          dateTo.month,
          dateTo.day,
          23,
          59,
          59,
          999,
        ).toUtc().toIso8601String(),
    };

    final endpoint = Uri(
      path: '/orders/mine',
      queryParameters: query,
    ).toString();

    final response = await ApiService.get(
      endpoint,
      requiresAuth: true,
    );

    final data = _decode(response.body);

    if (response.statusCode != 200) {
      throw Exception(
        _detail(
          data,
          'No se pudo cargar tu historial de compras.',
        ),
      );
    }

    if (data is! Map) {
      throw Exception(
        'Respuesta inválida del historial de compras.',
      );
    }

    return PurchaseListResponse.fromJson(
      Map<String, dynamic>.from(data),
    );
  }

  static Future<PurchaseOrder> getOrder(int orderId) async {
    final response = await ApiService.get(
      '/orders/$orderId',
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

    return PurchaseOrder.fromJson(
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

  static String _detail(dynamic data, String fallback) {
    if (data is Map && data['detail'] != null) {
      return data['detail'].toString();
    }
    return fallback;
  }
}
