import 'package:flutter/material.dart';


class PaymentExpirationBanner extends StatelessWidget {
  const PaymentExpirationBanner({
    super.key,
    required this.label,
    required this.deadline,
    required this.expired,
  });

  final String label;
  final String deadline;
  final bool expired;

  @override
  Widget build(BuildContext context) {
    final tone =
        expired ? const Color(0xFFB72C3A) : const Color(0xFF9A650F);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8ED),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFEAD8BA),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            expired
                ? Icons.hourglass_disabled_rounded
                : Icons.timer_outlined,
            color: tone,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: tone,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Límite: $deadline',
                  style: const TextStyle(
                    color: const Color(0xFF626262),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Si el plazo termina sin pago confirmado, la compra se cancelará y el stock reservado volverá a estar disponible.',
                  style: TextStyle(
                    color: const Color(0xFF868686),
                    fontSize: 10,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
