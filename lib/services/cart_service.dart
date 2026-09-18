import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/errors/api_exception.dart';
import '../models/cart_item.dart';
import 'api_service.dart';

/// CU32 - Gestionar carrito de compras.
///
/// El backend exige un `branch_id` en cada operación porque cada
/// cliente puede tener a lo sumo un carrito ACTIVE por sucursal
/// (ver `shopping_carts` / `uq_shopping_cart_active_customer_branch`).
///
/// La app todavía no tiene un selector de "sucursal actual" global,
/// así que `CartService` recuerda la última sucursal usada (la de la
/// última prenda agregada) en almacenamiento seguro, y esa es la que
/// se abre por defecto al entrar a la pantalla del carrito.
class CartService {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String _lastBranchKey = 'cart_last_branch_id';

  // =========================================================
  // SUCURSAL RECORDADA
  // =========================================================

  static Future<void> _rememberBranch(int branchId) async {
    await _secureStorage.write(
      key: _lastBranchKey,
      value: branchId.toString(),
    );
  }

  static Future<int?> getLastBranchId() async {
    final raw = await _secureStorage.read(key: _lastBranchKey);
    if (raw == null) return null;
    return int.tryParse(raw);
  }

  // =========================================================
  // CU32 - CONSULTAR MI CARRITO
  // =========================================================

  static Future<MyCart> getMyCart({required int branchId}) async {
    final response = await ApiService.get(
      '/carts/me?branch_id=$branchId',
      requiresAuth: true,
    );

    throwIfError(response);

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return MyCart.fromJson(data as Map<String, dynamic>);
  }

  // =========================================================
  // CU32 - CONTADOR PARA EL BADGE DEL CARRITO
  // =========================================================

  static Future<CartCount> getMyCartCount({required int branchId}) async {
    final response = await ApiService.get(
      '/carts/me/count?branch_id=$branchId',
      requiresAuth: true,
    );

    throwIfError(response);

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return CartCount.fromJson(data as Map<String, dynamic>);
  }

  // =========================================================
  // CU32 - AGREGAR PRODUCTO
  // =========================================================

  static Future<Cart> addItem({
    required int branchId,
    required int productVariantId,
    int quantity = 1,
  }) async {
    final response = await ApiService.post(
      '/carts/me/items',
      requiresAuth: true,
      body: {
        'branch_id': branchId,
        'product_variant_id': productVariantId,
        'quantity': quantity,
      },
    );

    throwIfError(response);

    await _rememberBranch(branchId);

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return Cart.fromJson(data['cart'] as Map<String, dynamic>);
  }

  // =========================================================
  // CU32 - ACTUALIZAR CANTIDAD
  // =========================================================

  static Future<Cart> updateItemQuantity({
    required int itemId,
    required int quantity,
  }) async {
    final response = await ApiService.patch(
      '/carts/me/items/$itemId',
      requiresAuth: true,
      body: {'quantity': quantity},
    );

    throwIfError(response);

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return Cart.fromJson(data['cart'] as Map<String, dynamic>);
  }

  // =========================================================
  // CU32 - ELIMINAR PRODUCTO
  // =========================================================

  static Future<Cart> removeItem({required int itemId}) async {
    final response = await ApiService.delete(
      '/carts/me/items/$itemId',
      requiresAuth: true,
    );

    throwIfError(response);

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return Cart.fromJson(data['cart'] as Map<String, dynamic>);
  }

  // =========================================================
  // CU32 - VACIAR CARRITO
  // =========================================================

  static Future<void> clearCart({required int branchId}) async {
    final response = await ApiService.delete(
      '/carts/me/items?branch_id=$branchId',
      requiresAuth: true,
    );

    throwIfError(response);
  }
}