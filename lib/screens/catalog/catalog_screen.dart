import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/catalog/catalog_fashion_style.dart';
import '../../core/network/app_error_message.dart';
import '../../models/catalog_models.dart';
import '../../models/product.dart';
import '../../services/catalog_service.dart';
import '../../core/network/connectivity_service.dart';
import '../../providers/connectivity_provider.dart';
import '../../repositories/cached_catalog_repository.dart';
import '../../repositories/offline_catalog_download_service.dart';
import '../../widgets/catalog/catalog_filter_drawer.dart';
import '../../widgets/catalog/catalog_product_card.dart';
import 'product_detail_screen.dart';
import 'catalog_search_screen.dart';

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({
    super.key,
    this.branchId,
    this.initialSearch,
    this.onOpenCart,
  });

  final int? branchId;
  final String? initialSearch;
  final VoidCallback? onOpenCart;

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  final _catalogRepository = CachedCatalogRepository();
  bool _fromCache = false;
  bool _downloadingOffline = false;
  bool _cancelOfflineDownload = false;
  OfflineCatalogDownloadProgress? _offlineProgress;
  OfflineCatalogDownloadProgress? _completedDownload;
  bool _checkingDownload = true;
  final _offlineDownloader = OfflineCatalogDownloadService();
  int _requestSerial = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  Timer? _searchDebounce;

  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  int _page = 1;
  int _total = 0;
  int _totalPages = 0;

  List<Product> _products = const [];
  CatalogFilterMetadata? _metadata;
  CatalogFilterState _filters = const CatalogFilterState();

  @override
  void initState() {
    super.initState();

    final initialSearch =
        widget.initialSearch?.trim();

    if (initialSearch != null &&
        initialSearch.isNotEmpty) {
      _searchController.text =
          initialSearch;
    }

    _scrollController.addListener(_onCatalogScroll);
    _loadInitial();
    _refreshDownloadStatus();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _cancelOfflineDownload = true;
    _searchController.dispose();
    _scrollController.removeListener(_onCatalogScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // Paginación incremental: cargar la página siguiente antes de llegar al final.
  // El guard evita peticiones duplicadas durante una carga o tras un error.
  void _onCatalogScroll() {
    if (!_scrollController.hasClients ||
        _loading ||
        _loadingMore ||
        _error != null ||
        _products.isEmpty ||
        _page >= _totalPages) {
      return;
    }

    if (_scrollController.position.extentAfter < 600) {
      _loadCatalog(reset: false);
    }
  }

  Future<void> _loadInitial() async {
    await Future.wait([
      _loadCatalog(reset: true),
      _loadMetadata(),
    ]);
  }

  Future<void> _loadMetadata() async {
    try {
      final metadata = await CatalogService.loadFilterMetadata();

      if (!mounted) return;

      setState(() {
        _metadata = metadata;
      });
    } catch (_) {}
  }

  Future<void> _loadCatalog({
    required bool reset,
  }) async {
    if (reset) {
      setState(() {
        _loading = true;
        _loadingMore = false;
        _error = null;
        _page = 1;
      });
    } else {
      if (_loading || _loadingMore || _page >= _totalPages) return;

      setState(() {
        _loadingMore = true;
      });
    }

    final requestedPage = reset ? 1 : _page + 1;
    final serial = ++_requestSerial;

    try {
      final result = await _catalogRepository.load(
        page: requestedPage,
        pageSize: 20,
        branchId: widget.branchId,
        search: _searchController.text,
        filters: _filters,
      );

      if (!mounted || serial != _requestSerial) return;
      final response = result.page;

      setState(() {
        _fromCache = result.fromCache;
        _error = null;
        _products = reset
            ? response.items
            : [..._products, ...response.items];
        _page = response.page;
        _total = response.total;
        if (!result.fromCache && _completedDownload != null &&
            _completedDownload!.products != response.total) {
          _completedDownload = null;
        }
        _totalPages = response.totalPages;
      });
      // Si una pantalla alta deja poco contenido por debajo, continuar
      // cargando hasta tener contenido desplazable o agotar las páginas.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onCatalogScroll();
      });
    } catch (error) {
      if (!mounted || serial != _requestSerial) return;

      setState(() {
        debugPrint('[FS-CATALOGO-UI] Falló página $requestedPage: $error');
        _error = error.toString().contains('CATALOG_NOT_CACHED')
            ? 'Este catálogo todavía no está descargado en el teléfono. '
                'Conéctate al servidor y ábrelo una vez.'
            : AppErrorMessage.from(error);
        // Mantener la última lista visible si falla una actualización.
      });
    } finally {
      if (!mounted || serial != _requestSerial) return;

      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _refreshDownloadStatus() async {
    try {
      final completed = await _offlineDownloader.completedDownload(branchId: widget.branchId);
      if (mounted) setState(() {
        _completedDownload = completed;
        _checkingDownload = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _completedDownload = null;
        _checkingDownload = false;
      });
    }
  }

  Future<void> _openSearch() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => CatalogSearchScreen(
        branchId: widget.branchId,
        onOpenCart: widget.onOpenCart,
      ),
    ));
  }

  Future<void> _downloadForOffline() async {
    if (_downloadingOffline) return;
    setState(() {
      _downloadingOffline = true;
      _cancelOfflineDownload = false;
      _offlineProgress = null;
      _completedDownload = null;
    });
    final result = await _offlineDownloader.download(
      branchId: widget.branchId,
      onProgress: (progress) {
        if (mounted) setState(() => _offlineProgress = progress);
      },
      isCancelled: () => _cancelOfflineDownload || !mounted,
    );
    if (!mounted) return;
    setState(() {
      _downloadingOffline = false;
      _offlineProgress = result.progress;
    });
    await _refreshDownloadStatus();
    if (!mounted) return;
    final p = result.progress;
    final message = result.cancelled
        ? 'Descarga detenida. Lo descargado se conserva.'
        : result.completed
            ? 'Catálogo preparado: ${p.products} productos y ${p.details} detalles.'
            : 'Descarga incompleta: ${p.products} productos, '
                '${p.details} detalles y ${p.failedDetails} detalles fallidos.'
                '${result.error == null ? '' : ' ${result.error}'}';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 6),
    ));
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();

    _searchDebounce = Timer(
      const Duration(milliseconds: 450),
      () => _loadCatalog(reset: true),
    );
  }

  void _applyFilters(CatalogFilterState filters) {
    setState(() {
      _filters = filters;
    });

    _loadCatalog(reset: true);
  }

  void _clearFilters() {
    setState(() {
      _filters = _filters.clearAll();
    });

    _loadCatalog(reset: true);
  }

  void _clearSearch() {
    _searchController.clear();
    _loadCatalog(reset: true);
  }

  void _removeFilter(String key) {
    setState(() {
      switch (key) {
        case 'category':
          _filters = _filters.copyWith(clearCategory: true);
          break;
        case 'audience':
          _filters = _filters.copyWith(clearAudience: true);
          break;
        case 'price':
          _filters = _filters.copyWith(
            clearMinPrice: true,
            clearMaxPrice: true,
          );
          break;
        case 'stock':
          _filters = _filters.copyWith(inStock: false);
          break;
        case 'promotion':
          _filters = _filters.copyWith(
            onlyPromotions: false,
            clearPromotionId: true,
          );
          break;
        case 'collection':
          _filters = _filters.copyWith(clearCollectionId: true);
          break;
        case 'season':
          _filters = _filters.copyWith(clearSeasonId: true);
          break;
      }
    });

    _loadCatalog(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<ConnectionStatus>>(
      connectionStatusProvider, (previous, next) {
        final wasAvailable = previous?.valueOrNull == ConnectionStatus.apiAvailable;
        final isAvailable = next.valueOrNull == ConnectionStatus.apiAvailable;
        if (!mounted) return;
        if (!isAvailable && wasAvailable) {
          if (_products.isNotEmpty) setState(() => _fromCache = true);
          debugPrint('[FS-CATALOGO-UI] Conexión perdida: manteniendo productos');
        } else if (isAvailable && !wasAvailable && !_loading) {
          debugPrint('[FS-CATALOGO-UI] Conexión recuperada: actualizando');
          _loadCatalog(reset: true);
          _refreshDownloadStatus();
        }
      },
    );
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: CatalogFashionColors.background,
      drawer: CatalogFilterDrawer(
        initialFilters: _filters,
        metadata: _metadata,
        onApply: _applyFilters,
        onClear: _clearFilters,
      ),
      appBar: AppBar(
        backgroundColor: CatalogFashionColors.background,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 10,
        foregroundColor: CatalogFashionColors.textPrimary,
        toolbarHeight: 64,
        leading: IconButton(
          tooltip: 'Filtros',
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
          icon: Badge(
            isLabelVisible: _filters.activeCount > 0,
            label: Text('${_filters.activeCount}'),
            child: const Icon(Icons.menu_rounded),
          ),
        ),
        title: InkWell(
          onTap: _openSearch,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: CatalogFashionColors.surface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: CatalogFashionColors.divider),
            ),
            child: const Row(children: [
              Icon(Icons.search_rounded, color: CatalogFashionColors.textSecondary),
              SizedBox(width: 10),
              Expanded(child: Text('Buscar prendas, marcas...',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: CatalogFashionColors.textSecondary, fontSize: 14))),
            ]),
          ),
        ),
        actions: [
          if (ref.watch(connectionStatusProvider).valueOrNull ==
              ConnectionStatus.apiAvailable)
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 10),
              child: _checkingDownload
                  ? const SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(child: SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )),
                    )
                  : IconButton(
                      tooltip: _downloadingOffline
                          ? 'Detener descarga del catálogo'
                          : _completedDownload != null
                              ? 'Catálogo descargado: ${_completedDownload!.products} productos'
                              : 'Descargar catálogo para usar sin Internet',
                      onPressed: () {
                        if (_downloadingOffline) {
                          setState(() => _cancelOfflineDownload = true);
                        } else if (_completedDownload != null) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Catálogo descargado: '
                                '${_completedDownload!.products} productos y '
                                '${_completedDownload!.details} detalles. '
                                'Precios y existencias son los últimos conocidos.'),
                          ));
                        } else {
                          _downloadForOffline();
                        }
                      },
                      icon: Icon(
                        _downloadingOffline
                            ? Icons.stop_circle_outlined
                            : _completedDownload != null
                                ? Icons.verified_rounded
                                : Icons.download_for_offline_outlined,
                        color: _completedDownload != null
                            ? CatalogFashionColors.success
                            : CatalogFashionColors.textPrimary,
                        size: 27,
                      ),
                    ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadCatalog(reset: true),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (_downloadingOffline)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_offlineProgress == null
                          ? 'Preparando descarga del catálogo completo…'
                          : 'Descargando: ${_offlineProgress!.products} productos '
                              '(${_offlineProgress!.pages}/${_offlineProgress!.totalPages} páginas) · '
                              '${_offlineProgress!.details} detalles listos · '
                              '${_offlineProgress!.failedDetails} pendientes',
                          style: const TextStyle(fontSize: 12,
                              color: CatalogFashionColors.textSecondary)),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _offlineProgress == null ||
                                _offlineProgress!.totalPages <= 0
                            ? null
                            : (_offlineProgress!.pages /
                                    _offlineProgress!.totalPages).clamp(0.0, 1.0),
                      ),
                    ],
                  ),
                ),
              ),
            if (_fromCache)
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  color: CatalogFashionColors.surface,
                  child: const Row(
                    children: [
                      Icon(Icons.cloud_off_rounded, size: 18,
                          color: CatalogFashionColors.textSecondary),
                      SizedBox(width: 10),
                      Expanded(child: Text(
                        'Mostrando datos guardados. Precios y stock pueden haber cambiado.',
                        style: TextStyle(color: CatalogFashionColors.textSecondary,
                            fontSize: 12),
                      )),
                    ],
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: _CatalogHeader(
                total: _total,
                loading: _loading,
                filters: _filters,
                metadata: _metadata,
              ),
            ),
            if (_hasAnyContext)
              SliverToBoxAdapter(
                child: _ActiveFilters(
                  search: _searchController.text,
                  filters: _filters,
                  metadata: _metadata,
                  onClearSearch: _clearSearch,
                  onRemove: _removeFilter,
                  onClearAll: () {
                    _searchController.clear();
                    setState(() {
                      _filters = _filters.clearAll();
                    });
                    _loadCatalog(reset: true);
                  },
                ),
              ),
            if (_error != null && _products.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(_error!, style: const TextStyle(
                    color: CatalogFashionColors.textSecondary, fontSize: 12)),
                ),
              ),
            if (_loading && _products.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null && _products.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _CatalogMessage(
                  icon: Icons.cloud_off_rounded,
                  title: 'No pudimos cargar el catálogo',
                  message: _error!,
                  buttonLabel: 'Reintentar',
                  onPressed: () => _loadCatalog(reset: true),
                ),
              )
            else if (_products.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _CatalogMessage(
                  icon: Icons.search_off_rounded,
                  title: 'No encontramos prendas',
                  message:
                      'Prueba quitando alguno de los filtros activos.',
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.64,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final product = _products[index];

                      return CatalogProductCard(
                        product: product,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProductDetailScreen(
                                productId: product.id,
                                onOpenCart: widget.onOpenCart == null ? null : () {
                                  Navigator.of(context).pop();
                                  widget.onOpenCart!.call();
                                },
                              ),
                            ),
                          );
                        },
                      );
                    },
                    childCount: _products.length,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _InfiniteScrollFooter(
                  hasNextPage: _page < _totalPages,
                  loading: _loadingMore,
                  error: _error,
                  onRetry: () => _loadCatalog(reset: false),
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 96),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool get _hasAnyContext =>
      _filters.hasFilters ||
      _searchController.text.trim().isNotEmpty;
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: const TextStyle(
        color: CatalogFashionColors.textPrimary,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        hintText: 'Buscar prendas...',
        hintStyle: const TextStyle(
          color: CatalogFashionColors.textSecondary,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: CatalogFashionColors.textSecondary,
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: CatalogFashionColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: CatalogFashionColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: CatalogFashionColors.primary),
        ),
      ),
    );
  }
}

class _CatalogHeader extends StatelessWidget {
  const _CatalogHeader({
    required this.total,
    required this.loading,
    required this.filters,
    required this.metadata,
  });

  final int total;
  final bool loading;
  final CatalogFilterState filters;
  final CatalogFilterMetadata? metadata;

  @override
  Widget build(BuildContext context) {
    final contextInfo = _CatalogContext(
      filters: filters,
      metadata: metadata,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contextInfo.eyebrow.toUpperCase(),
                  style: const TextStyle(
                    color: CatalogFashionColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  contextInfo.title,
                  style: const TextStyle(
                    color: CatalogFashionColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  contextInfo.description,
                  style: const TextStyle(
                    color: CatalogFashionColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (!loading)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 11,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: CatalogFashionColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: CatalogFashionColors.divider),
              ),
              child: Column(
                children: [
                  Text(
                    '$total',
                    style: const TextStyle(
                      color: CatalogFashionColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    total == 1 ? 'producto' : 'productos',
                    style: const TextStyle(
                      color: CatalogFashionColors.textMuted,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({
    required this.search,
    required this.filters,
    required this.metadata,
    required this.onClearSearch,
    required this.onRemove,
    required this.onClearAll,
  });

  final String search;
  final CatalogFilterState filters;
  final CatalogFilterMetadata? metadata;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onRemove;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    if (search.trim().isNotEmpty) {
      chips.add(
        _FilterChip(
          label: '“${search.trim()}”',
          onDeleted: onClearSearch,
        ),
      );
    }

    if (filters.category != null) {
      chips.add(
        _FilterChip(
          label: filters.category!,
          onDeleted: () => onRemove('category'),
        ),
      );
    }

    if (filters.audience != null) {
      chips.add(
        _FilterChip(
          label: filters.audience!,
          onDeleted: () => onRemove('audience'),
        ),
      );
    }

    if (filters.collectionId != null) {
      chips.add(
        _FilterChip(
          label:
              'Colección: ${_name(metadata?.collections, filters.collectionId!)}',
          onDeleted: () => onRemove('collection'),
        ),
      );
    }

    if (filters.seasonId != null) {
      chips.add(
        _FilterChip(
          label:
              'Temporada: ${_name(metadata?.seasons, filters.seasonId!)}',
          onDeleted: () => onRemove('season'),
        ),
      );
    }

    if (filters.promotionId != null || filters.onlyPromotions) {
      chips.add(
        _FilterChip(
          label: filters.promotionId == null
              ? 'Solo ofertas'
              : _name(metadata?.promotions, filters.promotionId!),
          onDeleted: () => onRemove('promotion'),
        ),
      );
    }

    if (filters.minPrice != null || filters.maxPrice != null) {
      final from = filters.minPrice == null
          ? ''
          : 'Desde Bs ${_number(filters.minPrice!)}';
      final to = filters.maxPrice == null
          ? ''
          : 'Hasta Bs ${_number(filters.maxPrice!)}';

      chips.add(
        _FilterChip(
          label: [from, to].where((text) => text.isNotEmpty).join(' · '),
          onDeleted: () => onRemove('price'),
        ),
      );
    }

    if (filters.inStock) {
      chips.add(
        _FilterChip(
          label: 'Con stock',
          onDeleted: () => onRemove('stock'),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: chips,
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: onClearAll,
            child: const Text('Limpiar todo'),
          ),
        ],
      ),
    );
  }

  String _name(
    List<CatalogMerchandisingOption>? items,
    int id,
  ) {
    if (items == null) return '#$id';

    for (final item in items) {
      if (item.id == id) {
        return item.name;
      }
    }

    return '#$id';
  }

  String _number(double value) {
    return value % 1 == 0
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.onDeleted,
  });

  final String label;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text(label),
      onDeleted: onDeleted,
      deleteIconColor: CatalogFashionColors.textSecondary,
      labelStyle: const TextStyle(
        color: CatalogFashionColors.textPrimary,
        fontSize: 12,
      ),
      backgroundColor: CatalogFashionColors.surface,
      side: const BorderSide(color: CatalogFashionColors.divider),
    );
  }
}

class _InfiniteScrollFooter extends StatelessWidget {
  const _InfiniteScrollFooter({
    required this.hasNextPage,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final bool hasNextPage;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (!hasNextPage) return const SizedBox(height: 20);

    if (error != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Center(
          child: TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar carga de productos'),
            style: TextButton.styleFrom(
              foregroundColor: CatalogFashionColors.textPrimary,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 23,
                height: 23,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: CatalogFashionColors.textPrimary,
                ),
              )
            : const SizedBox(height: 20),
      ),
    );
  }
}

class _CatalogMessage extends StatelessWidget {
  const _CatalogMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.buttonLabel,
    this.onPressed,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 54,
              color: CatalogFashionColors.textMuted,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: CatalogFashionColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: CatalogFashionColors.textSecondary,
                height: 1.35,
              ),
            ),
            if (onPressed != null && buttonLabel != null) ...[
              const SizedBox(height: 14),
              TextButton(
                onPressed: onPressed,
                child: Text(buttonLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CatalogContext {
  _CatalogContext({
    required this.filters,
    required this.metadata,
  });

  final CatalogFilterState filters;
  final CatalogFilterMetadata? metadata;

  String get eyebrow {
    if (filters.collectionId != null) return 'Colección';
    if (filters.seasonId != null) return 'Temporada';
    if (filters.promotionId != null || filters.onlyPromotions) {
      return 'Ofertas';
    }
    return 'FashionStore';
  }

  String get title {
    if (filters.collectionId != null) {
      return _name(metadata?.collections, filters.collectionId!) ??
          'Colección';
    }

    if (filters.seasonId != null) {
      return _name(metadata?.seasons, filters.seasonId!) ??
          'Temporada';
    }

    if (filters.promotionId != null) {
      return _name(metadata?.promotions, filters.promotionId!) ??
          'Promoción';
    }

    if (filters.onlyPromotions) return 'Ofertas';
    if (filters.category != null && filters.audience != null) {
      return '${filters.category} · ${filters.audience}';
    }
    if (filters.category != null) return filters.category!;
    if (filters.audience != null) return filters.audience!;

    return 'Catálogo';
  }

  String get description {
    if (filters.collectionId != null) {
      return 'Explora las prendas incluidas en esta colección.';
    }

    if (filters.seasonId != null) {
      return 'Descubre las prendas de esta temporada.';
    }

    if (filters.promotionId != null || filters.onlyPromotions) {
      return 'Productos con promociones vigentes en FashionStore.';
    }

    return 'Explora nuestras prendas disponibles y encuentra tu estilo.';
  }

  String? _name(
    List<CatalogMerchandisingOption>? items,
    int id,
  ) {
    if (items == null) return null;

    for (final item in items) {
      if (item.id == id) return item.name;
    }

    return null;
  }
}
