import 'dart:convert';
import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../../services/api_service.dart';
import '../../services/tenant_context_service.dart';
import '../catalog/product_detail_screen.dart';

/// Listado filtrado real para categorías, promociones y colecciones del Home.
class HomeSectionScreen extends StatefulWidget {
  const HomeSectionScreen({super.key, required this.title, required this.branchId,
    required this.kind, this.category, this.resourceId});

  final String title;
  final int branchId;
  final String kind; // category, collection, promotion
  final String? category;
  final int? resourceId;

  @override
  State<HomeSectionScreen> createState() => _HomeSectionScreenState();
}

class _HomeSectionScreenState extends State<HomeSectionScreen> {
  List<Product> _items = [];
  bool _loading = true;
  bool _more = false;
  String? _error;
  int _page = 0;
  int _totalPages = 1;

  @override
  void initState() { super.initState(); _load(reset: true); }

  Future<void> _load({required bool reset}) async {
    if (_more) return;
    final page = reset ? 1 : _page + 1;
    if (!reset && page > _totalPages) return;
    setState(() { if (reset) _loading = true; else _more = true; _error = null; });
    try {
      final path = widget.kind == 'category' ? '/store/catalog' :
          '/store/${widget.kind == 'collection' ? 'collections' : 'promotions'}/${widget.resourceId}/products';
      final endpoint = await TenantContextService.withTenant(Uri(
        path: path, queryParameters: {
          'branch_id': '${widget.branchId}', 'page': '$page',
          'page_size': '20', 'in_stock': 'true',
          if (widget.kind == 'category' && widget.category != null)
            'category': widget.category!,
        },
      ).toString());
      final response = await ApiService.get(endpoint, requiresAuth: true);
      if (response.statusCode != 200) throw StateError('No se pudo consultar esta colección (${response.statusCode}).');
      final raw = jsonDecode(response.body);
      if (raw is! Map || raw['items'] is! List) throw const FormatException('Respuesta de productos inválida');
      final incoming = (raw['items'] as List).whereType<Map>().map((item) =>
          Product.fromJson(Map<String, dynamic>.from(item))).toList();
      if (!mounted) return;
      setState(() {
        _items = reset ? incoming : [..._items, ...incoming];
        _page = page;
        _totalPages = (raw['total_pages'] as num?)?.toInt() ?? 1;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() { _loading = false; _more = false; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8F8F8),
    appBar: AppBar(backgroundColor: Colors.white, foregroundColor: Colors.black,
      elevation: 0, title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800))),
    body: RefreshIndicator(onRefresh: () => _load(reset: true), child: ListView(
      padding: const EdgeInsets.all(14), children: [
        if (_loading && _items.isEmpty) const Padding(padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator(color: Colors.black))),
        if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 15),
          child: Column(children: [Text(_error!, style: const TextStyle(color: Colors.black54)),
            TextButton(onPressed: () => _load(reset: true), child: const Text('Reintentar'))])),
        if (!_loading && _items.isEmpty && _error == null) const Padding(
          padding: EdgeInsets.all(32), child: Text('Todavía no hay productos disponibles.',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.black54))),
        GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          itemCount: _items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: .62),
          itemBuilder: (context, i) {
            final product = _items[i];
            return InkWell(onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ProductDetailScreen(productId: product.id))),
              child: Container(color: Colors.white, child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: product.coverImageUrl?.startsWith('http') == true
                    ? Image.network(product.coverImageUrl!, width: double.infinity, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const _Placeholder())
                    : const _Placeholder()),
                  Padding(padding: const EdgeInsets.all(9), child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black87)),
                      Text('Bs ${product.minPrice.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
                    ])),
                ])));
          }),
        if (!_loading && !_more && _page < _totalPages) Center(child: OutlinedButton(
          onPressed: () => _load(reset: false), child: const Text('Cargar más productos'))),
        if (_more) const Center(child: CircularProgressIndicator(color: Colors.black)),
        const SizedBox(height: 28),
      ],
    )),
  );
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();
  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFFECECEC), child: Center(child: Icon(Icons.checkroom_outlined,
      size: 42, color: Color(0xFF999999))));
}
