import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/catalog/catalog_fashion_style.dart';
import '../../core/network/app_error_message.dart';
import '../../core/constants/app_permissions.dart';
import '../../models/branch.dart';
import '../../models/product_detail.dart';
import '../../models/reservation.dart';
import '../../services/auth_service.dart';
import '../../services/ai_assistant_context_service.dart';
import '../../services/branch_service.dart';
import '../../services/cart_service.dart';
import '../../services/main_tab_navigation_service.dart';
import '../../repositories/offline_cart_repository.dart';
import '../../core/network/connectivity_service.dart';
import '../../services/product_service.dart';
import '../../services/selected_branch_service.dart';
import '../../widgets/catalog/branch_selector_sheet.dart';
import '../../widgets/catalog/product_detail_gallery.dart';
import '../../widgets/catalog/product_variant_selector.dart';
import '../auth/login_screen.dart';
import '../reservations/create_reservation_screen.dart';
import '../virtual_try_on/virtual_try_on_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.productId,
    this.onOpenCart,
  });

  final int productId;
  final VoidCallback? onOpenCart;

  @override
  State<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState
    extends State<ProductDetailScreen> {
  bool _loading = true;
  bool _loadingBranches = true;
  bool _addingToCart = false;

  String? _error;

  List<StoreBranch> _branches = const [];
  StoreBranch? _selectedBranch;

  ProductDetail? _product;
  bool _fromCache = false;
  int? _selectedSizeId;
  int? _selectedColorId;
  ProductDetailVariant? _selectedVariant;

  bool _virtualTryOnVariantConfirmed = false;

  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    ConnectivityService.instance.status.addListener(_onConnectivityChanged);
    _onConnectivityChanged();

    AIAssistantContextService.setProduct(
      productId: widget.productId,
    );

    _bootstrap();
  }

  ConnectionStatus? _lastConnection;

  void _onConnectivityChanged() {
    if (!mounted) return;
    final current = ConnectivityService.instance.status.value;
    if (current == _lastConnection) return;
    _lastConnection = current;
    if (current == ConnectionStatus.offline ||
        current == ConnectionStatus.networkOnly) {
      if (_product != null) setState(() => _fromCache = true);
      debugPrint('[FS-DETALLE] Servidor desconectado: conservando producto visible');
    } else if (current == ConnectionStatus.apiAvailable && !_loading) {
      if (_fromCache || _error != null) {
        debugPrint('[FS-DETALLE] Servidor recuperado: recargando producto');
        _bootstrap();
      }
    }
  }

  @override
  void dispose() {
    ConnectivityService.instance.status.removeListener(_onConnectivityChanged);
    AIAssistantContextService.setPage('catalog');
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await SelectedBranchService.initialize();
    await _loadBranches();

    if (!mounted) return;

    if (_selectedBranch == null) {
      setState(() {
        _loading = false;
        _error = 'No hay sucursales disponibles.';
      });
      return;
    }

    await _loadProduct();
  }

  Future<void> _loadBranches() async {
    setState(() {
      _loadingBranches = true;
    });

    try {
      final branches = await BranchService.getStoreBranches();

      if (!mounted) return;

      final stored = SelectedBranchService.selectedBranch;

      StoreBranch? selected = _selectedBranch;

      if (selected == null && stored != null) {
        for (final branch in branches) {
          if (branch.id == stored.id) {
            selected = branch;
            break;
          }
        }
      }

      selected ??=
          branches.isNotEmpty ? branches.first : null;

      setState(() {
        _branches = branches;
        _selectedBranch = selected;
      });

      if (selected != null) {
        await const OfflineCartRepository().refreshCount(selected.id);
      }

      if (selected != null &&
          stored?.id != selected.id) {
        await SelectedBranchService.selectBranch(selected);
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error =
            AppErrorMessage.from(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingBranches = false;
        });
      }
    }
  }

  Future<void> _loadProduct() async {
    final branch = _selectedBranch;

    if (branch == null) return;

    setState(() {
      _loading = true;
      _error = null;
      _product = null;
      _fromCache = false;
      _selectedSizeId = null;
      _selectedColorId = null;
      _selectedVariant = null;
      _virtualTryOnVariantConfirmed = false;
      _quantity = 1;
    });

    try {
      final result = await ProductService.getProductDetailWithSource(
        widget.productId,
        branchId: branch.id,
      );
      final product = result.detail;

      if (!mounted) return;

      setState(() {
        _product = product;
        _fromCache = result.fromCache;
      });

      _selectInitialVariant(product);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error =
            AppErrorMessage.from(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _selectInitialVariant(ProductDetail product) {
    if (product.variants.isEmpty) return;

    final variant = product.variants.firstWhere(
      (item) => item.hasStock,
      orElse: () => product.variants.first,
    );

    setState(() {
      _selectedSizeId = variant.sizeId;
      _selectedColorId = variant.colorId;
      _selectedVariant = variant;
      _quantity = 1;
    });

    AIAssistantContextService.setProduct(
      productId: widget.productId,
      variantId: variant.id,
    );
  }

  void _selectSize(int sizeId) {
    final product = _product;

    if (product == null) return;

    final colors = product.colorsForSize(sizeId);

    ProductDetailVariant? target;

    for (final color in colors) {
      final candidate = product.variantFor(
        sizeId: sizeId,
        colorId: color.id,
      );

      if (candidate?.hasStock == true) {
        target = candidate;
        break;
      }

      target ??= candidate;
    }

    setState(() {
      _virtualTryOnVariantConfirmed = true;
      _selectedSizeId = sizeId;
      _selectedColorId = target?.colorId;
      _selectedVariant = target;
      _quantity = 1;
    });

    AIAssistantContextService.setProduct(
      productId: widget.productId,
      variantId: target?.id,
    );
  }

  void _selectColor(int colorId) {
    final product = _product;

    if (product == null) return;

    final variant = product.variantFor(
      sizeId: _selectedSizeId,
      colorId: colorId,
    );

    setState(() {
      _virtualTryOnVariantConfirmed = true;
      _selectedColorId = colorId;
      _selectedVariant = variant;
      _quantity = 1;
    });

    AIAssistantContextService.setProduct(
      productId: widget.productId,
      variantId: variant?.id,
    );
  }

  Future<void> _chooseBranch() async {
    if (_loadingBranches || _branches.isEmpty) return;

    final selected = await showModalBottomSheet<StoreBranch>(
      context: context,
      backgroundColor: CatalogFashionColors.surface,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.78,
      ),
      builder: (_) => BranchSelectorSheet(
        branches: _branches,
        selectedBranchId: _selectedBranch?.id,
      ),
    );

    if (selected == null ||
        selected.id == _selectedBranch?.id ||
        !mounted) {
      return;
    }

    await SelectedBranchService.selectBranch(selected);

    if (!mounted) return;

    setState(() {
      _selectedBranch = selected;
    });

    await const OfflineCartRepository().refreshCount(selected.id);
    await _loadProduct();
  }

  Future<void> _openReservation() async {
    final product = _product;
    final variant = _selectedVariant;
    final branch = _selectedBranch;

    if (product == null || variant == null || branch == null) {
      return;
    }

    if (!variant.hasStock || variant.totalAvailable <= 0) {
      _showError('Esta variante no tiene stock en la sucursal.');
      return;
    }

    final reservation = await Navigator.push<Reservation>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateReservationScreen(
          product: product,
          variant: variant,
          branch: branch,
        ),
      ),
    );

    if (reservation == null || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Reserva ${reservation.reservationCode} guardada correctamente.',
        ),
      ),
    );

    await _loadProduct();
  }

  Future<void> _openVirtualTryOn() async {
    final product = _product;
    final variant = _selectedVariant;

    if (!_virtualTryOnVariantConfirmed ||
        product == null ||
        variant == null) {
      _showError(
        'Selecciona una talla y un color antes de usar el probador.',
      );
      return;
    }

    if (variant.imageUrl?.trim().isEmpty != false) {
      _showError(
        'Esta variante todavía no tiene una imagen disponible para el probador.',
      );
      return;
    }

    final loggedIn = await AuthService.isLoggedIn();

    if (!mounted) return;

    if (!loggedIn) {
      final goToLogin = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: CatalogFashionColors.surface,
            title: const Text(
              'Inicia sesión para usar el probador',
              style: TextStyle(
                color: CatalogFashionColors.textPrimary,
              ),
            ),
            content: const Text(
              'Necesitas iniciar sesión para generar una prueba virtual con IA.',
              style: TextStyle(
                color: CatalogFashionColors.textSecondary,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, false),
                child: const Text('Seguir mirando'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, true),
                child: const Text('Iniciar sesión'),
              ),
            ],
          );
        },
      );

      if (goToLogin == true && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const LoginScreen(),
          ),
        );
      }

      return;
    }

    final hasPermission = await AuthService.hasPermission(
      AppPermissions.virtualFittingUse,
    );

    if (!mounted) return;

    if (!hasPermission) {
      _showError(
        'Tu cuenta no tiene permiso para utilizar el probador virtual.',
      );
      return;
    }

    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => VirtualTryOnScreen(
          product: product,
          variant: variant,
        ),
      ),
    );

    if (!mounted) return;

    if (result == 'session_expired') {
      final goToLogin = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: CatalogFashionColors.surface,
            title: const Text(
              'Tu sesión ha expirado',
              style: TextStyle(
                color: CatalogFashionColors.textPrimary,
              ),
            ),
            content: const Text(
              'Inicia sesión nuevamente para continuar usando el probador virtual.',
              style: TextStyle(
                color: CatalogFashionColors.textSecondary,
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, true),
                child: const Text('Iniciar sesión'),
              ),
            ],
          );
        },
      );

      if (goToLogin == true && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const LoginScreen(),
          ),
        );
      }
    }
  }

  Future<void> _addToCart() async {
    final variant = _selectedVariant;
    final branch = _selectedBranch;

    if (variant == null || branch == null || _addingToCart) {
      return;
    }

    if (!variant.hasStock || variant.totalAvailable <= 0) {
      _showError('Esta variante no tiene stock disponible.');
      return;
    }

    if (_quantity > variant.totalAvailable) {
      _showError(
        'Solo hay ${variant.totalAvailable} unidades disponibles.',
      );
      return;
    }

    setState(() {
      _addingToCart = true;
    });

    try {
      // Nunca ponemos en cola un POST cuyo resultado es desconocido.
      // Si sabemos ANTES de enviar que no hay servidor, guardamos borrador.
      final available = await ConnectivityService.instance.canSyncNow();
      if (_fromCache || !available) {
        final product = _product!;
        await const OfflineCartRepository().add(
          branchId: branch.id,
          productId: product.id,
          variantId: variant.id,
          productName: product.name,
          variantLabel: '${variant.size.name} / ${variant.color.name}',
          unitPriceCents: (variant.finalPrice * 100).round(),
          quantity: _quantity,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:
          Text('Prenda guardada en tu carrito local. Todavía NO es una compra; revisa el borrador en Carrito.')));
        setState(() => _quantity = 1);
        return;
      }
      final result = await CartService.addItem(
        branchId: branch.id,
        productVariantId: variant.id,
        quantity: _quantity,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
        ),
      );

      setState(() {
        _quantity = 1;
      });
    } catch (error) {
      if (!mounted) return;

      _showError(
        error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() {
          _addingToCart = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: CatalogFashionColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = _product;

    return Scaffold(
      backgroundColor: CatalogFashionColors.background,
      appBar: AppBar(
        backgroundColor: CatalogFashionColors.background,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        foregroundColor: CatalogFashionColors.textPrimary,
        elevation: 0,
        title: const Text('DETALLE DE PRODUCTO', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 1.1)),
        actions: [
          AnimatedBuilder(
            animation: Listenable.merge([
              CartService.totalUnitsNotifier,
              OfflineCartRepository.draftUnitsNotifier,
            ]),
            builder: (context, _) {
              final total = CartService.totalUnitsNotifier.value +
                  OfflineCartRepository.draftUnitsNotifier.value;
              return IconButton(
                tooltip: 'Ir a mi carrito',
                onPressed: widget.onOpenCart ?? () =>
                    MainTabNavigationService.openCart(context),
                icon: Badge(
                  isLabelVisible: total > 0,
                  label: Text(total > 99 ? '99+' : '$total'),
                  child: const Icon(Icons.shopping_cart_outlined),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProduct,
        child: _buildBody(product),
      ),
    );
  }

  Widget _buildBody(ProductDetail? product) {
    if (_loading && product == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 220),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (_error != null && product == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 90),
          const Icon(
            Icons.error_outline_rounded,
            color: CatalogFashionColors.error,
            size: 52,
          ),
          const SizedBox(height: 14),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: CatalogFashionColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _bootstrap,
            child: const Text('Reintentar'),
          ),
        ],
      );
    }

    if (product == null) {
      return const SizedBox.shrink();
    }

    final variant = _selectedVariant;
    final selectedImage = variant?.resolveImage(product);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 36),
      children: [
        if (_fromCache) ...[
          const Card(child: Padding(
            padding: EdgeInsets.all(12),
            child: Row(children: [
              Icon(Icons.cloud_off_outlined), SizedBox(width: 10),
              Expanded(child: Text('Detalle guardado en SQLite. Precios y stock pueden haber cambiado. La reserva se guardará como pendiente hasta reconectar.')),
            ]),
          )),
          const SizedBox(height: 12),
        ],
        ProductDetailGallery(
          images: product.galleryUrls,
          productName: product.name,
          forcedImageUrl: selectedImage,
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 7,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (product.category.name.isNotEmpty)
              _MetaChip(label: product.category.name),
            if (product.audience.name.isNotEmpty)
              _MetaChip(label: product.audience.name),
            if (product.hasDiscount)
              const _MetaChip(
                label: 'OFERTA',
                highlighted: true,
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          product.name,
          style: const TextStyle(
            color: CatalogFashionColors.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (product.brand?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 4),
          Text(
            product.brand!,
            style: const TextStyle(
              color: CatalogFashionColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 12),
        _PriceBlock(
          finalPrice: variant?.finalPrice ?? product.minPrice,
          originalPrice:
              variant?.originalPrice ?? product.originalMinPrice,
          hasDiscount: product.hasDiscount,
        ),
        if (product.promotion != null) ...[
          const SizedBox(height: 10),
          _PromotionBox(
            promotion: product.promotion!,
          ),
        ],
        if (product.description?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 18),
          Text(
            product.description!,
            style: const TextStyle(
              color: CatalogFashionColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
        const Divider(color: CatalogFashionColors.divider, height: 36),
        ProductVariantSelector(
          product: product,
          selectedSizeId: _selectedSizeId,
          selectedColorId: _selectedColorId,
          onSizeSelected: _selectSize,
          onColorSelected: _selectColor,
        ),
        const Divider(color: CatalogFashionColors.divider, height: 36),
        _StockBox(
          branch: _selectedBranch,
          variant: variant,
          onChangeBranch: _chooseBranch,
        ),
        const SizedBox(height: 18),
        if (variant != null && variant.hasStock)
          _QuantitySelector(
            quantity: _quantity,
            max: variant.totalAvailable,
            onDecrease: () {
              if (_quantity > 1) {
                setState(() => _quantity--);
              }
            },
            onIncrease: () {
              if (_quantity < variant.totalAvailable) {
                setState(() => _quantity++);
              }
            },
          ),
        const SizedBox(height: 18),
        _VirtualTryOnLauncherCard(
          enabled: _virtualTryOnVariantConfirmed &&
              variant != null &&
              variant.imageUrl?.trim().isNotEmpty == true,
          helperText: !_virtualTryOnVariantConfirmed ||
                  variant == null
              ? 'Selecciona una talla y un color para activar el probador'
              : variant.imageUrl?.trim().isEmpty != false
                  ? 'Esta variante todavía no tiene imagen'
                  : 'Usa una foto tuya y genera una prueba virtual con IA',
          onTap: _openVirtualTryOn,
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    variant?.hasStock == true && !_addingToCart
                        ? _addToCart
                        : null,
                icon: _addingToCart
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.shopping_cart_outlined,
                      ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: CatalogFashionColors.textPrimary,
                  side: const BorderSide(color: CatalogFashionColors.textPrimary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                  minimumSize: const Size(0, 52),
                ),
                label: Text(
                  _addingToCart
                      ? 'Agregando...'
                      : 'Agregar al carrito',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed:
                    variant?.hasStock == true
                        ? _openReservation
                        : null,
                icon: const Icon(
                  Icons.event_available_rounded,
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: CatalogFashionColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                  minimumSize: const Size(0, 52),
                ),
                label: const Text('Reservar'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    this.highlighted = false,
  });

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: highlighted
            ? CatalogFashionColors.primary.withValues(alpha: 0.15)
            : CatalogFashionColors.surface,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: highlighted
              ? CatalogFashionColors.primary
              : CatalogFashionColors.divider,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: highlighted
              ? CatalogFashionColors.primaryLight
              : CatalogFashionColors.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PriceBlock extends StatelessWidget {
  const _PriceBlock({
    required this.finalPrice,
    required this.originalPrice,
    required this.hasDiscount,
  });

  final double finalPrice;
  final double originalPrice;
  final bool hasDiscount;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 10,
      runSpacing: 5,
      children: [
        Text(
          'Bs ${finalPrice.toStringAsFixed(2)}',
          style: const TextStyle(
            color: CatalogFashionColors.primaryLight,
            fontSize: 25,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (hasDiscount && originalPrice > finalPrice)
          Text(
            'Bs ${originalPrice.toStringAsFixed(2)}',
            style: const TextStyle(
              color: CatalogFashionColors.textMuted,
              fontSize: 14,
              decoration: TextDecoration.lineThrough,
              decorationColor: CatalogFashionColors.textMuted,
            ),
          ),
      ],
    );
  }
}

class _PromotionBox extends StatelessWidget {
  const _PromotionBox({
    required this.promotion,
  });

  final ProductDetailPromotion promotion;

  @override
  Widget build(BuildContext context) {
    final value = promotion.discountValue % 1 == 0
        ? promotion.discountValue.toStringAsFixed(0)
        : promotion.discountValue.toStringAsFixed(2);

    final discount =
        promotion.discountType.toUpperCase() == 'PERCENTAGE'
            ? '$value% OFF'
            : 'Bs $value OFF';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CatalogFashionColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: CatalogFashionColors.primary.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.local_offer_rounded,
            color: CatalogFashionColors.primaryLight,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${promotion.name} · $discount',
              style: const TextStyle(
                color: CatalogFashionColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StockBox extends StatelessWidget {
  const _StockBox({
    required this.branch,
    required this.variant,
    required this.onChangeBranch,
  });

  final StoreBranch? branch;
  final ProductDetailVariant? variant;
  final VoidCallback onChangeBranch;

  @override
  Widget build(BuildContext context) {
    final hasStock = variant?.hasStock == true;
    final stock = variant?.totalAvailable ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CatalogFashionColors.surface,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: CatalogFashionColors.divider),
      ),
      child: Row(
        children: [
          Icon(
            hasStock
                ? Icons.inventory_2_outlined
                : Icons.inventory_2_rounded,
            color:
                hasStock ? CatalogFashionColors.success : CatalogFashionColors.error,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  branch?.name ?? 'Selecciona una sucursal',
                  style: const TextStyle(
                    color: CatalogFashionColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hasStock
                      ? '$stock unidades disponibles'
                      : 'Sin stock de esta variante',
                  style: TextStyle(
                    color: hasStock
                        ? CatalogFashionColors.textSecondary
                        : CatalogFashionColors.error,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onChangeBranch,
            child: const Text('Cambiar'),
          ),
        ],
      ),
    );
  }
}

class _QuantitySelector extends StatelessWidget {
  const _QuantitySelector({
    required this.quantity,
    required this.max,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int quantity;
  final int max;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Cantidad',
          style: TextStyle(
            color: CatalogFashionColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        IconButton.outlined(
          onPressed: quantity > 1 ? onDecrease : null,
          icon: const Icon(Icons.remove_rounded),
        ),
        SizedBox(
          width: 42,
          child: Center(
            child: Text(
              '$quantity',
              style: const TextStyle(
                color: CatalogFashionColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        IconButton.outlined(
          onPressed: quantity < max ? onIncrease : null,
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }
}

class _VirtualTryOnLauncherCard extends StatelessWidget {
  const _VirtualTryOnLauncherCard({
    required this.enabled,
    required this.helperText,
    required this.onTap,
  });

  final bool enabled;
  final String helperText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CatalogFashionColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: CatalogFashionColors.primary.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: CatalogFashionColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: CatalogFashionColors.primaryLight,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Probador virtual',
                  style: TextStyle(
                    color: CatalogFashionColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  helperText,
                  style: const TextStyle(
                    color: CatalogFashionColors.textSecondary,
                    fontSize: 10,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: enabled ? onTap : null,
            style: FilledButton.styleFrom(
              backgroundColor: CatalogFashionColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Probar'),
          ),
        ],
      ),
    );
  }
}
