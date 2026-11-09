import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../../core/network/connectivity_service.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/app_error_message.dart';
import '../../models/branch.dart';
import '../../models/home_models.dart';
import '../../models/product.dart';
import '../../services/branch_service.dart';
import '../../services/home_service.dart';
import '../../services/tenant_context_service.dart';
import '../../services/selected_branch_service.dart';
import '../../widgets/catalog/branch_selector_sheet.dart';
import '../../widgets/home_storefront.dart';
import '../catalog/catalog_search_screen.dart';
import '../catalog/product_detail_screen.dart';
import 'home_section_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.onOpenCatalog,
  });

  final VoidCallback? onOpenCatalog;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  bool _promotionDialogOpen = false;
  String? _error;
  HomeData? _data;
  bool _fromCache = false;

  @override
  void initState() {
    super.initState();
    ConnectivityService.instance.status.addListener(_onConnectivityChanged);
    _onConnectivityChanged();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _bootstrap();
    });
  }


  ConnectionStatus? _lastConnection;

  void _onConnectivityChanged() {
    if (!mounted) return;
    final current = ConnectivityService.instance.status.value;
    if (current == _lastConnection) return;
    _lastConnection = current;
    if (current == ConnectionStatus.offline ||
        current == ConnectionStatus.networkOnly) {
      // Actualizar de inmediato la interfaz, sin esperar a fallar un GET.
      if (_data != null) setState(() => _fromCache = true);
      debugPrint('[FS-HOME] Servidor no disponible: mostrando copia local');
      return;
    }
    if (current == ConnectionStatus.apiAvailable && !_loading) {
      debugPrint('[FS-HOME] Servidor disponible: actualizando novedades');
      _load();
    }
  }

  @override
  void dispose() {
    ConnectivityService.instance.status.removeListener(_onConnectivityChanged);
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await SelectedBranchService.initialize();

    if (!mounted) return;

    try {
      final available = await BranchService.getStoreBranches();
      final selected = SelectedBranchService.selectedBranch;
      if (selected != null && !available.any((b) => b.id == selected.id)) {
        await SelectedBranchService.clearBranch();
        await SelectedBranchService.initialize();
      }
    } catch (error) {
      // Cuando la sucursal ya está guardada no bloquear Inicio por falta de red.
      if (SelectedBranchService.selectedBranch == null) {
        if (mounted) {
          setState(() {
            _error = AppErrorMessage.from(error);
            _loading = false;
          });
        }
        return;
      }
    }
    if (SelectedBranchService.selectedBranch == null) {
      await _openBranchSelector(requiredSelection: true);
    }

    if (!mounted) return;
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await SelectedBranchService.initialize();

      final branch = SelectedBranchService.selectedBranch;

      final result = await HomeService.loadHomeWithSource(
        branchId: branch?.id,
      );
      final data = result.data;

      if (!mounted) return;

      setState(() {
        _data = data;
        _fromCache = result.fromCache;
      });
      if (!result.fromCache) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _maybeShowCampaignPopup(data);
        });
      }


    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = AppErrorMessage.from(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _openBranchSelector({
    bool requiredSelection = false,
  }) async {
    List<StoreBranch> branches;

    try {
      branches = await BranchService.getStoreBranches();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppErrorMessage.from(error),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!mounted) return;

    if (branches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay sucursales disponibles en este momento.'),
        ),
      );
      return;
    }

    final selected = await showModalBottomSheet<StoreBranch>(
      context: context,
      isScrollControlled: true,
      isDismissible: !requiredSelection,
      enableDrag: !requiredSelection,
      backgroundColor: AppColors.surface,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.82,
        child: BranchSelectorSheet(
          branches: branches,
          selectedBranchId: SelectedBranchService.selectedBranch?.id,
        ),
      ),
    );

    if (selected == null) return;

    await SelectedBranchService.selectBranch(selected);

    if (!mounted) return;

    if (_data != null) {
      await _load();
    } else {
      setState(() {});
    }
  }

  /// Mostrar una sola campaña por día y por sucursal, usando únicamente
  /// la respuesta ONLINE del Home. Los banners marcados como popup tienen
  /// preferencia; si no hay banners, usar promociones vigentes del catálogo.
  Future<void> _maybeShowCampaignPopup(HomeData data) async {
    if (!mounted || _promotionDialogOpen || _fromCache) return;

    final branchId = SelectedBranchService.selectedBranch?.id;
    final tenantId = await TenantContextService.tenantId;
    if (!mounted || branchId == null || tenantId == null) return;

    final banners = data.banners.where((banner) =>
      banner.showAsPopup && banner.id > 0).toList()
      ..sort((a, b) {
        final priority = b.popupPriority.compareTo(a.popupPriority);
        return priority != 0 ? priority : a.id.compareTo(b.id);
      });

    // /store/home devuelve las promociones vigentes. No hace falta crear
    // otro banner ni inventar el porcentaje de descuento.
    final promotions = data.promotions.where((promotion) =>
      promotion.id > 0 && promotion.name.trim().isNotEmpty).toList();

    if (banners.isEmpty && promotions.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || _promotionDialogOpen || _fromCache) return;
    final now = DateTime.now();
    final today = '${now.year}-${now.month}-${now.day}';
    final prefix = 'home_popup_${tenantId}_$branchId';

    // No interrumpir al cliente cada vez que vuelve a Inicio.
    if (prefs.getString('${prefix}_last_day') == today) return;
    final banner = banners.isNotEmpty ? banners.first : null;
    final promotion = banner == null && promotions.isNotEmpty
        ? promotions.first : null;
    if (banner == null && promotion == null) return;

    _promotionDialogOpen = true;
    // Guardar antes de abrir evita diálogos simultáneos si se recarga el Home.
    await prefs.setString('${prefix}_last_day', today);
    if (!mounted) { _promotionDialogOpen = false; return; }
    try {
      final open = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (_) => _CampaignPopupDialog(
          banner: banner, promotion: promotion),
      );
      if (!mounted || open != true) return;
      if (banner != null) {
        _openBanner(banner);
      } else if (promotion != null) {
        _openSection('promotion', promotion.name, resourceId: promotion.id);
      }
    } finally {
      _promotionDialogOpen = false;
    }
  }

  void _openSearch() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CatalogSearchScreen(branchId: SelectedBranchService.selectedBranch?.id),
    ));
  }

  void _openProduct(int id) {
    if (id <= 0) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProductDetailScreen(productId: id),
    ));
  }

  void _openSection(String kind, String title, {String? category, int? resourceId}) {
    final branch = SelectedBranchService.selectedBranch;
    if (branch == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => HomeSectionScreen(title: title, branchId: branch.id,
        kind: kind, category: category, resourceId: resourceId),
    ));
  }

  void _openBanner(HomeBanner banner) {
    switch (banner.targetType) {
      case 'product':
        _openProduct(banner.targetId ?? 0);
        return;
      case 'category':
        final category = _data?.categories.where((c) => c.id == banner.targetId).toList();
        if (category != null && category.isNotEmpty) {
          _openSection('category', category.first.name, category: category.first.name);
        } else { widget.onOpenCatalog?.call(); }
        return;
      case 'collection':
        if (banner.targetId != null) {
          _openSection('collection', banner.title, resourceId: banner.targetId);
        }
        return;
      case 'promotion':
        if (banner.targetId != null) {
          _openSection('promotion', banner.title, resourceId: banner.targetId);
        }
        return;
      default:
        widget.onOpenCatalog?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return ColoredBox(color: const Color(0xFFF9F9F9), child: SafeArea(
      child: RefreshIndicator(color: Colors.black, onRefresh: _load, child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('FASHIONSTORE', style: TextStyle(color: Color(0xFF111111),
                fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              const SizedBox(height: 14),
              InkWell(onTap: _openSearch, child: Container(
                height: 48, padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: Colors.white,
                  border: Border.all(color: const Color(0xFFE2E2E2))),
                child: const Row(children: [Icon(Icons.search, color: Color(0xFF333333)),
                  SizedBox(width: 10), Text('Buscar ropa, marcas y estilos...',
                  style: TextStyle(color: Color(0xFF777777), fontSize: 13))]))),
              const SizedBox(height: 4),
              ValueListenableBuilder<StoreBranch?>(
                valueListenable: SelectedBranchService.selectedBranchNotifier,
                builder: (context, branch, _) => TextButton.icon(
                  onPressed: () => _openBranchSelector(),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF333333),
                    padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
                  icon: const Icon(Icons.location_on_outlined, size: 17),
                  label: Text(branch?.name ?? 'Seleccionar sucursal',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ])),
          if (_fromCache && data != null) Container(
            color: const Color(0xFFF0F0F0), padding: const EdgeInsets.all(12),
            child: const Text('Mostrando información guardada. Los precios y existencias pueden haber cambiado.',
              style: TextStyle(color: Color(0xFF666666), fontSize: 12))),
          if (_loading && data == null) const Padding(
            padding: EdgeInsets.all(48), child: Center(
              child: CircularProgressIndicator(color: Colors.black))),
          if (_error != null && data == null) Padding(
            padding: const EdgeInsets.all(16), child: Column(children: [
              Text(_error!, style: const TextStyle(color: Colors.black87)),
              OutlinedButton(onPressed: _bootstrap, child: const Text('Reintentar')),
            ])),
          if (data != null) HomeStorefront(
            data: data, onBanner: _openBanner, onProduct: _openProduct,
            onCategory: (category) => _openSection('category', category.name, category: category.name),
            onCollection: (collection) => _openSection('collection', collection.name, resourceId: collection.id),
            onPromotion: (promotion) => _openSection('promotion', promotion.name, resourceId: promotion.id),
            onCatalog: () => widget.onOpenCatalog?.call(),
          ),
          if (_error != null && data != null) Padding(
            padding: const EdgeInsets.all(16), child: Text(_error!,
              style: const TextStyle(color: Color(0xFF666666)))),
        ],
      )),
    ));
  }

}

class _BranchStatusCard extends StatelessWidget {
  const _BranchStatusCard({
    required this.branch,
    required this.onChange,
  });

  final StoreBranch? branch;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final current = branch;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onChange,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: AppColors.primaryLight,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: current == null
                    ? const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selecciona una sucursal',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Consulta stock y disponibilidad exacta.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            current.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            [
                              current.city.name,
                              current.address,
                            ]
                                .where((item) => item.trim().isNotEmpty)
                                .join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: 8),
              Text(
                current == null ? 'Elegir' : 'Cambiar',
                style: const TextStyle(
                  color: AppColors.primaryLight,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.primaryLight,
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CampaignPopupDialog extends StatelessWidget {
  const _CampaignPopupDialog({this.banner, this.promotion});
  final HomeBanner? banner;
  final HomePromotion? promotion;

  @override
  Widget build(BuildContext context) {
    final image = banner?.displayImage.trim() ?? '';
    final title = banner?.title ?? promotion?.name ?? 'Moda para ti';
    final subtitle = banner?.subtitle ?? promotion?.description;
    final discount = promotion?.discountLabel;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
      shape: const RoundedRectangleBorder(),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(children: [
            AspectRatio(
              aspectRatio: 1.35,
              child: image.isNotEmpty
                ? Image.network(image, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _PromoArtwork(
                      title: title, discount: discount))
                : _PromoArtwork(title: title, discount: discount),
            ),
            Positioned(right: 8, top: 8, child: IconButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: IconButton.styleFrom(backgroundColor: Colors.white),
              icon: const Icon(Icons.close, color: Colors.black),
              tooltip: 'Cerrar anuncio',
            )),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('FASHIONSTORE  /  PROMOCIÓN ESPECIAL',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, letterSpacing: 1.1,
                  color: Color(0xFF777777), fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text(title, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900,
                  color: Color(0xFF111111))),
              if (discount != null) ...[
                const SizedBox(height: 6),
                Text(discount, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900,
                    color: Color(0xFF111111))),
              ],
              if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(subtitle, textAlign: TextAlign.center, maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF666666), fontSize: 12)),
              ],
              const SizedBox(height: 8),
              const Text('Descubre las prendas participantes de esta campaña.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF777777), fontSize: 12)),
              const SizedBox(height: 19),
              SizedBox(width: double.infinity, child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF111111),
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 15)),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('EXPLORAR OFERTAS',
                  style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.7)),
              )),
              TextButton(onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Ahora no',
                  style: TextStyle(color: Color(0xFF555555)))),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _PromoArtwork extends StatelessWidget {
  const _PromoArtwork({required this.title, this.discount});
  final String title;
  final String? discount;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF161616),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('FASHIONSTORE   •   SPECIAL OFFER',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFCCCCCC), fontSize: 10,
              letterSpacing: 1.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 18),
          Text(title.toUpperCase(), textAlign: TextAlign.center, maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 29,
              fontWeight: FontWeight.w900, letterSpacing: 1.0)),
          if (discount != null) ...[
            const SizedBox(height: 18),
            Container(color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Text(discount!,
                style: const TextStyle(color: Colors.black, fontSize: 25,
                  fontWeight: FontWeight.w900))),
          ],
        ]),
      ),
    );
  }
}
