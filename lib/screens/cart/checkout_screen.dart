import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/cart_item.dart';

/// Resumen previo al pago. CU32 solo cubre la gestión del carrito;
/// el flujo de pago (reservas/ventas) todavía no está conectado, así
/// que por ahora esta pantalla solo confirma lo que el cliente va a
/// llevar antes de continuar con un módulo siguiente.
class CheckoutScreen extends StatelessWidget {
  final Cart cart;

  const CheckoutScreen({super.key, required this.cart});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Resumen de compra'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (cart.branch != null)
            Text(
              'Retiro en ${cart.branch!.name}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          const SizedBox(height: 16),
          ...cart.items.map(
                (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${item.quantity}x ${item.productVariant.product.name} '
                          '(${item.productVariant.size.name} · ${item.productVariant.color.name})',
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                  ),
                  Text(
                    'Bs ${item.subtotal.toStringAsFixed(2)}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          const Divider(color: AppColors.divider, height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: TextStyle(color: AppColors.textSecondary)),
              Text(
                'Bs ${cart.totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: const Text(
              'El pago y la confirmación de la compra se conectarán en el '
                  'siguiente módulo.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}