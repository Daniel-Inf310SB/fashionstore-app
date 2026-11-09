import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/reservation.dart';

class ReservationPendingState extends StatelessWidget {
  const ReservationPendingState({
    super.key,
    required this.checking,
    required this.checked,
    required this.pendingReservation,
    required this.branchName,
    required this.errorMessage,
  });

  final bool checking;
  final bool checked;
  final Reservation? pendingReservation;
  final String branchName;
  final String errorMessage;

  @override
  Widget build(BuildContext context) {
    if (checking) {
      return _StateBox(
        icon: Icons.sync_rounded,
        tone: AppColors.primaryLight,
        title: 'Sincronizando tu reserva',
        message:
            'Comprobando si ya tienes una reserva pendiente en esta sucursal...',
        loading: true,
      );
    }

    final pending = pendingReservation;

    if (pending != null) {
      return _StateBox(
        icon: Icons.subdirectory_arrow_right_rounded,
        tone: AppColors.primaryLight,
        title: 'Ya tienes la reserva ${pending.reservationCode}',
        message:
            'Esta prenda se agregará a esa misma reserva en $branchName. El plazo de retiro todavía no comenzó.',
      );
    }

    if (errorMessage.isNotEmpty) {
      return _StateBox(
        icon: Icons.warning_amber_rounded,
        tone: AppColors.warning,
        title: 'No se pudo comprobar ahora',
        message: errorMessage,
      );
    }

    if (checked) {
      return _StateBox(
        icon: Icons.check_circle_outline_rounded,
        tone: AppColors.success,
        title: 'No tienes otra reserva pendiente aquí',
        message:
            'Al confirmar se creará una nueva reserva en $branchName.',
      );
    }

    return const SizedBox.shrink();
  }
}

class _StateBox extends StatelessWidget {
  const _StateBox({
    required this.icon,
    required this.tone,
    required this.title,
    required this.message,
    this.loading = false,
  });

  final IconData icon;
  final Color tone;
  final String title;
  final String message;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tone.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (loading)
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: tone,
              ),
            )
          else
            Icon(icon, color: tone, size: 22),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: tone,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
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
