import 'package:flutter/material.dart';

import 'checkout_fashion_style.dart';

/// Checkout de clientes: la única modalidad habilitada es el retiro en sucursal.
class CheckoutDeliverySelector extends StatelessWidget {
  const CheckoutDeliverySelector({
    super.key,
    required this.branchName,
  });

  final String branchName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CheckoutFashionStyle.surface,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: CheckoutFashionStyle.primary),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.storefront_rounded,
            color: CheckoutFashionStyle.textPrimary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recoger en sucursal',
                  style: TextStyle(
                    color: CheckoutFashionStyle.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  branchName,
                  style: const TextStyle(
                    color: CheckoutFashionStyle.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.check_circle_rounded,
            color: CheckoutFashionStyle.textPrimary,
          ),
        ],
      ),
    );
  }
}
