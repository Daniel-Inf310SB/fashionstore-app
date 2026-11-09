import 'package:flutter/material.dart';

import 'catalog_fashion_style.dart';
import '../../models/product_detail.dart';

class ProductVariantSelector extends StatelessWidget {
  const ProductVariantSelector({
    super.key,
    required this.product,
    required this.selectedSizeId,
    required this.selectedColorId,
    required this.onSizeSelected,
    required this.onColorSelected,
  });

  final ProductDetail product;
  final int? selectedSizeId;
  final int? selectedColorId;
  final ValueChanged<int> onSizeSelected;
  final ValueChanged<int> onColorSelected;

  @override
  Widget build(BuildContext context) {
    final colors = product.colorsForSize(selectedSizeId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Talla',
          style: TextStyle(
            color: CatalogFashionColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: product.sizes.map((size) {
            final selected = selectedSizeId == size.id;
            final hasStock = product.variants.any(
              (variant) =>
                  variant.sizeId == size.id &&
                  variant.hasStock,
            );

            return ChoiceChip(
              label: Text(size.name),
              selected: selected,
              onSelected: (_) => onSizeSelected(size.id),
              selectedColor: CatalogFashionColors.primary,
              backgroundColor: CatalogFashionColors.surface,
              disabledColor: CatalogFashionColors.surfaceLight,
              side: BorderSide(
                color: selected
                    ? CatalogFashionColors.primary
                    : CatalogFashionColors.divider,
              ),
              labelStyle: TextStyle(
                color: selected
                    ? Colors.white
                    : hasStock
                        ? CatalogFashionColors.textSecondary
                        : CatalogFashionColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        const Text(
          'Color',
          style: TextStyle(
            color: CatalogFashionColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: colors.map((color) {
            final selected = selectedColorId == color.id;
            final variant = product.variantFor(
              sizeId: selectedSizeId,
              colorId: color.id,
            );
            final hasStock = variant?.hasStock == true;

            return ChoiceChip(
              avatar: _ColorDot(color: color),
              label: Text(color.name),
              selected: selected,
              onSelected: (_) => onColorSelected(color.id),
              selectedColor: CatalogFashionColors.primary,
              backgroundColor: CatalogFashionColors.surface,
              side: BorderSide(
                color: selected
                    ? CatalogFashionColors.primary
                    : CatalogFashionColors.divider,
              ),
              labelStyle: TextStyle(
                color: selected
                    ? Colors.white
                    : hasStock
                        ? CatalogFashionColors.textSecondary
                        : CatalogFashionColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
  });

  final ProductDetailColor color;

  @override
  Widget build(BuildContext context) {
    final parsed = _parseHex(color.hexCode);

    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: parsed ?? CatalogFashionColors.surfaceLight,
        shape: BoxShape.circle,
        border: Border.all(
          color: CatalogFashionColors.divider,
        ),
      ),
    );
  }

  Color? _parseHex(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;

    var value = raw.trim().replaceFirst('#', '');

    if (value.length == 6) {
      value = 'FF$value';
    }

    final parsed = int.tryParse(value, radix: 16);

    return parsed == null ? null : Color(parsed);
  }
}
