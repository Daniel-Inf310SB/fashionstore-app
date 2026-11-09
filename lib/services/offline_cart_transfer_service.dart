import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';
import '../repositories/offline_cart_repository.dart';
import 'cart_service.dart';

class CartTransferResult {
  const CartTransferResult({required this.transferred, required this.needsReview,
    required this.failed, required this.message});
  final int transferred;
  final int needsReview;
  final int failed;
  final String message;
}

/// Copia borradores al carrito del servidor cuando hay conexión.
/// No finaliza compras, reservas ni pagos.
/// POST /carts/me/items no dispone de clave idempotente comprobada.
/// Antes de cualquier petición de escritura registra un journal persistente;
/// si la respuesta es incierta, bloquea el reintento para evitar duplicados.
class OfflineCartTransferService {
  const OfflineCartTransferService();

  Future<CartTransferResult> transfer(
    int branchId, {
    void Function(int completed, int total)? onProgress,
  }) async {
    const repository = OfflineCartRepository();
    final drafts = await repository.list(branchId);
    int moved = 0, review = 0, failed = 0;
    var completed = 0;
    final total = drafts.length;
    onProgress?.call(0, total);
    if (drafts.isEmpty) {
      return const CartTransferResult(transferred: 0, needsReview: 0,
        failed: 0, message: 'No hay prendas locales para transferir.');
    }

    for (final draft in drafts) {
      try {
      if (await repository.requiresReview(branchId, draft.variantId)) {
        review++;
        continue;
      }
      MyCartResponse remote;
      try {
        remote = await CartService.getMyCart(branchId);
      } catch (error) {
        debugPrint('[FS-CARRITO-SYNC] No se pudo leer el carrito: $error');
        failed++;
        break; // Se puede reintentar: no hubo escritura.
      }
      final existing = remote.cart?.items.where(
        (e) => e.productVariantId == draft.variantId).toList() ?? [];
      final old = existing.isEmpty ? null : existing.first;
      final target = (old?.quantity ?? 0) + draft.quantity;
      // Persistencia ANTES de enviar; tras fallo/crash no se reenvía a ciegas.
      try {
        await repository.markTransferStarted(branchId: branchId,
          draft: draft, targetQuantity: target, remoteItemId: old?.id);
      } catch (error) {
        review++;
        debugPrint('[FS-CARRITO-SYNC] Journal no disponible: $error');
        continue;
      }
      try {
        if (old != null) {
          await CartService.updateItemQuantity(itemId: old.id, quantity: target);
        } else {
          await CartService.addItem(branchId: branchId,
            productVariantId: draft.variantId, quantity: draft.quantity);
        }
        await repository.transferSucceeded(branchId: branchId, draft: draft);
        moved++;
        debugPrint('[FS-CARRITO-SYNC] Variante ${draft.variantId} transferida');
      } catch (error) {
        // No sabemos si FastAPI aplicó la escritura antes de perder respuesta.
        // Mantener el journal y el borrador; requiere revisión explícita.
        review++;
        debugPrint('[FS-CARRITO-SYNC] Revisión requerida ${draft.variantId}: $error');
      }
      } finally {
        completed++;
        onProgress?.call(completed, total);
      }
    }
    return CartTransferResult(transferred: moved, needsReview: review,
      failed: failed,
      message: review > 0
        ? '$moved prenda(s) transferidas; $review requieren revisión para evitar duplicados.'
        : failed > 0
          ? '$moved transferidas. Sin conexión para continuar; las demás siguen guardadas.'
          : '$moved prenda(s) transferidas correctamente al carrito del servidor.');
  }
}
