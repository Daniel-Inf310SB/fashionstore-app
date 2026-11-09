import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../screens/profile/return_style.dart';
import '../../models/purchase_order.dart';

class PurchaseOrderCard extends StatelessWidget {
  const PurchaseOrderCard({
    super.key,
    required this.order,
    required this.now,
    required this.onTap,
  });

  final PurchaseOrder order;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = _tone(order.status);
    final expiration = order.paymentExpirationLabel(now);

    return Material(
      color: ReturnStyle.paper,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: ReturnStyle.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.orderCode,
                      style: const TextStyle(
                        color: ReturnStyle.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: tone.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      order.statusLabel,
                      style: TextStyle(
                        color: tone,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                '${_date(order.createdAt)} · ${order.deliveryLabel}',
                style: const TextStyle(
                  color: ReturnStyle.grey,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.storefront_outlined,
                    color: ReturnStyle.grey,
                    size: 17,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      order.branch.name,
                      style: const TextStyle(
                        color: ReturnStyle.grey,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              if (order.isReadyForPickup) ...[
                const SizedBox(height: 10),
                const _InfoBox(
                  text: 'Tu pedido está listo para recoger',
                  tone: AppColors.success,
                ),
              ],
              if (expiration.isNotEmpty) ...[
                const SizedBox(height: 10),
                _InfoBox(
                  text: expiration,
                  tone: order.paymentExpiringSoon(now)
                      ? AppColors.warning
                      : ReturnStyle.ink,
                ),
              ],
              const SizedBox(height: 13),
              Row(
                children: [
                  Text(
                    '${order.totalUnits} ${order.totalUnits == 1 ? 'unidad' : 'unidades'}',
                    style: const TextStyle(
                      color: ReturnStyle.grey,
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Bs ${order.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: ReturnStyle.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: ReturnStyle.grey,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _tone(String status) {
    if ([
      'PAID',
      'PREPARING',
      'READY_FOR_PICKUP',
      'SHIPPED',
      'DELIVERED',
      'COMPLETED',
    ].contains(status)) {
      return AppColors.success;
    }

    if (['PAYMENT_FAILED', 'CANCELLED'].contains(status)) {
      return AppColors.error;
    }

    if (status == 'REFUNDED') {
      return ReturnStyle.ink;
    }

    return AppColors.warning;
  }

  String _date(DateTime value) {
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    return '$d/$m/${value.year}';
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({
    required this.text,
    required this.tone,
  });

  final String text;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: tone,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
