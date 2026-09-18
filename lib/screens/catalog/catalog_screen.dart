import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/errors/api_exception.dart';
import '../../models/branch.dart';
import '../../models/product.dart';
import '../../services/catalog service.dart';
import '../../widgets/product_card.dart';
import 'product_detail_screen.dart';
import 'widgets/catalog_filters_sheet.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  StoreCatalogFilters _filters = const StoreCatalogFilters();
  List<StoreBranch> _branches = [];

  final List<StoreCatalogProduct> _items = [];
  int _page = 1;
  int _totalPages = 1;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBranches();
    _loadCatalog(reset: true);

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >
          _scrollController.position.maxScrollExtent - 200 &&
          !_isLoadingMore &&
          _page < _totalPages) {
        _loadCatalog();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    try {
      final branches = await StoreCatalogService.getBranches();
      if (mounted) setState(() => _branches = branches);
    } catch (_) {
      // El selector de sucursal es un complemento; si falla, el
      // catálogo sigue funcionando sin ese filtro.
    }
  }

  Future<void> _loadCatalog({bool reset = false}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _error = null;
        _page = 1;
        _items.clear();
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final nextPage = reset ? 1 : _page + 1;

      final result = await StoreCatalogService.getCatalog(
        filters: _filters,
        page: nextPage,
      );

      setState(() {
        _items.addAll(result.items);
        _page = result.page;
        _totalPages = result.totalPages;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.message : 'No se pudo cargar el catálogo.';
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _filters = _filters.copyWith(search: value.trim());
      _loadCatalog(reset: true);
    });
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<StoreCatalogFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CatalogFiltersSheet(
        initialFilters: _filters,
        branches: _branches,
      ),
    );

    if (result != null) {
      setState(() {
        _filters = result.copyWith(search: _filters.search);
      });
      _loadCatalog(reset: true);
    }
  }

  void _openDetail(StoreCatalogProduct product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          productId: product.id,
          branchId: _filters.branchId,
        ),
      ),
    );
  }

  int get _activeFilterCount {
    var count = 0;
    if (_filters.audience != null) count++;
    if (_filters.category != null) count++;
    if (_filters.minPrice != null) count++;
    if (_filters.maxPrice != null) count++;
    if (_filters.promotion == true) count++;
    if (_filters.inStock == true) count++;
    if (_filters.branchId != null) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Catálogo'),
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadCatalog(reset: true),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Buscar prendas',
                        hintStyle: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: AppColors.textSecondary,
                        ),
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: AppColors.divider),
                        ),
                      ),
                      onChanged: _onSearchChanged,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.tune,
                            color: AppColors.textPrimary,
                          ),
                          onPressed: _openFilters,
                        ),
                      ),
                      if (_activeFilterCount > 0)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$_activeFilterCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
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

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _loadCatalog(reset: true),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return const Center(
        child: Text(
          'No se encontraron prendas con esos filtros.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.68,
      ),
      itemCount: _items.length + (_isLoadingMore ? 2 : 0),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final product = _items[index];
        return ProductCard(
          product: product,
          onTap: () => _openDetail(product),
        );
      },
    );
  }
}