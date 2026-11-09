import 'package:flutter/material.dart';

import 'catalog_fashion_style.dart';
import '../../models/product.dart';

class CatalogProductCard extends StatelessWidget {
  const CatalogProductCard({
    super.key,
    required this.product,
    this.onTap,
  });

  final Product product;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.coverImageUrl;

    return Material(
      color: CatalogFashionColors.surface,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: CatalogFashionColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl != null && imageUrl.isNotEmpty)
                      Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const _ProductPlaceholder(),
                      )
                    else
                      const _ProductPlaceholder(),
                    if (product.hasDiscount)
                      Positioned(
                        top: 9,
                        left: 9,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: CatalogFashionColors.primary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: const Text(
                            'OFERTA',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    if (!product.hasStock)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.38),
                          alignment: Alignment.center,
                          child: const Text(
                            'AGOTADO',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.category.name.isEmpty
                          ? 'FashionStore'
                          : product.category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: CatalogFashionColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: CatalogFashionColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 7,
                      runSpacing: 3,
                      children: [
                        Text(
                          'Bs ${_price(product.minPrice)}',
                          style: const TextStyle(
                            color: CatalogFashionColors.primaryLight,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (product.hasDiscount &&
                            product.originalMinPrice >
                                product.minPrice)
                          Text(
                            'Bs ${_price(product.originalMinPrice)}',
                            style: const TextStyle(
                              color: CatalogFashionColors.textMuted,
                              fontSize: 10,
                              decoration: TextDecoration.lineThrough,
                              decorationColor: CatalogFashionColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      product.hasStock
                          ? '${product.totalAvailable} disponibles'
                          : 'Sin stock',
                      style: TextStyle(
                        color: product.hasStock
                            ? CatalogFashionColors.textMuted
                            : CatalogFashionColors.error,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _price(double value) {
    return value % 1 == 0
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }
}

class _ProductPlaceholder extends StatelessWidget {
  const _ProductPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: CatalogFashionColors.surfaceLight,
      alignment: Alignment.center,
      child: const Icon(
        Icons.checkroom_rounded,
        color: CatalogFashionColors.textMuted,
        size: 52,
      ),
    );
  }
}
