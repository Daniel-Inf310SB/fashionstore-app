import 'package:flutter/material.dart';

import '../../models/order.dart';

class PaymentOrderSummaryCard extends StatelessWidget {
  const PaymentOrderSummaryCard({
    super.key,
    required this.order,
  });

  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFE3E3E3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'COMPRA',
            style: TextStyle(
              color: const Color(0xFF151515),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            order.orderCode,
            style: const TextStyle(
              color: const Color(0xFF151515),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          _Row(
            label: 'Estado',
            value: _statusLabel(order.status),
          ),
          const SizedBox(height: 9),
          _Row(
            label: 'Sucursal',
            value: order.branch.name,
          ),
          const SizedBox(height: 9),
          _Row(
            label: 'Entrega',
            value: order.deliveryLabel,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 13),
            child: Divider(
              height: 1,
              color: const Color(0xFFE3E3E3),
            ),
          ),
          _Row(
            label: 'Total',
            value:
                'Bs ${order.totalAmount.toStringAsFixed(2)}',
            emphasize: true,
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'PENDING_PAYMENT':
        return 'Pendiente de pago';
      case 'PAYMENT_FAILED':
        return 'Pago fallido';
      case 'PAID':
        return 'Pagada';
      case 'PREPARING':
        return 'En preparación';
      case 'READY_FOR_PICKUP':
        return 'Lista para recoger';
      case 'SHIPPED':
        return 'Enviada';
      case 'DELIVERED':
        return 'Entregada';
      case 'COMPLETED':
        return 'Finalizada';
      case 'CANCELLED':
        return 'Cancelada';
      case 'REFUNDED':
        return 'Reembolsada';
      default:
        return status;
    }
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: const Color(0xFF626262),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: emphasize
                  ? const Color(0xFF151515)
                  : const Color(0xFF151515),
              fontSize: emphasize ? 19 : 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
