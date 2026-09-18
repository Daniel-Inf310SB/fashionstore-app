import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/errors/api_exception.dart';
import '../../models/reservation.dart';
import '../../services/reservation_service.dart';

/// CU28 - Gestionar reservas (lado cliente): ver, filtrar y cancelar.
///
/// Las reservas se crean desde el detalle de producto (hoja de
/// disponibilidad por sucursal), no desde esta pantalla.
class ReservationsScreen extends StatefulWidget {
  const ReservationsScreen({super.key});

  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen> {
  List<Reservation> _reservations = [];
  bool _isLoading = true;
  String? _error;
  bool _activeOnly = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final page = await ReservationService.listMyReservations(
        pageSize: 50,
        activeOnly: _activeOnly,
      );
      if (!mounted) return;
      setState(() {
        _reservations = page.items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'No se pudieron cargar tus reservas.';
        _isLoading = false;
      });
    }
  }

  void _setFilter(bool activeOnly) {
    if (_activeOnly == activeOnly) return;
    setState(() => _activeOnly = activeOnly);
    _load();
  }

  Future<void> _openDetail(Reservation reservation) async {
    final updated = await showModalBottomSheet<Reservation>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReservationDetailSheet(reservation: reservation),
    );

    if (updated != null) {
      setState(() {
        _reservations = _reservations
            .map((r) => r.id == updated.id ? updated : r)
            .toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 70, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mis reservas',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Prendas reservadas para probar en sucursal.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _FilterChip(
                  label: 'Activas',
                  selected: _activeOnly,
                  onTap: () => _setFilter(true),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Todas',
                  selected: !_activeOnly,
                  onTap: () => _setFilter(false),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    if (_reservations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.event_available_outlined,
                size: 56,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 16),
              Text(
                _activeOnly ? 'No tienes reservas activas' : 'Todavía no reservaste ninguna prenda',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Elige "Reservar" en la disponibilidad de una prenda para probarla en sucursal.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.builder(
        itemCount: _reservations.length,
        itemBuilder: (context, index) {
          final reservation = _reservations[index];
          return _ReservationCard(
            reservation: reservation,
            onTap: () => _openDetail(reservation),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surfaceLight,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _ReservationCard extends StatelessWidget {
  final Reservation reservation;
  final VoidCallback onTap;

  const _ReservationCard({required this.reservation, required this.onTap});

  Color get _statusColor {
    switch (reservation.status) {
      case ReservationStatus.ready:
      case ReservationStatus.confirmed:
      case ReservationStatus.completed:
        return AppColors.success;
      case ReservationStatus.cancelled:
      case ReservationStatus.expired:
        return AppColors.error;
      case ReservationStatus.preparing:
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Reserva ${reservation.reservationCode}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  reservationStatusLabel(reservation.status),
                  style: TextStyle(color: _statusColor, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Sucursal: ${reservation.branch.name}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              '${reservation.totalItems} ${reservation.totalItems == 1 ? 'prenda reservada' : 'prendas reservadas'}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Detalle de una reserva con sus prendas y, si corresponde, el botón
/// para cancelarla (`can_cancel` viene calculado desde el backend).
class _ReservationDetailSheet extends StatefulWidget {
  final Reservation reservation;

  const _ReservationDetailSheet({required this.reservation});

  @override
  State<_ReservationDetailSheet> createState() => _ReservationDetailSheetState();
}

class _ReservationDetailSheetState extends State<_ReservationDetailSheet> {
  late Reservation _reservation = widget.reservation;
  bool _isCancelling = false;

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Cancelar reserva', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          '¿Seguro que quieres cancelar esta reserva?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sí, cancelar', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCancelling = true);

    try {
      final updated = await ReservationService.cancelReservation(_reservation.id);
      if (!mounted) return;
      setState(() => _reservation = updated);
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : 'No se pudo cancelar la reserva.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Reserva ${_reservation.reservationCode}',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(_reservation),
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  ),
                ],
              ),
              Text(
                reservationStatusLabel(_reservation.status),
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                _reservation.branch.name,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              if (_reservation.notes != null && _reservation.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _reservation.notes!,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: _reservation.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = _reservation.items[index];
                    final variant = item.productVariant;

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  variant.product.name,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Talla ${variant.size.name} · ${variant.color.name}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'x${item.quantity}',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (_reservation.canCancel) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _isCancelling ? null : _cancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isCancelling
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Text('Cancelar reserva'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}