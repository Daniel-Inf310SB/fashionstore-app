import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/errors/api_exception.dart';
import '../../../models/availability_model.dart';
import '../../../services/cart_service.dart';
import '../../../services/catalog service.dart';
import '../../reservations/create_reservation_screen.dart';

/// CU27 - Consultar disponibilidad por sucursal.
/// CU32 - Agregar al carrito directamente desde la sucursal elegida.
/// CU28 - Reservar la prenda para probarla en esa sucursal.
///
/// Se abre desde el detalle de producto una vez que el cliente eligió
/// una variante (talla + color) concreta.
class AvailabilitySheet extends StatefulWidget {
  final int productId;
  final String productName;
  final int variantId;
  final String variantLabel;

  const AvailabilitySheet({
    super.key,
    required this.productId,
    required this.productName,
    required this.variantId,
    required this.variantLabel,
  });

  @override
  State<AvailabilitySheet> createState() => _AvailabilitySheetState();
}

class _AvailabilitySheetState extends State<AvailabilitySheet> {
  ProductVariantAvailability? _availability;
  bool _isLoading = true;
  String? _error;

  /// branchId de la sucursal para la que hay una petición de
  /// "agregar al carrito" en curso.
  int? _addingBranchId;

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
      final result = await StoreCatalogService.getAvailability(
        widget.productId,
        variantId: widget.variantId,
      );

      setState(() {
        _availability = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.message : 'No se pudo consultar disponibilidad.';
        _isLoading = false;
      });
    }
  }

  Future<void> _addToCart(BranchAvailability branch) async {
    setState(() => _addingBranchId = branch.branchId);

    try {
      await CartService.addItem(
        branchId: branch.branchId,
        productVariantId: widget.variantId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Se agregó a tu carrito de ${branch.branchName}.'),
          backgroundColor: AppColors.success,
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      final message = e is ApiException ? e.message : 'No se pudo agregar al carrito.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _addingBranchId = null);
    }
  }

  Future<void> _reserve(BranchAvailability branch) async {
    final reservation = await Navigator.of(context).push<Object?>(
      MaterialPageRoute(
        builder: (_) => CreateReservationScreen(
          branchId: branch.branchId,
          branchName: branch.branchName,
          productVariantId: widget.variantId,
          productName: widget.productName,
          variantLabel: widget.variantLabel,
          maxQuantity: branch.availableQuantity,
        ),
      ),
    );

    if (reservation == null || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Reserva creada en ${branch.branchName}.'),
        backgroundColor: AppColors.success,
      ),
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
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
              const Text(
                'Disponibilidad por sucursal',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.variantLabel,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Expanded(child: _buildBody(scrollController)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(ScrollController scrollController) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: AppColors.error)),
      );
    }

    final branches = _availability!.branches;

    if (branches.isEmpty) {
      return const Center(
        child: Text(
          'Ninguna sucursal tiene esta variante en este momento.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.separated(
      controller: scrollController,
      itemCount: branches.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final branch = branches[index];
        final isAdding = _addingBranchId == branch.branchId;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    branch.hasStock
                        ? Icons.check_circle_outline
                        : Icons.remove_circle_outline,
                    color: branch.hasStock
                        ? AppColors.success
                        : AppColors.textMuted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          branch.branchName,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${branch.address} · ${branch.cityName}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        if (branch.phone != null)
                          Text(
                            branch.phone!,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    branch.hasStock
                        ? '${branch.availableQuantity} disp.'
                        : 'Agotado',
                    style: TextStyle(
                      color: branch.hasStock
                          ? AppColors.success
                          : AppColors.textMuted,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              if (branch.hasStock) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _reserve(branch),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.event_available_outlined, size: 16),
                        label: const Text('Reservar', style: TextStyle(fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isAdding ? null : () => _addToCart(branch),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor: AppColors.divider,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: isAdding
                            ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Icon(Icons.add_shopping_cart, size: 16, color: Colors.white),
                        label: const Text('Carrito', style: TextStyle(fontSize: 13, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}