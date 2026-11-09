import 'package:flutter/material.dart';

import 'checkout_fashion_style.dart';
import '../../models/order.dart';

class CheckoutItemsCard extends StatelessWidget {
  const CheckoutItemsCard({
    super.key,
    required this.items,
  });

  final List<CheckoutItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CheckoutFashionStyle.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: CheckoutFashionStyle.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tu pedido',
            style: TextStyle(
              color: CheckoutFashionStyle.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < items.length; index++) ...[
            _CheckoutItemRow(item: items[index]),
            if (index != items.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(
                  height: 1,
                  color: CheckoutFashionStyle.divider,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _CheckoutItemRow extends StatelessWidget {
  const _CheckoutItemRow({
    required this.item,
  });

  final CheckoutItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: CheckoutFashionStyle.surfaceLight,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(
            Icons.checkroom_rounded,
            color: CheckoutFashionStyle.textMuted,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.productName,
                style: const TextStyle(
                  color: CheckoutFashionStyle.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${item.size} · ${item.color} · ${item.sku}',
                style: const TextStyle(
                  color: CheckoutFashionStyle.textSecondary,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${item.quantity} × Bs ${item.unitPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: CheckoutFashionStyle.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Bs ${item.subtotal.toStringAsFixed(2)}',
          style: const TextStyle(
            color: CheckoutFashionStyle.primaryLight,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
