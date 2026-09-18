import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/errors/api_exception.dart';
import '../../models/cart_item.dart';
import '../../services/cart_service.dart';
import 'checkout_screen.dart';

/// CU32 - Gestionar carrito de compras.
///
/// Si no se recibe [branchId], se usa la última sucursal en la que el
/// cliente agregó una prenda (ver [CartService.getLastBranchId]). Si
/// todavía no agregó nada, se muestra un estado vacío.
class CartScreen extends StatefulWidget {
  final int? branchId;

  const CartScreen({super.key, this.branchId});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  int? _branchId;
  MyCart? _myCart;
  bool _isLoading = true;
  String? _error;

  /// itemId -> true mientras esa fila tiene una petición en curso
  /// (actualizar cantidad o eliminar), para deshabilitar sus controles.
  final Set<int> _busyItemIds = {};
  bool _isClearing = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final branchId = widget.branchId ?? await CartService.getLastBranchId();

    if (!mounted) return;

    setState(() => _branchId = branchId);

    if (branchId != null) {
      await _load();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _load() async {
    if (_branchId == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final myCart = await CartService.getMyCart(branchId: _branchId!);
      if (!mounted) return;
      setState(() {
        _myCart = myCart;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'No se pudo cargar el carrito.';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateQuantity(CartLineItem item, int newQuantity) async {
    if (newQuantity < 1) {
      _removeItem(item);
      return;
    }

    setState(() => _busyItemIds.add(item.id));

    try {
      final cart = await CartService.updateItemQuantity(
        itemId: item.id,
        quantity: newQuantity,
      );
      _applyCart(cart);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busyItemIds.remove(item.id));
    }
  }

  Future<void> _removeItem(CartLineItem item) async {
    setState(() => _busyItemIds.add(item.id));

    try {
      final cart = await CartService.removeItem(itemId: item.id);
      _applyCart(cart);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busyItemIds.remove(item.id));
    }
  }

  Future<void> _clearCart() async {
    if (_branchId == null) return;

    setState(() => _isClearing = true);

    try {
      await CartService.clearCart(branchId: _branchId!);
      await _load();
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
  }

  void _applyCart(Cart cart) {
    if (!mounted) return;
    setState(() {
      _myCart = MyCart(
        branchId: cart.branchId ?? _branchId!,
        hasCart: cart.items.isNotEmpty,
        totalItems: cart.totalItems,
        totalUnits: cart.totalUnits,
        totalAmount: cart.totalAmount,
        cart: cart,
      );
    });
  }

  void _showError(Object e) {
    if (!mounted) return;
    final message = e is ApiException ? e.message : 'Ocurrió un error inesperado.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 70, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Carrito',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_myCart?.cart != null && _myCart!.cart!.items.isNotEmpty)
                  TextButton.icon(
                    onPressed: _isClearing ? null : _clearCart,
                    icon: _isClearing
                        ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.error,
                      ),
                    )
                        : const Icon(Icons.delete_sweep_outlined, size: 18),
                    label: const Text('Vaciar'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                  ),
              ],
            ),
            if (_myCart?.cart?.branch != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.storefront_outlined,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _myCart!.cart!.branch!.name,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Expanded(child: _buildBody()),
            if (_myCart?.cart != null && _myCart!.cart!.items.isNotEmpty)
              _buildTotalBar(_myCart!.cart!),
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

    if (_branchId == null) {
      return _buildEmptyState(
        icon: Icons.storefront_outlined,
        title: 'Todavía no elegiste una sucursal',
        message:
        'Agrega una prenda desde el catálogo para empezar tu carrito.',
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

    final cart = _myCart?.cart;

    if (cart == null || cart.items.isEmpty) {
      return _buildEmptyState(
        icon: Icons.shopping_cart_outlined,
        title: 'Tu carrito está vacío',
        message: 'Explora el catálogo y agrega las prendas que te gusten.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.builder(
        itemCount: cart.items.length,
        itemBuilder: (context, index) => _CartItemTile(
          item: cart.items[index],
          busy: _busyItemIds.contains(cart.items[index].id),
          onIncrement: (item) => _updateQuantity(item, item.quantity + 1),
          onDecrement: (item) => _updateQuantity(item, item.quantity - 1),
          onRemove: _removeItem,
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalBar(Cart cart) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${cart.totalUnits} ${cart.totalUnits == 1 ? 'unidad' : 'unidades'}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              Text(
                'Bs ${cart.totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CheckoutScreen(cart: cart),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Continuar compra'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  final CartLineItem item;
  final bool busy;
  final ValueChanged<CartLineItem> onIncrement;
  final ValueChanged<CartLineItem> onDecrement;
  final ValueChanged<CartLineItem> onRemove;

  const _CartItemTile({
    required this.item,
    required this.busy,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final variant = item.productVariant;
    final imageUrl = variant.displayImageUrl;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Opacity(
        opacity: busy ? 0.6 : 1,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 70,
                height: 90,
                child: imageUrl != null
                    ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const _ItemPlaceholder(),
                )
                    : const _ItemPlaceholder(),
              ),
            ),
            const SizedBox(width: 14),
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
                  const SizedBox(height: 6),
                  Text(
                    'Talla ${variant.size.name} · ${variant.color.name}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bs ${item.unitPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: AppColors.primaryLight,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _QuantityButton(
                        icon: Icons.remove,
                        onTap: busy ? null : () => onDecrement(item),
                      ),
                      SizedBox(
                        width: 32,
                        child: Text(
                          '${item.quantity}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _QuantityButton(
                        icon: Icons.add,
                        onTap: busy ? null : () => onIncrement(item),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              'Bs ${item.subtotal.toStringAsFixed(2)}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              onPressed: busy ? null : () => onRemove(item),
              icon: const Icon(Icons.delete_outline, color: AppColors.textSecondary),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemPlaceholder extends StatelessWidget {
  const _ItemPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceLight,
      child: const Icon(Icons.checkroom, color: AppColors.textSecondary, size: 32),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _QuantityButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.divider),
        ),
        child: Icon(icon, size: 14, color: AppColors.textPrimary),
      ),
    );
  }
}