import 'dart:async';

import 'package:flutter/material.dart';

import '../../widgets/reservations/reservation_fashion_style.dart';
import '../../models/reservation.dart';
import '../../services/reservation_service.dart';
import '../../repositories/account_snapshot_repository.dart';
import '../../services/ai_assistant_context_service.dart';
import '../../widgets/reservations/reservation_status_chip.dart';

class ReservationDetailScreen extends StatefulWidget {
  const ReservationDetailScreen({
    super.key,
    required this.reservationId,
    this.initialReservation,
  });

  final int reservationId;
  final Reservation? initialReservation;

  @override
  State<ReservationDetailScreen> createState() =>
      _ReservationDetailScreenState();
}

class _ReservationDetailScreenState
    extends State<ReservationDetailScreen> {
  bool _loading = true;
  bool _cancelling = false;
  String? _error;
  Reservation? _reservation;
  bool _fromSnapshot = false;
  Timer? _clock;
  bool _expirationRefreshDone = false;

  @override
  void initState() {
    super.initState();

    AIAssistantContextService.setReservation(
      widget.reservationId,
    );

    if (widget.initialReservation != null) {
      _reservation = widget.initialReservation;
      _fromSnapshot = true;
    }
    _load();

    _clock = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (!mounted) return;

        final reservation = _reservation;

        if (reservation != null &&
            reservation.expirationRelevant &&
            reservation.expiredLocally &&
            !_expirationRefreshDone) {
          _expirationRefreshDone = true;
          _load(silent: true);
        } else {
          setState(() {});
        }
      },
    );
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _load({
    bool silent = false,
  }) async {
    // Primero mostrar el último detalle íntegro descargado, sin esperar la red.
    try {
      final cached = await const AccountSnapshotRepository()
          .readReservationDetail(widget.reservationId);
      if (cached != null && mounted &&
          (_reservation == null || _reservation!.items.isEmpty)) {
        setState(() {
          _reservation = Reservation.fromJson(cached);
          _fromSnapshot = true;
        });
      }
    } catch (error) {
      debugPrint('[FS-RESERVA-DETALLE] Caché no disponible: $error');
    }
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final reservation =
          await ReservationService.getMyReservation(
        widget.reservationId,
      );

      if (!mounted) return;

      setState(() {
        _reservation = reservation;
        _fromSnapshot = false;
        _expirationRefreshDone =
            reservation.status == 'EXPIRED' ||
            !reservation.expirationRelevant ||
            reservation.expiresAt == null;
      });
    } catch (error) {
      if (!mounted || silent) return;

      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        // Conservar la copia ya descargada cuando falle FastAPI.
      });
    } finally {
      if (mounted && !silent) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _cancel() async {
    final reservation = _reservation;

    if (reservation == null || _fromSnapshot ||
        !reservation.canCancel ||
        _cancelling) {
      return;
    }

    final controller = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: ReservationFashionStyle.surface,
          title: const Text(
            '¿Cancelar reserva?',
            style: TextStyle(
              color: ReservationFashionStyle.textPrimary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Cancelarás ${reservation.reservationCode}.',
                style: const TextStyle(
                  color: ReservationFashionStyle.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                maxLength: 255,
                maxLines: 3,
                style: const TextStyle(
                  color: ReservationFashionStyle.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: 'Motivo (opcional)',
                  filled: true,
                  fillColor: ReservationFashionStyle.surfaceLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text('Volver'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: ReservationFashionStyle.error,
              ),
              child: const Text('Sí, cancelar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      controller.dispose();
      return;
    }

    final reason = controller.text.trim();
    controller.dispose();

    setState(() {
      _cancelling = true;
    });

    try {
      final updated =
          await ReservationService.cancelMyReservation(
        reservation.id,
        reason: reason,
      );

      if (!mounted) return;

      setState(() {
        _reservation = updated;
        _expirationRefreshDone = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reserva cancelada correctamente.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Exception: ', ''),
          ),
          backgroundColor: ReservationFashionStyle.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _cancelling = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ReservationFashionStyle.theme(context),
      child: Scaffold(
      backgroundColor: ReservationFashionStyle.background,
      appBar: AppBar(
        backgroundColor: ReservationFashionStyle.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('Detalle de reserva'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    ),
    );
  }

  Widget _buildBody() {
    if (_loading && _reservation == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 220),
          Center(
            child: CircularProgressIndicator(),
          ),
        ],
      );
    }

    if (_error != null && _reservation == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 100),
          const Icon(
            Icons.error_outline_rounded,
            color: ReservationFashionStyle.error,
            size: 50,
          ),
          const SizedBox(height: 14),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ReservationFashionStyle.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _load,
            child: const Text('Reintentar'),
          ),
        ],
      );
    }

    final reservation = _reservation!;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        if (_fromSnapshot) const Card(child: Padding(
          padding: EdgeInsets.all(12), child: Text(
            'Detalle guardado en este teléfono. El estado y las fechas pueden haber cambiado. Para cancelar, vuelve a conectarte.',
            style: TextStyle(color: ReservationFashionStyle.textSecondary),
          ),
        )),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DETALLE DE RESERVA',
                    style: TextStyle(
                      color: ReservationFashionStyle.primaryLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    reservation.reservationCode,
                    style: const TextStyle(
                      color: ReservationFashionStyle.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Solicitada ${_date(reservation.createdAt)}',
                    style: const TextStyle(
                      color: ReservationFashionStyle.textSecondary,
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
        const SizedBox(height: 18),
        _buildExpiration(reservation),
        const SizedBox(height: 18),
        _Panel(
          title: 'Prendas reservadas',
          child: Column(
            children: reservation.items
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ReservationItemTile(item: item),
                  ),
                )
                .toList(),
          ),
        ),
        if (reservation.notes?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 14),
          _Panel(
            title: 'Observación',
            child: Text(
              reservation.notes!,
              style: const TextStyle(
                color: ReservationFashionStyle.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        _Panel(
          title: 'Resumen',
          child: Column(
            children: [
              _SummaryRow(
                label: 'Sucursal',
                value: reservation.branch.name,
              ),
              if (reservation.branch.address.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      bottom: 12,
                    ),
                    child: Text(
                      reservation.branch.address,
                      style: const TextStyle(
                        color: ReservationFashionStyle.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              const _SummaryRow(
                label: 'Pago',
                value: 'Presencial al recoger',
              ),
              _SummaryRow(
                label: 'Prendas',
                value: '${reservation.totalItems}',
              ),
              _SummaryRow(
                label: 'Unidades',
                value: '${reservation.totalUnits}',
              ),
              if (reservation.expiresAt != null)
                _SummaryRow(
                  label: 'Vence',
                  value: _date(reservation.expiresAt!),
                ),
              const Divider(color: ReservationFashionStyle.divider),
              _SummaryRow(
                label: 'Total referencial',
                value:
                    'Bs ${reservation.totalAmount.toStringAsFixed(2)}',
                emphasize: true,
              ),
              if (reservation.canCancel && !_fromSnapshot) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _cancelling ? null : _cancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ReservationFashionStyle.error,
                    ),
                    icon: _cancelling
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.cancel_outlined),
                    label: Text(
                      _cancelling
                          ? 'Cancelando...'
                          : 'Cancelar reserva',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExpiration(Reservation reservation) {
    if (reservation.status == 'PENDING') {
      return const _Notice(
        icon: Icons.hourglass_top_rounded,
        tone: ReservationFashionStyle.warning,
        title: 'Esperando confirmación de la sucursal',
        message:
            'El plazo de retiro todavía no ha comenzado. Cuando la sucursal confirme, tendrás 24 horas para recoger y pagar presencialmente.',
      );
    }

    if (reservation.status == 'EXPIRED') {
      return const _Notice(
        icon: Icons.hourglass_disabled_rounded,
        tone: ReservationFashionStyle.error,
        title: 'Reserva vencida',
        message:
            'El plazo terminó y el stock fue liberado automáticamente.',
      );
    }

    if (reservation.expirationRelevant &&
        reservation.expiresAt != null) {
      return _Notice(
        icon: Icons.timer_outlined,
        tone: reservation.expiringSoon
            ? ReservationFashionStyle.warning
            : ReservationFashionStyle.primaryLight,
        title: reservation.expirationLabel(),
        message:
            'Fecha límite: ${_date(reservation.expiresAt!)}. El plazo comenzó cuando la sucursal confirmó tu reserva.',
      );
    }

    if (reservation.status == 'READY') {
      return _Notice(
        icon: Icons.shopping_bag_outlined,
        tone: ReservationFashionStyle.success,
        title: '¡Tu reserva está lista!',
        message:
            'Ya puedes recogerla en ${reservation.branch.name}.',
      );
    }

    return const SizedBox.shrink();
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

class _Panel extends StatelessWidget {
  const _Panel({
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
        color: ReservationFashionStyle.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ReservationFashionStyle.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: ReservationFashionStyle.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ReservationItemTile extends StatelessWidget {
  const _ReservationItemTile({
    required this.item,
  });

  final ReservationItem item;

  @override
  Widget build(BuildContext context) {
    final image = item.variant.displayImageUrl;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 72,
          height: 82,
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
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.variant.product.brand?.isNotEmpty == true)
                Text(
                  item.variant.product.brand!,
                  style: const TextStyle(
                    color: ReservationFashionStyle.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              Text(
                item.variant.product.name,
                style: const TextStyle(
                  color: ReservationFashionStyle.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Talla ${item.variant.size.name} · Color ${item.variant.color.name}',
                style: const TextStyle(
                  color: ReservationFashionStyle.textSecondary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'SKU: ${item.variant.sku} · Cant. ${item.quantity}',
                style: const TextStyle(
                  color: ReservationFashionStyle.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Bs ${item.subtotal.toStringAsFixed(2)}',
          style: const TextStyle(
            color: ReservationFashionStyle.primaryLight,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: ReservationFashionStyle.textSecondary,
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
                    ? ReservationFashionStyle.primaryLight
                    : ReservationFashionStyle.textPrimary,
                fontWeight:
                    emphasize ? FontWeight.w800 : FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.tone,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final Color tone;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: tone.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tone),
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
                const SizedBox(height: 5),
                Text(
                  message,
                  style: const TextStyle(
                    color: ReservationFashionStyle.textSecondary,
                    height: 1.4,
                    fontSize: 12,
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
