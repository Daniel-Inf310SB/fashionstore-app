import 'package:flutter/material.dart';

import 'catalog_fashion_style.dart';

class ProductDetailGallery extends StatefulWidget {
  const ProductDetailGallery({
    super.key,
    required this.images,
    required this.productName,
    this.forcedImageUrl,
  });

  final List<String> images;
  final String productName;
  final String? forcedImageUrl;

  @override
  State<ProductDetailGallery> createState() =>
      _ProductDetailGalleryState();
}

class _ProductDetailGalleryState
    extends State<ProductDetailGallery> {
  int _index = 0;

  @override
  void didUpdateWidget(covariant ProductDetailGallery oldWidget) {
    super.didUpdateWidget(oldWidget);

    final forced = widget.forcedImageUrl;

    if (forced != null && forced.isNotEmpty) {
      final target = widget.images.indexOf(forced);

      if (target >= 0 && target != _index) {
        setState(() => _index = target);
      }
    } else if (_index >= widget.images.length) {
      setState(() => _index = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return _placeholder();
    }

    final safeIndex = _index.clamp(0, widget.images.length - 1);
    final selected = widget.images[safeIndex];

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 0.9,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: CatalogFashionColors.surface,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: CatalogFashionColors.divider),
            ),
            child: Image.network(
              selected,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder(),
            ),
          ),
        ),
        if (widget.images.length > 1) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 66,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.images.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final selectedThumb = index == safeIndex;

                return InkWell(
                  borderRadius: BorderRadius.circular(3),
                  onTap: () => setState(() => _index = index),
                  child: Container(
                    width: 58,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: selectedThumb
                            ? CatalogFashionColors.primary
                            : CatalogFashionColors.divider,
                        width: selectedThumb ? 2 : 1,
                      ),
                    ),
                    child: Image.network(
                      widget.images[index],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(
                        Icons.checkroom_rounded,
                        color: CatalogFashionColors.textMuted,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _placeholder() {
    return Container(
      color: CatalogFashionColors.surfaceLight,
      alignment: Alignment.center,
      child: const Icon(
        Icons.checkroom_rounded,
        color: CatalogFashionColors.textMuted,
        size: 72,
      ),
    );
  }
}
