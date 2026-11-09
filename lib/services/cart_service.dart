import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';
import '../repositories/account_snapshot_repository.dart';
import 'api_service.dart';

class CartService {
  static const String _baseUrl = '/carts/me';

  static final ValueNotifier<int> totalItemsNotifier =
      ValueNotifier<int>(0);

  static final ValueNotifier<int> totalUnitsNotifier =
      ValueNotifier<int>(0);

  static final ValueNotifier<int> mutationVersionNotifier =
      ValueNotifier<int>(0);

  static Future<MyCartResponse> getMyCart(int branchId) async {
    final endpoint = Uri(
      path: _baseUrl,
      queryParameters: {
        'branch_id': '$branchId',
      },
    ).toString();

    final response = await ApiService.get(
      endpoint,
      requiresAuth: true,
    );

    final data = _decode(response.body);

    if (response.statusCode != 200) {
      throw Exception(
        _detail(data, 'No pudimos cargar tu carrito.'),
      );
    }

    if (data is! Map) {
      throw Exception('Respuesta inválida del carrito.');
    }

    final result = MyCartResponse.fromJson(
      Map<String, dynamic>.from(data),
    );

    _setCount(result.totalItems, result.totalUnits);
    try {
      await const AccountSnapshotRepository().saveCart(
        branchId, Map<String, dynamic>.from(data));
    } catch (error) {
      debugPrint('[FS-SNAPSHOT] No se guardó carrito remoto: $error');
    }

    return result;
  }

  static Future<CartCountResponse> getMyCartCount(
    int branchId,
  ) async {
    final endpoint = Uri(
      path: '$_baseUrl/count',
      queryParameters: {
        'branch_id': '$branchId',
      },
    ).toString();

    final response = await ApiService.get(
      endpoint,
      requiresAuth: true,
    );

    final data = _decode(response.body);

    if (response.statusCode != 200) {
      throw Exception(
        _detail(data, 'No se pudo consultar el carrito.'),
      );
    }

    if (data is! Map) {
      throw Exception('Respuesta inválida del contador.');
    }

    final result = CartCountResponse.fromJson(
      Map<String, dynamic>.from(data),
    );

    _setCount(result.totalItems, result.totalUnits);

    return result;
  }

  static Future<CartActionResponse> addItem({
    required int branchId,
    required int productVariantId,
    required int quantity,
  }) async {
    final response = await ApiService.post(
      '$_baseUrl/items',
      requiresAuth: true,
      body: {
        'branch_id': branchId,
        'product_variant_id': productVariantId,
        'quantity': quantity,
      },
    );

    return _actionResponse(
      response.statusCode,
      response.body,
      successCodes: const {200, 201},
      fallback: 'No se pudo agregar la prenda al carrito.',
    );
  }

  static Future<CartActionResponse> updateItemQuantity({
    required int itemId,
    required int quantity,
  }) async {
    final response = await ApiService.patch(
      '$_baseUrl/items/$itemId',
      requiresAuth: true,
      body: {
        'quantity': quantity,
      },
    );

    return _actionResponse(
      response.statusCode,
      response.body,
      successCodes: const {200},
      fallback:
          'No se pudo actualizar la cantidad. Verifica el stock disponible.',
    );
  }

  static Future<CartActionResponse> removeItem(
    int itemId,
  ) async {
    final response = await ApiService.delete(
      '$_baseUrl/items/$itemId',
      requiresAuth: true,
    );

    return _actionResponse(
      response.statusCode,
      response.body,
      successCodes: const {200},
      fallback: 'No se pudo eliminar el producto del carrito.',
    );
  }

  static Future<CartClearResponse> clearMyCart(
    int branchId,
  ) async {
    final endpoint = Uri(
      path: '$_baseUrl/items',
      queryParameters: {
        'branch_id': '$branchId',
      },
    ).toString();

    final response = await ApiService.delete(
      endpoint,
      requiresAuth: true,
    );

    final data = _decode(response.body);

    if (response.statusCode != 200) {
      throw Exception(
        _detail(data, 'No se pudo vaciar el carrito.'),
      );
    }

    if (data is! Map) {
      throw Exception('Respuesta inválida al vaciar el carrito.');
    }

    final result = CartClearResponse.fromJson(
      Map<String, dynamic>.from(data),
    );

    _setCount(result.totalItems, result.totalUnits);
    _notifyMutation();
    try {
      await const AccountSnapshotRepository().saveCart(branchId, {
        'branch_id': branchId, 'has_cart': false,
        'total_items': 0, 'total_units': 0, 'total_amount': 0,
        'cart': null,
      });
    } catch (error) {
      debugPrint('[FS-SNAPSHOT] No se actualizó carrito vacío: $error');
    }

    return result;
  }

  /// Vuelve a consultar el carrito remoto después de crear o pagar un pedido.
  /// La API es la autoridad: no eliminamos productos ni borradores locales
  /// basándonos únicamente en lo que muestra la pantalla de pago.
  static Future<void> refreshAfterPurchase(int? branchId) async {
    if (branchId == null || branchId <= 0) return;
    try {
      await getMyCart(branchId);
      _notifyMutation();
    } catch (error) {
      debugPrint('[FS-CARRITO] Sincronización poscompra pendiente: $error');
      // La próxima entrada al carrito reintentará la consulta remota.
    }
  }

  static void resetCount() {
    _setCount(0, 0);
  }

  static CartActionResponse _actionResponse(
    int statusCode,
    String body, {
    required Set<int> successCodes,
    required String fallback,
  }) {
    final data = _decode(body);

    if (!successCodes.contains(statusCode)) {
      throw Exception(_detail(data, fallback));
    }

    if (data is! Map) {
      throw Exception('Respuesta inválida del carrito.');
    }

    final result = CartActionResponse.fromJson(
      Map<String, dynamic>.from(data),
    );

    _setCount(
      result.cart.totalItems,
      result.cart.totalUnits,
    );
    _notifyMutation();
    final branchId = result.cart.branchId;
    if (branchId != null && branchId > 0) {
      unawaited(const AccountSnapshotRepository().saveCart(branchId, {
        'branch_id': branchId,
        'has_cart': true,
        'total_items': result.cart.totalItems,
        'total_units': result.cart.totalUnits,
        'total_amount': result.cart.totalAmount,
        'cart': data['cart'],
      }).catchError((Object error) {
        debugPrint('[FS-SNAPSHOT] No se actualizó carrito: $error');
      }));
    }

    return result;
  }

  static void _setCount(
    int totalItems,
    int totalUnits,
  ) {
    totalItemsNotifier.value =
        totalItems < 0 ? 0 : totalItems;
    totalUnitsNotifier.value =
        totalUnits < 0 ? 0 : totalUnits;
  }

  static void _notifyMutation() {
    mutationVersionNotifier.value++;
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
