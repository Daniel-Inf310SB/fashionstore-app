import 'package:flutter/material.dart';

import 'cart_fashion_style.dart';
import '../../models/cart_item.dart';

class CustomerCartItemCard extends StatelessWidget {
  const CustomerCartItemCard({
    super.key,
    required this.item,
    required this.busy,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  final CartItem item;
  final bool busy;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: busy ? 0.60 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: CartFashionStyle.paper,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: CartFashionStyle.line),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProductImage(url: item.imageUrl),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productVariant.product.code,
                        style: const TextStyle(
                          color: CartFashionStyle.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.productVariant.product.name,
                        style: const TextStyle(
                          color: CartFashionStyle.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (item.productVariant.product.brand
                              ?.trim()
                              .isNotEmpty ==
                          true) ...[
                        const SizedBox(height: 3),
                        Text(
                          item.productVariant.product.brand!,
                          style: const TextStyle(
                            color: CartFashionStyle.grey,
                            fontSize: 11,
                          ),
                        ),
                      ],
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 7,
                        runSpacing: 5,
                        crossAxisAlignment:
                            WrapCrossAlignment.center,
                        children: [
                          _VariantBadge(
                            text:
                                'Talla ${item.productVariant.size.name}',
                          ),
                          _VariantBadge(
                            text:
                                'Color ${item.productVariant.color.name}',
                            colorHex:
                                item.productVariant.color.hexCode,
                          ),
                          _VariantBadge(
                            text:
                                'SKU ${item.productVariant.sku}',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Eliminar',
                  onPressed: busy ? null : onRemove,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: CartFashionStyle.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(
              height: 1,
              color: CartFashionStyle.line,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _QuantityControl(
                  quantity: item.quantity,
                  busy: busy,
                  onDecrease: () {
                    if (item.quantity > 1) {
                      onQuantityChanged(item.quantity - 1);
                    }
                  },
                  onIncrease: () {
                    onQuantityChanged(item.quantity + 1);
                  },
                ),
                const Spacer(),
                const SizedBox(width: 12),
                Flexible(
                  child: _PriceBlock(item: item),
                ),
              ],
            ),
            if (busy) ...[
              const SizedBox(height: 10),
              const Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Actualizando...',
                    style: TextStyle(
                      color: CartFashionStyle.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({
    required this.url,
  });

  final String? url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      height: 104,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: CartFashionStyle.canvas,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: CartFashionStyle.line),
      ),
      child: url != null && url!.isNotEmpty
          ? Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const _Placeholder(),
            )
          : const _Placeholder(),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.checkroom_rounded,
        color: CartFashionStyle.muted,
        size: 42,
      ),
    );
  }
}

class _VariantBadge extends StatelessWidget {
  const _VariantBadge({
    required this.text,
    this.colorHex,
  });

  final String text;
  final String? colorHex;

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(colorHex);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: CartFashionStyle.canvas,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (color != null) ...[
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: CartFashionStyle.line,
                ),
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: const TextStyle(
              color: CartFashionStyle.grey,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Color? _parseColor(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;

    var value = raw.trim().replaceFirst('#', '');

    if (value.length == 6) {
      value = 'FF$value';
    }

    final parsed = int.tryParse(value, radix: 16);

    return parsed == null ? null : Color(parsed);
  }
}

class _QuantityControl extends StatelessWidget {
  const _QuantityControl({
    required this.quantity,
    required this.busy,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int quantity;
  final bool busy;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _QuantityButton(
          icon: Icons.remove_rounded,
          onPressed:
              busy || quantity <= 1 ? null : onDecrease,
        ),
        SizedBox(
          width: 42,
          child: Center(
            child: Text(
              '$quantity',
              style: const TextStyle(
                color: CartFashionStyle.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        _QuantityButton(
          icon: Icons.add_rounded,
          onPressed: busy ? null : onIncrease,
        ),
      ],
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          side: const BorderSide(
            color: CartFashionStyle.line,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }
}

class _PriceBlock extends StatelessWidget {
  const _PriceBlock({
    required this.item,
  });

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (item.hasDiscount) ...[
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 5,
            runSpacing: 4,
            children: [
              if (item.promotionLabel.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: CartFashionStyle.ink
                        .withValues(alpha: 0.15),
                    borderRadius:
                        BorderRadius.circular(999),
                  ),
                  child: Text(
                    item.promotionLabel,
                    style: const TextStyle(
                      color: CartFashionStyle.ink,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              if (item.promotion != null)
                Text(
                  item.promotion!.name,
                  style: const TextStyle(
                    color: CartFashionStyle.muted,
                    fontSize: 9,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Bs ${item.originalUnitPrice.toStringAsFixed(2)} c/u',
            style: const TextStyle(
              color: CartFashionStyle.muted,
              fontSize: 10,
              decoration: TextDecoration.lineThrough,
              decorationColor: CartFashionStyle.muted,
            ),
          ),
        ],
        Text(
          'Bs ${item.unitPrice.toStringAsFixed(2)} c/u',
          style: const TextStyle(
            color: CartFashionStyle.grey,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 3),
        if (item.hasDiscount)
          Text(
            'Bs ${item.originalSubtotal.toStringAsFixed(2)}',
            style: const TextStyle(
              color: CartFashionStyle.muted,
              fontSize: 10,
              decoration: TextDecoration.lineThrough,
              decorationColor: CartFashionStyle.muted,
            ),
          ),
        Text(
          'Bs ${item.subtotal.toStringAsFixed(2)}',
          style: const TextStyle(
            color: CartFashionStyle.ink,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
