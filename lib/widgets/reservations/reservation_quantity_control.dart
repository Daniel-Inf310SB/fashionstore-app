import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class ReservationQuantityControl extends StatelessWidget {
  const ReservationQuantityControl({
    super.key,
    required this.quantity,
    required this.maxQuantity,
    required this.disabled,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int quantity;
  final int maxQuantity;
  final bool disabled;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _QuantityButton(
          icon: Icons.remove_rounded,
          onPressed:
              disabled || quantity <= 1 ? null : onDecrease,
        ),
        SizedBox(
          width: 64,
          child: Center(
            child: Text(
              '$quantity',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        _QuantityButton(
          icon: Icons.add_rounded,
          onPressed: disabled || quantity >= maxQuantity
              ? null
              : onIncrease,
        ),
      ],
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          side: const BorderSide(color: AppColors.divider),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Icon(icon),
      ),
    );
  }
}
