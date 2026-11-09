import 'package:flutter/material.dart';

import '../../widgets/reservations/reservation_fashion_style.dart';

class ReservationStatusChip extends StatelessWidget {
  const ReservationStatusChip({
    super.key,
    required this.status,
    required this.label,
  });

  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tone = _tone(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: tone.withValues(alpha: 0.48),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: tone,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Color _tone(String status) {
    switch (status) {
      case 'READY':
      case 'COMPLETED':
      case 'ATTENDED':
        return ReservationFashionStyle.success;
      case 'CONFIRMED':
      case 'PREPARING':
        return ReservationFashionStyle.primaryLight;
      case 'PENDING':
        return ReservationFashionStyle.warning;
      case 'CANCELLED':
      case 'EXPIRED':
        return ReservationFashionStyle.error;
      default:
        return ReservationFashionStyle.textSecondary;
    }
  }
}
