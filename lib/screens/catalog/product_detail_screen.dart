import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/errors/api_exception.dart';
import '../../models/product.dart';
import '../../services/catalog service.dart';
import 'widgets/availability_sheet.dart';

class ProductDetailScreen extends StatefulWidget {
  final int productId;
  final int? branchId;

  const ProductDetailScreen({
    super.key,
    required this.productId,
    this.branchId,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  StoreProductDetail? _product;
  bool _isLoading = true;
  String? _error;

  int? _selectedSizeId;
  int? _selectedColorId;
  int _galleryIndex = 0;

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
      final detail = await StoreCatalogService.getProductDetail(
        widget.productId,
        branchId: widget.branchId,
      );

      setState(() {
        _product = detail;
        _isLoading = false;

        // Preselecciona la primera variante con stock, si existe.
        final firstAvailable = detail.variants
            .where((v) => v.hasStock)
            .cast<StoreProductVariant?>()
            .firstWhere((_) => true, orElse: () => null);

        final defaultVariant = firstAvailable ??
            detail.variants
                .cast<StoreProductVariant?>()
                .firstWhere((_) => true, orElse: () => null);

        _selectedSizeId = defaultVariant?.sizeId;
        _selectedColorId = defaultVariant?.colorId;
      });
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.message : 'No se pudo cargar el producto.';
        _isLoading = false;
      });
    }
  }

  StoreProductVariant? get _selectedVariant {
    if (_product == null) return null;
    return _product!.variantFor(
      sizeId: _selectedSizeId,
      colorId: _selectedColorId,
    );
  }

  void _openAvailability() {
    final variant = _selectedVariant;
    if (variant == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AvailabilitySheet(
        productId: widget.productId,
        productName: _product!.name,
        variantId: variant.id,
        variantLabel: '${variant.size.name} · ${variant.color.name}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(_product?.name ?? 'Detalle'),
      ),
      body: _buildBody(),
      bottomNavigationBar: _product == null ? null : _buildBottomBar(),
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

    final product = _product!;
    final variant = _selectedVariant;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _buildGallery(product),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${product.category.name} · ${product.audience.name}'
                    '${product.brand != null ? ' · ${product.brand}' : ''}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              Text(
                variant != null
                    ? 'Bs ${variant.finalPrice.toStringAsFixed(2)}'
                    : product.priceLabel,
                style: const TextStyle(
                  color: AppColors.primaryLight,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (product.description != null) ...[
                const SizedBox(height: 16),
                Text(
                  product.description!,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(height: 20),
              _buildSizeSelector(product),
              const SizedBox(height: 16),
              _buildColorSelector(product),
              const SizedBox(height: 16),
              _buildStockInfo(variant),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGallery(StoreProductDetail product) {
    final images = product.images.isNotEmpty
        ? product.images.map((i) => i.imageUrl).toList()
        : (product.coverImageUrl != null ? [product.coverImageUrl!] : []);

    if (images.isEmpty) {
      return AspectRatio(
        aspectRatio: 1,
        child: Container(
          color: AppColors.surface,
          child: const Icon(
            Icons.checkroom,
            size: 64,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: PageView.builder(
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _galleryIndex = i),
            itemBuilder: (context, index) {
              return Image.network(
                images[index],
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.surface,
                  child: const Icon(
                    Icons.checkroom,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                ),
              );
            },
          ),
        ),
        if (images.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(images.length, (i) {
              final active = i == _galleryIndex;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : AppColors.divider,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  Widget _buildSizeSelector(StoreProductDetail product) {
    final sizes = product.availableSizes;
    if (sizes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Talla',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: sizes.map((size) {
            final selected = _selectedSizeId == size.id;
            final variantForSize = product.variantFor(
              sizeId: size.id,
              colorId: _selectedColorId,
            );
            final disabled = variantForSize != null && !variantForSize.hasStock;

            return ChoiceChip(
              label: Text(size.name),
              selected: selected,
              onSelected: (_) => setState(() => _selectedSizeId = size.id),
              selectedColor: AppColors.primary,
              backgroundColor: disabled
                  ? AppColors.background
                  : AppColors.surfaceLight,
              labelStyle: TextStyle(
                color: selected
                    ? Colors.white
                    : disabled
                    ? AppColors.textMuted
                    : AppColors.textPrimary,
                decoration: disabled ? TextDecoration.lineThrough : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildColorSelector(StoreProductDetail product) {
    final colors = product.availableColors;
    if (colors.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Color',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: colors.map((color) {
            final selected = _selectedColorId == color.id;
            Color swatch = AppColors.divider;
            if (color.hexCode != null &&
                RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(color.hexCode!)) {
              swatch = Color(
                int.parse('FF${color.hexCode!.replaceFirst('#', '')}', radix: 16),
              );
            }

            return GestureDetector(
              onTap: () => setState(() => _selectedColorId = color.id),
              child: Column(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: swatch,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? AppColors.primary : AppColors.divider,
                        width: selected ? 3 : 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    color.name,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStockInfo(StoreProductVariant? variant) {
    if (variant == null) {
      return const Text(
        'Selecciona talla y color para ver el stock.',
        style: TextStyle(color: AppColors.textSecondary),
      );
    }

    return Row(
      children: [
        Icon(
          variant.hasStock ? Icons.check_circle_outline : Icons.cancel_outlined,
          size: 18,
          color: variant.hasStock ? AppColors.success : AppColors.error,
        ),
        const SizedBox(width: 6),
        Text(
          variant.hasStock
              ? '${variant.totalAvailable} unidades disponibles'
              : 'Sin stock disponible',
          style: TextStyle(
            color: variant.hasStock ? AppColors.success : AppColors.error,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    final variant = _selectedVariant;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: variant == null ? null : _openAvailability,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            icon: const Icon(Icons.storefront_outlined),
            label: const Text('Ver disponibilidad por sucursal'),
          ),
        ),
      ),
    );
  }
}