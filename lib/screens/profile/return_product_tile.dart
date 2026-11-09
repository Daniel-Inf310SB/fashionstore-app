import 'package:flutter/material.dart';
import '../../models/purchase_order.dart';
import '../../models/return_request.dart';
import 'return_style.dart';

/// Displays the actual purchased product associated with a return item.
/// Never guesses an identity if the order details are unavailable.
class ReturnProductTile extends StatelessWidget {
  const ReturnProductTile({super.key, required this.item, this.order, this.compact = false});
  final ReturnRequestItem item;
  final PurchaseOrder? order;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    PurchaseItem? purchaseItem;
    if (order != null) {
      for (final candidate in order!.items) {
        if (candidate.id == item.orderItemId) {
          purchaseItem = candidate;
          break;
        }
      }
    }
    final product = purchaseItem;
    final imageUrl = product?.variant.displayImageUrl;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
            color: const Color(0xFFF0F0F0),
            width: compact ? 62 : 78,
            height: compact ? 76 : 98,
            child: imageUrl == null
                ? const Icon(Icons.checkroom_outlined, color: Color(0xFF999999), size: 32)
                : Image.network(imageUrl, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.checkroom_outlined, color: Color(0xFF999999), size: 32)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(product?.variant.productName ?? 'Prenda del pedido #${item.orderItemId}',
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: ReturnStyle.ink)),
          const SizedBox(height: 5),
          if (product != null) ...[
            Text([product.variant.size, product.variant.color].where((x) => x.trim().isNotEmpty).join(' · '),
              style: const TextStyle(fontSize: 12, color: ReturnStyle.grey)),
            const SizedBox(height: 5),
            Text('Bs ${product.unitPrice.toStringAsFixed(2)} c/u',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ReturnStyle.ink)),
            if (!compact) ...[
              const SizedBox(height: 4),
              Text('Subtotal solicitado: Bs ${(product.unitPrice * item.quantity).toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 12, color: ReturnStyle.grey)),
            ],
          ] else ...[
            const Text('Detalle de la prenda no disponible', style: TextStyle(fontSize: 12, color: ReturnStyle.grey)),
          ],
          const SizedBox(height: 5),
          Text('${item.quantity} ${item.quantity == 1 ? 'unidad solicitada' : 'unidades solicitadas'}',
            style: const TextStyle(fontSize: 12, color: ReturnStyle.grey)),
        ])),
      ]),
    );
  }
}
