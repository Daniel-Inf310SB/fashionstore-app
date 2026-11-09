import 'package:flutter/material.dart';

import 'cart_fashion_style.dart';
import '../../models/cart_item.dart';

class CustomerCartSummaryCard extends StatelessWidget {
  const CustomerCartSummaryCard({
    super.key,
    required this.cart,
    required this.branchName,
    required this.checkoutDisabled,
    required this.onCheckout,
  });

  final ShoppingCart cart;
  final String branchName;
  final bool checkoutDisabled;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: CartFashionStyle.paper,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: CartFashionStyle.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DETALLE DEL PEDIDO',
            style: TextStyle(
              color: CartFashionStyle.ink,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Resumen de compra',
            style: TextStyle(
              color: CartFashionStyle.ink,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (branchName.isNotEmpty) ...[
            const SizedBox(height: 13),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: CartFashionStyle.canvas,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: CartFashionStyle.ink,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sucursal',
                          style: TextStyle(
                            color: CartFashionStyle.muted,
                            fontSize: 9,
                          ),
                        ),
                        Text(
                          branchName,
                          style: const TextStyle(
                            color: CartFashionStyle.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 15),
          _Row(
            label: 'Productos distintos',
            value: '${cart.totalItems}',
          ),
          const SizedBox(height: 9),
          _Row(
            label: 'Unidades',
            value: '${cart.totalUnits}',
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 13),
            child: Divider(
              height: 1,
              color: CartFashionStyle.line,
            ),
          ),
          if (cart.hasDiscount) ...[
            _Row(
              label: 'Subtotal',
              value:
                  'Bs ${cart.originalTotalAmount.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 9),
            _Row(
              label: 'Descuento',
              value:
                  '- Bs ${cart.discountAmount.toStringAsFixed(2)}',
              valueColor: CartFashionStyle.success,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 13),
              child: Divider(
                height: 1,
                color: CartFashionStyle.line,
              ),
            ),
          ],
          _Row(
            label: 'Total',
            value:
                'Bs ${cart.totalAmount.toStringAsFixed(2)}',
            emphasize: true,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed:
                  checkoutDisabled ? null : onCheckout,
              icon: const Icon(
                Icons.lock_outline_rounded,
              ),
              label: const Text('CONTINUAR AL PAGO'),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'El stock y los precios se validarán nuevamente al continuar con la compra.',
            style: TextStyle(
              color: CartFashionStyle.muted,
              fontSize: 10,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.emphasize = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool emphasize;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: emphasize
                  ? CartFashionStyle.ink
                  : CartFashionStyle.grey,
              fontWeight:
                  emphasize ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ??
                (emphasize
                    ? CartFashionStyle.ink
                    : CartFashionStyle.ink),
            fontSize: emphasize ? 19 : 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
