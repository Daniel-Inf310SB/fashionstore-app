import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../widgets/checkout/checkout_fashion_style.dart';
import '../../models/order.dart';
import '../../services/cart_service.dart';
import '../../services/selected_branch_service.dart';
import 'dart:async';
import '../../services/ai_assistant_context_service.dart';
import '../../services/order_service.dart';
import '../../widgets/checkout/checkout_delivery_selector.dart';
import '../../widgets/checkout/checkout_items_card.dart';
import '../../widgets/checkout/checkout_summary_card.dart';
import '../payments/payment_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.cartId,
  });

  final int cartId;

  @override
  State<CheckoutScreen> createState() =>
      _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  CheckoutPreview? _preview;

  bool _loading = true;
  bool _creating = false;

  String? _error;

  @override
  void initState() {
    super.initState();
    AIAssistantContextService.setPage('checkout');
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final preview =
          await OrderService.getCheckoutPreview(
        widget.cartId,
      );

      if (!mounted) return;

      setState(() {
        _preview = preview;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _preview = null;
        _error =
            error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _createOrder() async {
    final preview = _preview;

    if (preview == null || _creating) return;

    setState(() {
      _creating = true;
    });

    try {
      final order = await OrderService.createOrder(
        cartId: preview.cartId,
        deliveryType: 'PICKUP',
        shippingAddress: null,
      );

      // El backend ya creó el pedido: sincronizar el carrito real.
      // No asumir que el contador a cero significa carrito vacío.
      unawaited(CartService.refreshAfterPurchase(
        SelectedBranchService.selectedBranch?.id,
      ));

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentScreen(
            orderId: order.id,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Exception: ', ''),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _creating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;

    return Scaffold(
      backgroundColor: CheckoutFashionStyle.background,
      appBar: AppBar(
        backgroundColor: CheckoutFashionStyle.background,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: CheckoutFashionStyle.textPrimary),
        titleTextStyle: const TextStyle(
          color: CheckoutFashionStyle.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
        title: const Text('Finalizar compra'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadPreview,
        child: _buildBody(preview),
      ),
    );
  }

  Widget _buildBody(CheckoutPreview? preview) {
    if (_loading && preview == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 220),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (_error != null && preview == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        children: [
          const SizedBox(height: 100),
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 54,
          ),
          const SizedBox(height: 14),
          const Text(
            'No pudimos continuar',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: CheckoutFashionStyle.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: CheckoutFashionStyle.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: CheckoutFashionStyle.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: _loadPreview,
            child: const Text('Reintentar'),
          ),
        ],
      );
    }

    if (preview == null) {
      return const SizedBox.shrink();
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
      children: [
        const Text(
          'FASHIONSTORE / COMPRA SEGURA',
          style: TextStyle(
            color: CheckoutFashionStyle.primaryLight,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Revisa tu pedido',
          style: TextStyle(
            color: CheckoutFashionStyle.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Tu pedido se recogerá en la sucursal seleccionada. Revisa el resumen antes de pagar.',
          style: TextStyle(
            color: CheckoutFashionStyle.textSecondary,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 20),
        _CheckoutPanel(
          title: 'Entrega',
          child: CheckoutDeliverySelector(
            branchName: preview.branchName,
          ),
        ),
        const SizedBox(height: 14),
        CheckoutItemsCard(
          items: preview.items,
        ),
        const SizedBox(height: 14),
        CheckoutSummaryCard(
          preview: preview,
          creating: _creating,
          onCreateOrder: _createOrder,
        ),
      ],
    );
  }
}

class _CheckoutPanel extends StatelessWidget {
  const _CheckoutPanel({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

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
          Text(
            title,
            style: const TextStyle(
              color: CheckoutFashionStyle.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }
}
