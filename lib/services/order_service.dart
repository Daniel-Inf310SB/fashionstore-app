import 'dart:convert';

import '../core/errors/api_exception.dart';
import '../models/purchase.dart';
import 'api_service.dart';

/// CU33 - Gestionar compra digital (crear desde el carrito).
/// CU34 - Consultar historial de compras (lado cliente).
///
/// El pago electrónico (CU38/CU39) todavía no tiene una ruta pensada
/// para el cliente en el backend: `/payments/*` es exclusivo del
/// panel administrativo (`require_payments_view` / `require_payments_manage`
/// exigen rol ADMINISTRADOR). Por eso, después de crear la compra,
/// esta queda en `PENDING_PAYMENT` y el pago se conecta en un
/// siguiente módulo.
class OrderService {
  OrderService._();

  // =========================================================
  // CU33 - CREAR COMPRA DESDE EL CARRITO
  //
  // El cliente nunca envía customer_id ni totales: el backend los
  // calcula a partir del carrito (`cart_id`) y del inventario actual.
  // =========================================================

  static Future<Order> createOrder({required int cartId}) async {
    final response = await ApiService.post(
      '/orders',
      requiresAuth: true,
      body: {'cart_id': cartId},
    );

    throwIfError(response);

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return Order.fromJson(data as Map<String, dynamic>);
  }

  // =========================================================
  // CU34 - MI HISTORIAL DE COMPRAS
  // =========================================================

  static Future<OrderPage> listMyOrders({
    int page = 1,
    int pageSize = 10,
    String? status,
  }) async {
    final endpoint = Uri(
      path: '/orders/mine',
      queryParameters: {
        'page': '$page',
        'page_size': '$pageSize',
        if (status != null) 'status': status,
      },
    ).toString();

    final response = await ApiService.get(endpoint, requiresAuth: true);

    throwIfError(response);

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return OrderPage.fromJson(data as Map<String, dynamic>);
  }

  // =========================================================
  // CU34 - DETALLE DE UNA COMPRA
  // =========================================================

  static Future<Order> getOrder(int orderId) async {
    final response = await ApiService.get(
      '/orders/$orderId',
      requiresAuth: true,
    );

    throwIfError(response);

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return Order.fromJson(data as Map<String, dynamic>);
  }
}