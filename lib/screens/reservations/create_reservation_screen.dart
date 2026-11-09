import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/branch.dart';
import '../../models/product_detail.dart';
import '../../models/reservation.dart';
import '../../services/reservation_service.dart';
import '../../services/offline_reservation_service.dart';
import '../../services/offline_sync_coordinator.dart';
import '../../core/network/connectivity_service.dart';
import 'offline_pending_reservations_screen.dart';
import '../../widgets/reservations/reservation_create_product_summary.dart';
import '../../widgets/reservations/reservation_pending_state.dart';
import '../../widgets/reservations/reservation_quantity_control.dart';

class CreateReservationScreen extends StatefulWidget {
  const CreateReservationScreen({
    super.key,
    required this.product,
    required this.variant,
    required this.branch,
  });

  final ProductDetail product;
  final ProductDetailVariant variant;
  final StoreBranch branch;

  @override
  State<CreateReservationScreen> createState() =>
      _CreateReservationScreenState();
}

class _CreateReservationScreenState
    extends State<CreateReservationScreen> {
  final _notesController = TextEditingController();

  int _quantity = 1;

  bool _loading = false;
  bool _checkingPending = false;
  bool _pendingChecked = false;

  String _pendingCheckError = '';
  String _errorMessage = '';

  Reservation? _pendingReservation;

  int _pendingCheckRequestId = 0;

  int get _maxQuantity => widget.variant.totalAvailable;

  double get _unitPrice => widget.variant.finalPrice;

  double get _totalPrice => _unitPrice * _quantity;

  bool get _canSubmit =>
      !_loading &&
      !_checkingPending &&
      widget.variant.hasStock &&
      _maxQuantity > 0;

  String get _actionLabel {
    if (_loading) {
      return _pendingReservation != null
          ? 'Agregando...'
          : 'Reservando...';
    }

    return _pendingReservation != null
        ? 'Agregar a mi reserva'
        : 'Confirmar reserva';
  }

  @override
  void initState() {
    super.initState();
    _checkPendingReservation();
  }

  @override
  void dispose() {
    _pendingCheckRequestId++;
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _checkPendingReservation() async {
    final requestId = ++_pendingCheckRequestId;
    final branchId = widget.branch.id;

    setState(() {
      _checkingPending = true;
      _pendingChecked = false;
      _pendingCheckError = '';
      _pendingReservation = null;
    });

    try {
      final reservation =
          await ReservationService.getMyPendingReservation(
        branchId,
      ).timeout(
        const Duration(seconds: 8),
      );

      if (!mounted ||
          requestId != _pendingCheckRequestId ||
          widget.branch.id != branchId) {
        return;
      }

      setState(() {
        _pendingReservation = reservation;
        _pendingCheckError = '';
      });
    } on TimeoutException {
      if (!mounted || requestId != _pendingCheckRequestId) {
        return;
      }

      setState(() {
        _pendingReservation = null;
        _pendingCheckError =
            'No pudimos comprobar tu reserva pendiente a tiempo. Puedes continuar: el backend volverá a validarla al confirmar.';
      });
    } catch (error) {
      if (!mounted || requestId != _pendingCheckRequestId) {
        return;
      }

      final message =
          error.toString().replaceFirst('Exception: ', '');

      setState(() {
        _pendingReservation = null;

        if (message.toLowerCase().contains('sesión') ||
            message.contains('401') ||
            message.contains('403')) {
          _pendingCheckError =
              'No se pudo validar la reserva porque tu sesión cambió.';
        } else {
          _pendingCheckError =
              'No pudimos comprobar tu reserva pendiente. Puedes continuar: el backend volverá a validarla al confirmar.';
        }
      });
    } finally {
      if (!mounted || requestId != _pendingCheckRequestId) {
        return;
      }

      setState(() {
        _checkingPending = false;
        _pendingChecked = true;
      });
    }
  }

  Future<void> _submit() async {
    if (_loading || _checkingPending) return;

    setState(() {
      _errorMessage = '';
    });

    if (!widget.variant.hasStock || _maxQuantity <= 0) {
      setState(() {
        _errorMessage =
            'Esta variante ya no tiene stock disponible.';
      });
      return;
    }

    if (_quantity < 1) {
      setState(() {
        _errorMessage =
            'La cantidad debe ser mayor a cero.';
      });
      return;
    }

    if (_quantity > _maxQuantity) {
      setState(() {
        _errorMessage =
            'Solo hay $_maxQuantity unidades disponibles.';
      });
      return;
    }

    final item = ReservationItemRequest(
      productVariantId: widget.variant.id,
      quantity: _quantity,
    );

    final notes = _notesController.text.trim();

    setState(() {
      _loading = true;
    });

    try {
      // Solo guardar localmente si verificamos que FastAPI no está disponible
      // ANTES de enviar el POST. Nunca poner en cola una petición que pudo
      // haber llegado al servidor y respondió con timeout.
      final canReachServer = await ConnectivityService.instance.canSyncNow();
      if (!canReachServer) {
        final operationId = await OfflineReservationService.savePending(
          branchId: widget.branch.id,
          variantId: widget.variant.id,
          quantity: _quantity,
          unitPrice: _unitPrice,
          notes: notes,
          productName: widget.product.name,
          sizeName: widget.variant.size.name,
          colorName: widget.variant.color.name,
          branchName: widget.branch.name,
        );
        await OfflineSyncCoordinator.instance.startForBranch(widget.branch.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Reserva guardada en este teléfono (pendiente). ID: ${operationId.substring(0, 8)}. Aún NO está confirmada.'),
          duration: const Duration(seconds: 6),
        ));
        Navigator.pop(context);
        return;
      }

      final Reservation reservation;

      if (_pendingReservation != null) {
        reservation =
            await ReservationService.addItemsToMyReservation(
          reservationId: _pendingReservation!.id,
          notes: notes,
          items: [item],
        );
      } else {
        reservation =
            await ReservationService.createMyReservation(
          branchId: widget.branch.id,
          notes: notes,
          items: [item],
        );
      }

      if (!mounted) return;

      Navigator.pop(context, reservation);
    } catch (error) {
      if (!mounted) return;

      final detail =
          error.toString().replaceFirst('Exception: ', '');

      /*
       * Igual que Angular:
       * si el backend detecta una carrera y avisa que ya hay una
       * reserva PENDING, resincronizamos para que el próximo intento
       * agregue la prenda a esa misma reserva.
       */
      if (detail.contains('PENDING')) {
        setState(() {
          _errorMessage =
              'Ya tienes una reserva pendiente en esta sucursal. La estamos cargando para que agregues esta prenda.';
        });

        await _checkPendingReservation();
      } else {
        setState(() {
          _errorMessage = detail.isEmpty
              ? 'No se pudo guardar la reserva. Inténtalo nuevamente.'
              : detail;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _decreaseQuantity() {
    if (_quantity <= 1) return;

    setState(() {
      _quantity--;
    });
  }

  void _increaseQuantity() {
    if (_quantity >= _maxQuantity) return;

    setState(() {
      _quantity++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: Text(
          _pendingReservation != null
              ? 'Agregar a reserva'
              : 'Reservar prenda',
        ),
        actions: [
          IconButton(
            tooltip: 'Operaciones locales',
            icon: const Icon(Icons.pending_actions_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute<void>(
              builder: (_) => OfflinePendingReservationsScreen(branchId: widget.branch.id),
            )),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  24,
                ),
                children: [
                  Text(
                    _pendingReservation != null
                        ? 'Ya tienes una reserva pendiente en esta sucursal.'
                        : 'Revisa los datos antes de confirmar tu reserva.',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ReservationCreateProductSummary(
                    product: widget.product,
                    variant: widget.variant,
                    branch: widget.branch,
                  ),
                  const SizedBox(height: 14),
                  ReservationPendingState(
                    checking: _checkingPending,
                    checked: _pendingChecked,
                    pendingReservation: _pendingReservation,
                    branchName: widget.branch.name,
                    errorMessage: _pendingCheckError,
                  ),
                  const SizedBox(height: 18),
                  _Section(
                    title: 'Cantidad',
                    trailing:
                        '$_maxQuantity disponibles',
                    child: ReservationQuantityControl(
                      quantity: _quantity,
                      maxQuantity: _maxQuantity,
                      disabled:
                          _loading || _checkingPending,
                      onDecrease: _decreaseQuantity,
                      onIncrease: _increaseQuantity,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _Section(
                    title: 'Observación',
                    trailing: 'Opcional',
                    child: TextField(
                      controller: _notesController,
                      enabled:
                          !_loading && !_checkingPending,
                      maxLines: 3,
                      maxLength: 2000,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText:
                            'Ej.: Pasaré mañana por la tarde.',
                        hintStyle: const TextStyle(
                          color: AppColors.textMuted,
                        ),
                        filled: true,
                        fillColor: AppColors.surface,
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: AppColors.divider,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _PriceSummary(
                    unitPrice: _unitPrice,
                    quantity: _quantity,
                    total: _totalPrice,
                  ),
                  const SizedBox(height: 16),
                  _ReservationNotice(
                    hasPending:
                        _pendingReservation != null,
                    branchName: widget.branch.name,
                  ),
                  if (_errorMessage.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _ErrorBox(
                      message: _errorMessage,
                    ),
                  ],
                ],
              ),
            ),
            _BottomActions(
              loading: _loading,
              canSubmit: _canSubmit,
              actionLabel: _actionLabel,
              onCancel: () {
                if (!_loading) {
                  Navigator.pop(context);
                }
              },
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final String? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _PriceSummary extends StatelessWidget {
  const _PriceSummary({
    required this.unitPrice,
    required this.quantity,
    required this.total,
  });

  final double unitPrice;
  final int quantity;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          _PriceRow(
            label: 'Precio unitario',
            value: 'Bs ${unitPrice.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 10),
          _PriceRow(
            label: 'Cantidad',
            value: '$quantity',
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(
              height: 1,
              color: AppColors.divider,
            ),
          ),
          _PriceRow(
            label: 'Total referencial',
            value: 'Bs ${total.toStringAsFixed(2)}',
            emphasize: true,
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
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
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: emphasize
                ? AppColors.primaryLight
                : AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: emphasize ? 17 : 14,
          ),
        ),
      ],
    );
  }
}

class _ReservationNotice extends StatelessWidget {
  const _ReservationNotice({
    required this.hasPending,
    required this.branchName,
  });

  final bool hasPending;
  final String branchName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.primaryLight,
            size: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasPending
                  ? 'La prenda se agregará a tu solicitud pendiente. El plazo de 24 horas todavía no corre: comenzará cuando la sucursal confirme la reserva.'
                  : 'Al confirmar, enviarás una solicitud de reserva a $branchName. Cuando la sucursal la confirme, comenzará el plazo de 24 horas para recoger y pagar presencialmente.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.error,
            size: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.loading,
    required this.canSubmit,
    required this.actionLabel,
    required this.onCancel,
    required this.onSubmit,
  });

  final bool loading;
  final bool canSubmit;
  final String actionLabel;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        16,
        12,
        16,
        16,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.divider),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: loading ? null : onCancel,
                child: const Text('Cancelar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: canSubmit ? onSubmit : null,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (loading) ...[
                      const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(width: 9),
                    ],
                    Flexible(
                      child: Text(
                        actionLabel,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
