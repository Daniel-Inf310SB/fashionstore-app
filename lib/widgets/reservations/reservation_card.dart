import 'package:flutter/material.dart';

import '../../widgets/reservations/reservation_fashion_style.dart';
import '../../models/reservation.dart';
import 'reservation_status_chip.dart';

class ReservationCard extends StatelessWidget {
  const ReservationCard({
    super.key,
    required this.reservation,
    required this.onOpen,
    required this.onCancel,
    this.cancelling = false,
  });

  final Reservation reservation;
  final VoidCallback onOpen;
  final VoidCallback onCancel;
  final bool cancelling;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ReservationFashionStyle.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ReservationFashionStyle.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'RESERVA',
                      style: TextStyle(
                        color: ReservationFashionStyle.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      reservation.reservationCode,
                      style: const TextStyle(
                        color: ReservationFashionStyle.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Creada ${_date(reservation.createdAt)}',
                      style: const TextStyle(
                        color: ReservationFashionStyle.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              ReservationStatusChip(
                status: reservation.status,
                label: reservation.statusLabel,
              ),
            ],
          ),
          if (reservation.status == 'PENDING') ...[
            const SizedBox(height: 14),
            const _InfoBanner(
              icon: Icons.hourglass_top_rounded,
              title: 'Esperando confirmación',
              message:
                  'El plazo de 24 horas todavía no comenzó.',
              tone: ReservationFashionStyle.warning,
            ),
          ] else if (reservation.expirationRelevant &&
              reservation.expiresAt != null) ...[
            const SizedBox(height: 14),
            _InfoBanner(
              icon: Icons.timer_outlined,
              title: reservation.expirationLabel(),
              message:
                  'Límite: ${_date(reservation.expiresAt!)}',
              tone: reservation.expiringSoon
                  ? ReservationFashionStyle.warning
                  : ReservationFashionStyle.primaryLight,
            ),
          ] else if (reservation.status == 'EXPIRED') ...[
            const SizedBox(height: 14),
            const _InfoBanner(
              icon: Icons.hourglass_disabled_rounded,
              title: 'Reserva vencida',
              message:
                  'El stock reservado fue liberado automáticamente.',
              tone: ReservationFashionStyle.error,
            ),
          ],
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: ReservationFashionStyle.primaryLight,
                size: 21,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sucursal de retiro',
                      style: TextStyle(
                        color: ReservationFashionStyle.textMuted,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      reservation.branch.name,
                      style: const TextStyle(
                        color: ReservationFashionStyle.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (reservation.branch.address.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        reservation.branch.address,
                        style: const TextStyle(
                          color: ReservationFashionStyle.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (reservation.items.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 58,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: reservation.items.length.clamp(0, 5),
                separatorBuilder: (_, __) =>
                    const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final item = reservation.items[index];
                  return _ItemPreview(item: item);
                },
              ),
            ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ReservationFashionStyle.surfaceLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _SummaryValue(
                    label: 'Unidades',
                    value: '${reservation.totalUnits}',
                  ),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: ReservationFashionStyle.divider,
                ),
                Expanded(
                  flex: 2,
                  child: _SummaryValue(
                    label: 'Total referencial',
                    value:
                        'Bs ${reservation.totalAmount.toStringAsFixed(2)}',
                    alignEnd: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onOpen,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ReservationFashionStyle.textPrimary,
                    side: const BorderSide(
                      color: ReservationFashionStyle.textPrimary,
                      width: 1.2,
                    ),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    'VER DETALLE',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
              if (reservation.canCancel) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: cancelling ? null : onCancel,
                    style: FilledButton.styleFrom(
                      backgroundColor: ReservationFashionStyle.textPrimary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFBDBDBD),
                      disabledForegroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Text(
                      cancelling ? 'CANCELANDO...' : 'CANCELAR',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static String _date(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$day/$month/${local.year} $hour:$minute';
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.title,
    required this.message,
    required this.tone,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: tone.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: tone, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: tone,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(
                    color: ReservationFashionStyle.textSecondary,
                    fontSize: 10,
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

class _ItemPreview extends StatelessWidget {
  const _ItemPreview({
    required this.item,
  });

  final ReservationItem item;

  @override
  Widget build(BuildContext context) {
    final image = item.variant.displayImageUrl;

    return Container(
      width: 58,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: ReservationFashionStyle.surfaceLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ReservationFashionStyle.divider),
      ),
      child: image != null && image.isNotEmpty
          ? Image.network(
              image,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(
                Icons.checkroom_rounded,
                color: ReservationFashionStyle.textMuted,
              ),
            )
          : const Icon(
              Icons.checkroom_rounded,
              color: ReservationFashionStyle.textMuted,
            ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: ReservationFashionStyle.textMuted,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: ReservationFashionStyle.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
