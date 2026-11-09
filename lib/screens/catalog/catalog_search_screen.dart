import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/product.dart';
import '../../repositories/catalog_search_repository.dart';
import 'product_detail_screen.dart';

/// Buscador editorial de moda. Consulta el mismo catálogo de la tienda y usa
/// SQLite al perder conexión, sin cambiar compras, variantes ni navegación.
class CatalogSearchScreen extends StatefulWidget {
  const CatalogSearchScreen({super.key, this.branchId, this.onOpenCart});

  final int? branchId;
  final VoidCallback? onOpenCart;

  @override
  State<CatalogSearchScreen> createState() => _CatalogSearchScreenState();
}

class _CatalogSearchScreenState extends State<CatalogSearchScreen> {
  static const _ink = Color(0xFF171717);
  static const _muted = Color(0xFF777777);
  static const _surface = Color(0xFFF5F5F5);
  static const _line = Color(0xFFE6E6E6);

  final _repository = CatalogSearchRepository();
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  int _serial = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _fromCache = false;
  bool _offersOnly = false;
  bool _availableOnly = false;
  String _sort = 'relevance';
  int _page = 1;
  int _total = 0;
  int _totalPages = 1;
  String? _error;
  List<Product> _results = [];
  final List<String> _recent = [];

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _serial++;
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), _search);
  }

  void _submit(String value) {
    _debounce?.cancel();
    final text = value.trim();
    if (text.isNotEmpty) {
      _recent.removeWhere((v) => v.toLowerCase() == text.toLowerCase());
      _recent.insert(0, text);
      if (_recent.length > 5) _recent.removeLast();
    }
    _focusNode.unfocus();
    _search();
  }

  void _useSuggestion(String text) {
    _controller.text = text;
    _controller.selection = TextSelection.collapsed(offset: text.length);
    _submit(text);
  }

  Future<void> _search() async {
    final serial = ++_serial;
    final query = _controller.text.trim();
    setState(() {
      _loading = true;
      _loadingMore = false;
      _error = null;
    });
    try {
      final result = await _repository.search(
        query,
        branchId: widget.branchId,
        onlyPromotions: query.isNotEmpty && _offersOnly,
        inStock: query.isNotEmpty && _availableOnly,
        sortBy: _sort == 'price_low' || _sort == 'price_high' ? 'price' : 'name',
        sortOrder: _sort == 'price_high' ? 'desc' : 'asc',
      );
      if (!mounted || serial != _serial) return;
      setState(() {
        _results = result.products;
        _fromCache = result.fromCache;
        _page = 1;
        _total = result.total;
        _totalPages = result.totalPages;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || serial != _serial) return;
      setState(() {
        _results = [];
        _loading = false;
        _error = 'No fue posible consultar productos. Conéctate o descarga el catálogo para buscar sin Internet.';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || _page >= _totalPages) return;
    final serial = _serial;
    setState(() => _loadingMore = true);
    try {
      final result = await _repository.search(
        _controller.text.trim(),
        branchId: widget.branchId,
        page: _page + 1,
        onlyPromotions: _offersOnly,
        inStock: _availableOnly,
        sortBy: _sort == 'price_low' || _sort == 'price_high' ? 'price' : 'name',
        sortOrder: _sort == 'price_high' ? 'desc' : 'asc',
      );
      if (!mounted || serial != _serial) return;
      setState(() {
        final ids = _results.map((p) => p.id).toSet();
        _results = [..._results, ...result.products.where((p) => ids.add(p.id))];
        _page++;
        _totalPages = result.totalPages;
        _fromCache = result.fromCache;
      });
    } catch (_) {
      if (mounted && serial == _serial) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudieron cargar más productos.')),
        );
      }
    } finally {
      if (mounted && serial == _serial) setState(() => _loadingMore = false);
    }
  }

  void _choose(Product product) {
    _focusNode.unfocus();
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ProductDetailScreen(
        productId: product.id,
        onOpenCart: widget.onOpenCart == null ? null : () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
          widget.onOpenCart!.call();
        },
      ),
    ));
  }

  Widget _smallHeader(String title, {Widget? action}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 21, 20, 12),
      child: Row(children: [
        Expanded(child: Text(title, style: const TextStyle(
          color: _ink, fontWeight: FontWeight.w800, fontSize: 17,
        ))),
        if (action != null) action,
      ]),
    );
  }

  Widget _suggestion(Product product) {
    return InkWell(
      onTap: () => _choose(product),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(children: [
          Container(
            width: 52, height: 58,
            color: _surface,
            child: product.coverImageUrl != null && product.coverImageUrl!.isNotEmpty
              ? Image.network(product.coverImageUrl!, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.checkroom_outlined, color: _muted))
              : const Icon(Icons.checkroom_outlined, color: _muted),
          ),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _ink, fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 5),
            Text(product.category.name, maxLines: 1,
              style: const TextStyle(color: _muted, fontSize: 12)),
          ])),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_outward, color: _ink, size: 20),
        ]),
      ),
    );
  }

  Widget _productTile(Product product) {
    final image = product.coverImageUrl;
    return InkWell(
      onTap: () => _choose(product),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Stack(fit: StackFit.expand, children: [
          Container(color: _surface,
            child: image != null && image.isNotEmpty
              ? Image.network(image, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.checkroom_outlined, color: _muted, size: 48))
              : const Icon(Icons.checkroom_outlined, color: _muted, size: 48)),
          if (product.hasDiscount) Positioned(left: 0, top: 0,
            child: Container(color: _ink,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: const Text('OFERTA', style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)))),
          if (!product.hasStock) Positioned.fill(child: Container(
            color: Colors.white.withValues(alpha: .62),
            alignment: Alignment.center,
            child: const Text('AGOTADO', style: TextStyle(
              color: _ink, fontWeight: FontWeight.w800, letterSpacing: 1)))),
        ])),
        const SizedBox(height: 7),
        Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('Bs ${product.minPrice.toStringAsFixed(2)}',
            style: const TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w800)),
          if (product.hasDiscount && product.originalMinPrice > product.minPrice)
            Text('Bs ${product.originalMinPrice.toStringAsFixed(2)}',
              style: const TextStyle(color: _muted, fontSize: 11,
                decoration: TextDecoration.lineThrough)),
        ]),
        const SizedBox(height: 12),
      ]),
    );
  }

  Widget _emptyQuery() {
    return ListView(children: [
      if (_recent.isNotEmpty) ...[
        _smallHeader('Búsquedas recientes', action: TextButton(
          onPressed: () => setState(_recent.clear),
          child: const Text('Borrar', style: TextStyle(color: _muted)),
        )),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(spacing: 8, runSpacing: 8,
            children: _recent.map((term) => ActionChip(
              label: Text(term), onPressed: () => _useSuggestion(term),
              backgroundColor: _surface, side: BorderSide.none,
              shape: const RoundedRectangleBorder(),
            )).toList(),
          )),
      ],
      _smallHeader('Descubre nuevas prendas'),
      if (_loading) const Padding(padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator(color: _ink)))
      else if (_error != null) _message(_error!)
      else if (_results.isEmpty) _message('No hay productos disponibles para sugerir.')
      else ..._results.take(8).map(_suggestion),
      const SizedBox(height: 16),
    ]);
  }

  Widget _message(String text) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.search_off_outlined, size: 38, color: _muted),
      const SizedBox(height: 12),
      Text(text, textAlign: TextAlign.center,
        style: const TextStyle(color: _muted, height: 1.5)),
    ]),
  );

  Widget _resultsBody(String query) {
    return Column(children: [
      if (_fromCache) Container(
        color: _surface, width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: const Row(children: [
          Icon(Icons.cloud_off_outlined, size: 18, color: _muted),
          SizedBox(width: 8),
          Expanded(child: Text('Datos guardados. Precios y stock pueden haber cambiado.',
            style: TextStyle(color: _muted, fontSize: 12))),
        ]),
      ),
      _smallHeader('Resultados para “$query”'),
      Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Row(children: [
          Expanded(child: Text(_loading ? 'Buscando...' : '$_total productos',
            style: const TextStyle(color: _muted, fontSize: 12))),
          DropdownButtonHideUnderline(child: DropdownButton<String>(
            value: _sort, isDense: true,
            style: const TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.w600),
            icon: const Icon(Icons.keyboard_arrow_down, color: _ink),
            items: const [
              DropdownMenuItem(value: 'relevance', child: Text('Nombre')),
              DropdownMenuItem(value: 'price_low', child: Text('Menor precio')),
              DropdownMenuItem(value: 'price_high', child: Text('Mayor precio')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _sort = value);
              _search();
            },
          )),
        ]),
      ),
      SizedBox(height: 40, child: ListView(scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20), children: [
          _filterChip('Con descuento', _offersOnly, () {
            setState(() => _offersOnly = !_offersOnly); _search();
          }),
          const SizedBox(width: 9),
          _filterChip('Disponible', _availableOnly, () {
            setState(() => _availableOnly = !_availableOnly); _search();
          }),
        ])),
      const SizedBox(height: 12),
      Expanded(child: _loading
        ? const Center(child: CircularProgressIndicator(color: _ink))
        : _error != null ? Center(child: _message(_error!))
        : _results.isEmpty ? Center(child: _message('No encontramos productos. Prueba otro término o quita los filtros.'))
        : GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: _results.length + (_page < _totalPages ? 1 : 0),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 8,
            childAspectRatio: .57,
          ),
          itemBuilder: (context, index) {
            if (index == _results.length) {
              return Center(child: TextButton(
                onPressed: _loadingMore ? null : _loadMore,
                child: _loadingMore
                  ? const CircularProgressIndicator(color: _ink)
                  : const Text('Cargar más', style: TextStyle(color: _ink)),
              ));
            }
            return _productTile(_results[index]);
          },
        )),
    ]);
  }

  Widget _filterChip(String label, bool selected, VoidCallback action) {
    return ChoiceChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) => action(),
      labelStyle: TextStyle(color: selected ? Colors.white : _ink,
        fontSize: 12, fontWeight: FontWeight.w600),
      selectedColor: _ink, backgroundColor: Colors.white,
      side: const BorderSide(color: _line),
      shape: const RoundedRectangleBorder(),
      showCheckmark: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: _ink,
          surfaceTintColor: Colors.white,
          elevation: 0,
          toolbarHeight: 76,
          titleSpacing: 0,
          title: Container(
            height: 46,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: _surface,
              border: Border.all(color: _line),
            ),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              onChanged: _onChanged,
              onSubmitted: _submit,
              textInputAction: TextInputAction.search,
              cursorColor: _ink,
              style: const TextStyle(color: _ink, fontSize: 14),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: InputBorder.none,
                prefixIcon: const Icon(Icons.search, color: _ink, size: 22),
                hintText: 'Buscar ropa, marcas y categorías',
                hintStyle: const TextStyle(color: _muted, fontSize: 13),
                suffixIcon: query.isEmpty ? null : IconButton(
                  icon: const Icon(Icons.close, color: _ink, size: 20),
                  onPressed: () { _controller.clear(); _onChanged(''); _focusNode.requestFocus(); },
                ),
              ),
            ),
          ),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, thickness: 1, color: _line),
          ),
        ),
        body: query.isEmpty ? _emptyQuery() : _resultsBody(query),
      ),
    );
  }
}
