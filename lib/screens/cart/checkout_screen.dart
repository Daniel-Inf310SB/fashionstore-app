import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/errors/api_exception.dart';
import '../../models/cart_item.dart';
import '../../models/purchase.dart';
import '../../services/order_service.dart';
import '../profile/purchase_history_screen.dart';

/// CU33 - Gestionar compra digital.
///
/// Resume el carrito y, al confirmar, crea la compra con
/// `OrderService.createOrder` (`POST /orders`). El backend convierte
/// el carrito y reserva el inventario; la compra queda en
/// `PENDING_PAYMENT` porque el pago electrónico (CU38/CU39) todavía
/// no tiene una ruta para el cliente.
class CheckoutScreen extends StatefulWidget {
  final Cart cart;

  const CheckoutScreen({super.key, required this.cart});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _isSubmitting = false;
  Order? _createdOrder;

  Future<void> _confirmPurchase() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final order = await OrderService.createOrder(cartId: widget.cart.id);
      if (!mounted) return;
      setState(() {
        _createdOrder = order;
        _isSubmitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);

      final message =
      e is ApiException ? e.message : 'No se pudo completar la compra.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _createdOrder;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        automaticallyImplyLeading: order == null,
        title: Text(order == null ? 'Resumen de compra' : 'Compra registrada'),
      ),
      body: order == null ? _buildSummary() : _buildConfirmation(order),
    );
  }

  // =========================================================
  // RESUMEN (ANTES DE CONFIRMAR)
  // =========================================================

  Widget _buildSummary() {
    final cart = widget.cart;

    return ListView(
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
            'Al confirmar, tu compra quedará registrada con pago '
                'pendiente. La pasarela de pago electrónico se conectará '
                'en un siguiente módulo.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _confirmPurchase,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.3,
                color: Colors.white,
              ),
            )
                : const Text('Confirmar compra'),
          ),
        ),
      ],
    );
  }

  // =========================================================
  // CONFIRMACIÓN (DESPUÉS DE CREAR LA COMPRA)
  // =========================================================

  Widget _buildConfirmation(Order order) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 72,
            ),
            const SizedBox(height: 20),
            const Text(
              '¡Tu compra fue registrada!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              order.orderCode,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Estado', style: TextStyle(color: AppColors.textSecondary)),
                      Text(
                        orderStatusLabel(order.status),
                        style: const TextStyle(
                          color: AppColors.warning,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: TextStyle(color: AppColors.textSecondary)),
                      Text(
                        'Bs ${order.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'El pago electrónico todavía no está disponible en la '
                        'app. Te avisaremos cuando puedas pagarla desde aquí.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const PurchaseHistoryScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Ver mis compras'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Volver al inicio'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}