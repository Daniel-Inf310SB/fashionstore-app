import 'package:flutter/material.dart';

import '../models/home_models.dart';
import '../models/product.dart';

/// Presentación del escaparate: sólo datos del endpoint /store/home.
/// No crea descuentos, imágenes ni productos simulados.
class HomeStorefront extends StatefulWidget {
  const HomeStorefront({super.key, required this.data, required this.onBanner,
    required this.onProduct, required this.onCategory, required this.onCollection,
    required this.onPromotion, required this.onCatalog});

  final HomeData data;
  final ValueChanged<HomeBanner> onBanner;
  final ValueChanged<int> onProduct;
  final ValueChanged<HomeCategory> onCategory;
  final ValueChanged<HomeCollection> onCollection;
  final ValueChanged<HomePromotion> onPromotion;
  final VoidCallback onCatalog;

  @override
  State<HomeStorefront> createState() => _HomeStorefrontState();
}

class _HomeStorefrontState extends State<HomeStorefront> {
  static const ink = Color(0xFF161616);
  static const muted = Color(0xFF777777);
  static const line = Color(0xFFE8E8E8);
  final PageController _pages = PageController();
  int _page = 0;

  @override
  void dispose() { _pages.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (data.banners.isNotEmpty) ...[
        SizedBox(height: 210, child: PageView.builder(
          controller: _pages,
          itemCount: data.banners.length,
          onPageChanged: (index) => setState(() => _page = index),
          itemBuilder: (context, index) {
            final banner = data.banners[index];
            return InkWell(
              onTap: () => widget.onBanner(banner),
              child: Stack(fit: StackFit.expand, children: [
                _Image(imageUrl: banner.displayImage, placeholder: Icons.checkroom_outlined),
                const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xB8000000)],
                ))),
                Positioned(left: 18, right: 16, bottom: 20, child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(banner.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900)),
                    if (banner.subtitle?.isNotEmpty == true)
                      Padding(padding: const EdgeInsets.only(top: 4), child: Text(banner.subtitle!,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 13))),
                    const SizedBox(height: 8),
                    const Text('DESCUBRIR  →', style: TextStyle(color: Colors.white,
                      fontSize: 11, letterSpacing: 1.3, fontWeight: FontWeight.w800)),
                  ],
                )),
              ]),
            );
          },
        )),
        if (data.banners.length > 1) Padding(padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(data.banners.length,
            (i) => AnimatedContainer(duration: const Duration(milliseconds: 180),
              width: i == _page ? 22 : 6, height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(color: i == _page ? ink : line,
                borderRadius: BorderRadius.circular(3))))),
        ),
      ] else ...[
        Container(width: double.infinity, padding: const EdgeInsets.all(22),
          color: const Color(0xFFF0F0F0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('FASHIONSTORE  /  DESCUBRE', style: TextStyle(color: muted,
              letterSpacing: 1.4, fontWeight: FontWeight.w700, fontSize: 10)),
            const SizedBox(height: 14),
            const Text('Encuentra tu próximo estilo.', style: TextStyle(color: ink,
              fontSize: 29, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            FilledButton(style: FilledButton.styleFrom(backgroundColor: ink,
                foregroundColor: Colors.white, shape: const RoundedRectangleBorder()),
              onPressed: widget.onCatalog, child: const Text('EXPLORAR CATÁLOGO')),
          ])),
      ],
      if (data.categories.isNotEmpty) ...[
        _heading('EXPLORA', 'Categorías', widget.onCatalog),
        SizedBox(height: 117, child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16), scrollDirection: Axis.horizontal,
          itemCount: data.categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 14),
          itemBuilder: (context, i) {
            final category = data.categories[i];
            return InkWell(onTap: () => widget.onCategory(category), child: SizedBox(width: 80,
              child: Column(children: [
                Container(height: 69, width: 69, alignment: Alignment.center,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF1F1F1)),
                  child: const Icon(Icons.checkroom_outlined, color: ink, size: 27)),
                const SizedBox(height: 6),
                Text(category.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center, style: const TextStyle(color: ink, fontSize: 11, fontWeight: FontWeight.w600)),
              ])));
          },
        )),
      ],
      if (data.offers.isNotEmpty) ...[
        _heading('PRECIOS ESPECIALES', 'Ofertas para ti', widget.onCatalog),
        _products(data.offers),
      ],
      if (data.collections.isNotEmpty) ...[
        _heading('INSPÍRATE', 'Colecciones', widget.onCatalog),
        SizedBox(height: 132, child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16), scrollDirection: Axis.horizontal,
          itemCount: data.collections.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final item = data.collections[index];
            return InkWell(onTap: () => widget.onCollection(item), child: Container(
              width: 190, padding: const EdgeInsets.all(15), color: const Color(0xFFF1F1F1),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Icon(Icons.style_outlined, color: ink),
                  Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: ink, fontSize: 16, fontWeight: FontWeight.w800)),
                  Text('${item.productCount} productos  →', style: const TextStyle(color: muted, fontSize: 11)),
                ])));
          },
        )),
      ],
      if (data.featuredProducts.isNotEmpty) ...[
        _heading('RECIÉN INCORPORADO', 'Novedades', widget.onCatalog),
        _products(data.featuredProducts),
      ],
      if (data.bestSellers.isNotEmpty) ...[
        _heading('LOS FAVORITOS', 'Más vendidos', widget.onCatalog),
        SizedBox(height: 175, child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal, itemCount: data.bestSellers.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final item = data.bestSellers[index];
            return InkWell(onTap: () => widget.onProduct(item.productId), child: SizedBox(width: 130,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(height: 114, width: 130,
                  child: _Image(imageUrl: item.coverImageUrl, placeholder: Icons.checkroom_outlined)),
                const SizedBox(height: 5),
                Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: ink, fontWeight: FontWeight.w600, fontSize: 12)),
                Text('${item.unitsSold} vendidos', style: const TextStyle(color: muted, fontSize: 10)),
              ])));
          },
        )),
      ],
      if (data.recommended.isNotEmpty) ...[
        _heading('PARA DESCUBRIR', 'Más estilos', widget.onCatalog),
        _products(data.recommended),
      ],
      if (data.promotions.isNotEmpty) ...[
        _heading('CAMPAÑAS VIGENTES', 'Promociones', widget.onCatalog),
        ...data.promotions.take(3).map((p) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: ListTile(tileColor: const Color(0xFFF3F3F3),
            title: Text(p.name, style: const TextStyle(color: ink, fontWeight: FontWeight.w700)),
            subtitle: Text(p.discountLabel, style: const TextStyle(color: muted)),
            trailing: const Icon(Icons.arrow_forward, color: ink),
            onTap: () => widget.onPromotion(p)),
        )),
      ],
      const SizedBox(height: 25),
    ]);
  }

  Widget _heading(String kicker, String title, VoidCallback action) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 26, 16, 12),
    child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(kicker, style: const TextStyle(color: muted, letterSpacing: 1.4, fontSize: 10, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text(title, style: const TextStyle(color: ink, fontSize: 21, fontWeight: FontWeight.w900)),
    ])), TextButton(onPressed: action,
      style: TextButton.styleFrom(foregroundColor: ink), child: const Text('Ver todo →'))]),
  );

  Widget _products(List<Product> products) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      itemCount: products.length > 6 ? 6 : products.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 10, childAspectRatio: 0.61),
      itemBuilder: (context, index) {
        final product = products[index];
        return InkWell(onTap: () => widget.onProduct(product.id), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Stack(fit: StackFit.expand, children: [
              _Image(imageUrl: product.coverImageUrl, placeholder: Icons.checkroom_outlined),
              if (product.hasDiscount) const Positioned(top: 0, left: 0,
                child: ColoredBox(color: ink, child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                  child: Text('OFERTA', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700))))),
            ])),
            const SizedBox(height: 7),
            Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: ink, fontSize: 12)),
            Row(children: [
              Text('Bs ${product.minPrice.toStringAsFixed(2)}',
                style: const TextStyle(color: ink, fontSize: 14, fontWeight: FontWeight.w900)),
              if (product.hasDiscount && product.originalMinPrice > product.minPrice) ...[
                const SizedBox(width: 6),
                Flexible(child: Text('Bs ${product.originalMinPrice.toStringAsFixed(0)}',
                  overflow: TextOverflow.ellipsis, style: const TextStyle(color: muted,
                    fontSize: 10, decoration: TextDecoration.lineThrough))),
              ],
            ]),
          ]));
      }),
  );
}

class _Image extends StatelessWidget {
  const _Image({required this.imageUrl, required this.placeholder});
  final String? imageUrl;
  final IconData placeholder;
  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url == null || !(url.startsWith('https://') || url.startsWith('http://'))) {
      return Container(color: const Color(0xFFECECEC),
        alignment: Alignment.center, child: Icon(placeholder, color: const Color(0xFF999999), size: 42));
    }
    return Image.network(url, fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(color: const Color(0xFFECECEC),
        alignment: Alignment.center, child: Icon(placeholder, color: const Color(0xFF999999), size: 42)));
  }
}
