import 'package:flutter/material.dart';

import 'checkout_fashion_style.dart';
import '../../models/order.dart';

class CheckoutSummaryCard extends StatelessWidget {
  const CheckoutSummaryCard({
    super.key,
    required this.preview,
    required this.creating,
    required this.onCreateOrder,
  });

  final CheckoutPreview preview;
  final bool creating;
  final VoidCallback onCreateOrder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: CheckoutFashionStyle.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: CheckoutFashionStyle.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RESUMEN',
            style: TextStyle(
              color: CheckoutFashionStyle.primaryLight,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Compra',
            style: TextStyle(
              color: CheckoutFashionStyle.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 15),
          _SummaryRow(
            label: 'Productos',
            value: '${preview.totalItems}',
          ),
          const SizedBox(height: 9),
          _SummaryRow(
            label: 'Unidades',
            value: '${preview.totalUnits}',
          ),
          const SizedBox(height: 9),
          _SummaryRow(
            label: 'Subtotal',
            value: 'Bs ${preview.subtotal.toStringAsFixed(2)}',
          ),
          if (preview.discountAmount > 0) ...[
            const SizedBox(height: 9),
            _SummaryRow(
              label: 'Descuento',
              value:
                  '- Bs ${preview.discountAmount.toStringAsFixed(2)}',
              valueColor: CheckoutFashionStyle.success,
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 13),
            child: Divider(
              height: 1,
              color: CheckoutFashionStyle.divider,
            ),
          ),
          _SummaryRow(
            label: 'Total',
            value: 'Bs ${preview.totalAmount.toStringAsFixed(2)}',
            emphasize: true,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: CheckoutFashionStyle.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFBDBDBD),
                disabledForegroundColor: Colors.white,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
              onPressed: creating ? null : onCreateOrder,
              icon: creating
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.arrow_forward_rounded),
              label: Text(
                creating
                    ? 'Creando compra...'
                    : 'CONTINUAR AL PAGO',
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'El monto vuelve a validarse en backend. La app no decide el precio final.',
            style: TextStyle(
              color: CheckoutFashionStyle.textMuted,
              fontSize: 10,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
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
                  ? CheckoutFashionStyle.textPrimary
                  : CheckoutFashionStyle.textSecondary,
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
                    ? CheckoutFashionStyle.primaryLight
                    : CheckoutFashionStyle.textPrimary),
            fontWeight: FontWeight.w800,
            fontSize: emphasize ? 19 : 14,
          ),
        ),
      ],
    );
  }
}
