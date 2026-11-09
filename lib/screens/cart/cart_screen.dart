import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/cart/cart_fashion_style.dart';
import '../../core/network/app_error_message.dart';
import '../../core/network/connectivity_service.dart';
import '../../models/branch.dart';
import '../../models/cart_item.dart';
import '../../models/order.dart';
import '../../services/branch_service.dart';
import '../../services/cart_service.dart';
import '../../repositories/offline_cart_repository.dart';
import '../../repositories/account_snapshot_repository.dart';
import '../../services/offline_cart_transfer_service.dart';
import '../catalog/product_detail_screen.dart';
import '../../services/selected_branch_service.dart';
import '../../services/main_tab_navigation_service.dart';
import '../../widgets/cart/cart_item_card.dart';
import '../../widgets/cart/cart_summary_card.dart';
import '../../widgets/catalog/branch_selector_sheet.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({
    super.key,
    this.onOpenCatalog,
  });

  final VoidCallback? onOpenCatalog;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _loading = true;
  bool _loadingBranches = true;
  bool _clearing = false;
  bool _transferring = false;
  final ValueNotifier<int> _syncCompleted = ValueNotifier<int>(0);
  final ValueNotifier<String> _syncPhase = ValueNotifier<String>('Sincronizando tu carrito...');
  int _syncTotal = 0;
  BuildContext? _syncDialogContext;
  bool _syncDialogOpen = false;
  String? _transferMessage;
  bool _selfMutation = false;
  bool _reconnectionRefreshRunning = false;
  ConnectionStatus? _lastConnection;
  String? _connectionNotice;

  String? _error;

  List<StoreBranch> _branches = const [];
  StoreBranch? _selectedBranch;
  ShoppingCart? _cart;
  bool _cartFromSnapshot = false;
  List<OfflineCartEntry> _drafts = const [];

  final Set<int> _busyItems = <int>{};

  @override
  void initState() {
    super.initState();

    CartService.mutationVersionNotifier.addListener(
      _onExternalCartMutation,
    );
    OfflineCartRepository.mutationNotifier.addListener(_onLocalCartMutation);
    SelectedBranchService.selectedBranchNotifier.addListener(_onBranchChanged);
    MainTabNavigationService.selectedTab.addListener(_onTabSelected);

    _lastConnection = ConnectivityService.instance.status.value;
    ConnectivityService.instance.status.addListener(_onConnectivityChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    ConnectivityService.instance.status.removeListener(_onConnectivityChanged);
    CartService.mutationVersionNotifier.removeListener(
      _onExternalCartMutation,
    );
    OfflineCartRepository.mutationNotifier.removeListener(_onLocalCartMutation);
    SelectedBranchService.selectedBranchNotifier.removeListener(_onBranchChanged);
    MainTabNavigationService.selectedTab.removeListener(_onTabSelected);
    _syncCompleted.dispose();
    _syncPhase.dispose();
    super.dispose();
  }

  void _openSyncDialog() {
    if (_syncDialogOpen || !mounted ||
        MainTabNavigationService.selectedTab.value != 3) return;
    _syncDialogOpen = true;
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        _syncDialogContext = dialogContext;
        return PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: CartFashionStyle.paper,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
            title: const Row(children: [
              Icon(Icons.sync_rounded, color: CartFashionStyle.ink),
              SizedBox(width: 10),
              Expanded(child: Text('Sincronización del carrito',
                style: TextStyle(color: CartFashionStyle.ink, fontSize: 18))),
            ]),
            content: ValueListenableBuilder<int>(
              valueListenable: _syncCompleted,
              builder: (context, completed, _) => ValueListenableBuilder<String>(
                valueListenable: _syncPhase,
                builder: (context, phase, _) {
                  final total = _syncTotal;
                  final progress = total == 0 ? 0.0 : (completed / total).clamp(0.0, 1.0);
                  final percent = (progress * 100).round();
                  return Column(mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(phase, style: const TextStyle(color: CartFashionStyle.grey)),
                    const SizedBox(height: 18),
                    LinearProgressIndicator(value: progress, minHeight: 7,
                      borderRadius: BorderRadius.circular(10)),
                    const SizedBox(height: 12),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('$completed/$total prendas',
                        style: const TextStyle(color: CartFashionStyle.ink)),
                      Text('$percent%', style: const TextStyle(
                        color: CartFashionStyle.ink, fontWeight: FontWeight.bold)),
                    ]),
                  ]);
                },
              ),
            ),
          ),
        );
      },
    ).whenComplete(() {
      _syncDialogOpen = false;
      _syncDialogContext = null;
    }));
  }

  void _closeSyncDialog() {
    final dialogContext = _syncDialogContext;
    if (dialogContext != null && dialogContext.mounted) {
      Navigator.of(dialogContext).pop();
    }
  }

  void _onTabSelected() {
    if (!mounted || MainTabNavigationService.selectedTab.value != 3 || _transferring) return;
    final branch = _selectedBranch;
    if (branch == null) return;
    if (ConnectivityService.instance.canReachApi) {
      if (_drafts.isNotEmpty) {
        unawaited(_transferDrafts(branch.id));
      } else {
        unawaited(_loadCart(branch.id, showLoading: false));
      }
    }
  }

  void _onConnectivityChanged() {
    if (!mounted) return;
    final next = ConnectivityService.instance.status.value;
    if (next == _lastConnection) return;
    final before = _lastConnection;
    _lastConnection = next;
    if (next == ConnectionStatus.networkOnly ||
        next == ConnectionStatus.offline) {
      setState(() {
        if (_cart != null) _cartFromSnapshot = true;
        _connectionNotice = 'Sin conexión con FashionStore. '
            'Tus prendas guardadas en el teléfono siguen disponibles.';
      });
    } else if (next == ConnectionStatus.apiAvailable &&
        before != ConnectionStatus.apiAvailable) {
      setState(() {
        _connectionNotice = 'Conexión restablecida. Verificando tus prendas guardadas...';
      });
      _refreshAfterReconnect();
    }
  }

  Future<void> _refreshAfterReconnect() async {
    if (_reconnectionRefreshRunning) return;
    _reconnectionRefreshRunning = true;
    try {
      // Se consulta primero y luego se transfieren solo borradores seguros.
      await SelectedBranchService.initialize();
      await _loadBranches();
      final branch = _selectedBranch;
      if (mounted && branch != null) {
        await _loadCart(branch.id, showLoading: false);
        if (mounted && _drafts.isNotEmpty) await _transferDrafts(branch.id);
      }
    } finally {
      _reconnectionRefreshRunning = false;
    }
  }

  Future<void> _transferDrafts(int branchId) async {
    if (_transferring || _drafts.isEmpty || !mounted) return;
    _syncTotal = _drafts.length;
    _syncCompleted.value = 0;
    _syncPhase.value = 'Enviando prendas guardadas al servidor...';
    setState(() {
      _transferring = true;
      _transferMessage = null;
      _connectionNotice = null;
    });
    _openSyncDialog();
    try {
      final result = await const OfflineCartTransferService().transfer(
        branchId,
        onProgress: (completed, total) {
          if (!mounted) return;
          _syncTotal = total;
          _syncCompleted.value = completed;
        },
      );
      if (!mounted) return;
      await _loadDrafts(branchId);
      await _loadCart(branchId, showLoading: false);
      if (!mounted) return;
      _syncPhase.value = result.needsReview > 0
          ? 'Hay prendas que requieren revisión.'
          : result.failed > 0
              ? 'No se pudieron enviar todas las prendas.'
              : 'Carrito sincronizado correctamente.';
      setState(() {
        // Solo los errores requieren aviso persistente.
        _transferMessage = result.needsReview > 0 || result.failed > 0
            ? result.message : null;
        _connectionNotice = _transferMessage;
      });
      await Future<void>.delayed(const Duration(milliseconds: 1300));
    } catch (error) {
      if (!mounted) return;
      _syncPhase.value = 'La transferencia no se completó.';
      setState(() {
        _transferMessage = 'Conservamos tus prendas pendientes. Revisa la conexión.';
        _connectionNotice = _transferMessage;
      });
      debugPrint('[FS-CARRITO-SYNC] Error: $error');
      await Future<void>.delayed(const Duration(milliseconds: 1700));
    } finally {
      _closeSyncDialog();
      if (mounted) setState(() => _transferring = false);
    }
  }

  Future<void> _bootstrap() async {
    await SelectedBranchService.initialize();
    await _loadBranches();

    if (!mounted) return;

    final branch = _selectedBranch;

    if (branch == null) {
      setState(() {
        _loading = false;
        _error = 'No hay sucursales disponibles.';
      });
      return;
    }

    await _loadCart(branch.id);
    if (mounted && _drafts.isNotEmpty &&
        ConnectivityService.instance.canReachApi) {
      await _transferDrafts(branch.id);
    }
  }

  Future<void> _loadBranches() async {
    setState(() {
      _loadingBranches = true;
    });

    try {
      final branches = await BranchService.getStoreBranches();

      if (!mounted) return;

      final stored = SelectedBranchService.selectedBranch;

      StoreBranch? selected;

      if (stored != null) {
        for (final branch in branches) {
          if (branch.id == stored.id) {
            selected = branch;
            break;
          }
        }
      }

      selected ??= branches.isNotEmpty ? branches.first : null;

      setState(() {
        _branches = branches;
        _selectedBranch = selected;
      });

      if (selected != null &&
          stored?.id != selected.id) {
        await SelectedBranchService.selectBranch(selected);
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error =
            AppErrorMessage.from(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingBranches = false;
        });
      }
    }
  }

  Future<void> _loadCart(
    int branchId, {
    bool showLoading = true,
  }) async {
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      await _loadDrafts(branchId);
      // Primero mostrar la última copia disponible sin esperar el timeout HTTP.
      if (_cart == null) {
        try {
          final cached = await const AccountSnapshotRepository().readCart(branchId);
          if (cached != null && mounted && _selectedBranch?.id == branchId) {
            final saved = MyCartResponse.fromJson(cached);
            setState(() { _cart = saved.cart; _cartFromSnapshot = true; });
          }
        } catch (error) {
          debugPrint('[FS-SNAPSHOT] Error leyendo carrito: $error');
        }
      }
      final result =
          await CartService.getMyCart(branchId);

      if (!mounted ||
          _selectedBranch?.id != branchId) {
        return;
      }

      setState(() {
        _cart = result.cart;
        _cartFromSnapshot = false;
        _error = null;
        if (!_transferring && _lastConnection == ConnectionStatus.apiAvailable) {
          _connectionNotice = null;
        }
      });
    } catch (error) {
      if (!mounted ||
          _selectedBranch?.id != branchId) {
        return;
      }

      setState(() {
        // Mantener la copia remota si la red falla. No convertirla en carrito local.
        _cartFromSnapshot = _cart != null;
        _error = error is AppNetworkException
            ? 'El carrito del cliente requiere conexión al servidor. Tus productos no se han confirmado ni modificado.'
            : AppErrorMessage.from(error);
      });

      // No borrar el contador remoto conocido ante un fallo de red.
    } finally {
      if (mounted && showLoading) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadDrafts(int branchId) async {
    try {
      final drafts = await const OfflineCartRepository().list(branchId);
      if (mounted && _selectedBranch?.id == branchId) {
        setState(() => _drafts = drafts);
      }
    } catch (error) {
      debugPrint('[FS-CARRITO] No se pudieron leer borradores SQLite: $error');
    }
  }

  Future<void> _removeDraft(OfflineCartEntry item) async {
    final branch = _selectedBranch;
    if (branch == null) return;
    try {
      await const OfflineCartRepository().remove(
        branchId: branch.id, variantId: item.variantId);
      await _loadDrafts(branch.id);
    } catch (error) {
      if (mounted) _showError(AppErrorMessage.from(error));
    }
  }

  Future<void> _changeDraftQuantity(OfflineCartEntry item, int nextQuantity) async {
    final branch = _selectedBranch;
    if (branch == null) return;
    try {
      await const OfflineCartRepository().setQuantity(
        branchId: branch.id, variantId: item.variantId, quantity: nextQuantity);
      await _loadDrafts(branch.id);
    } catch (error) {
      if (mounted) _showError(AppErrorMessage.from(error));
    }
  }

  Widget _buildDrafts() {
    if (_drafts.isEmpty && !_transferring && _transferMessage == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        if (_transferMessage != null) ...[
          Text(_transferMessage!, style: const TextStyle(
            color: CartFashionStyle.grey, fontSize: 12)),
          const SizedBox(height: 12),
        ],
        if (_drafts.isNotEmpty) ...[
          const Text('Carrito guardado en este teléfono', style: TextStyle(
            color: CartFashionStyle.ink, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Prendas pendientes de transferir. No están pagadas ni reservadas.',
            style: TextStyle(color: CartFashionStyle.grey)),
          const SizedBox(height: 14),
          ..._drafts.map((item) => _OfflineDraftCard(
            item: item, busy: _transferring,
            onRemove: () => _removeDraft(item),
            onQuantityChanged: (n) => _changeDraftQuantity(item, n),
            onOpen: () => Navigator.push(context, MaterialPageRoute<void>(
              builder: (_) => ProductDetailScreen(productId: item.productId))),
          )),
          if (_lastConnection == ConnectionStatus.apiAvailable) ...[
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              onPressed: _transferring || _selectedBranch == null ? null
                : () => _transferDrafts(_selectedBranch!.id),
              icon: const Icon(Icons.sync_rounded),
              label: const Text('Verificar pendientes de sincronización'),
            )),
          ],
        ],
      ]),
    );
  }

  void _onBranchChanged() {
    final id = SelectedBranchService.selectedBranch?.id;
    if (mounted && id != null && id != _selectedBranch?.id) {
      _bootstrap();
    }
  }

  void _onLocalCartMutation() {
    final branchId = _selectedBranch?.id;
    if (mounted && branchId != null) {
      _loadDrafts(branchId);
    }
  }

  void _onExternalCartMutation() {
    if (!mounted || _selfMutation) return;

    final branchId = _selectedBranch?.id;

    if (branchId == null || _loading) return;

    _loadCart(
      branchId,
      showLoading: false,
    );
  }

  Future<void> _chooseBranch() async {
    if (_loadingBranches || _branches.isEmpty) return;

    final selected = await showModalBottomSheet<StoreBranch>(
      context: context,
      backgroundColor: CartFashionStyle.paper,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight:
            MediaQuery.of(context).size.height * 0.78,
      ),
      builder: (_) => BranchSelectorSheet(
        branches: _branches,
        selectedBranchId: _selectedBranch?.id,
      ),
    );

    if (selected == null ||
        selected.id == _selectedBranch?.id ||
        !mounted) {
      return;
    }

    await SelectedBranchService.selectBranch(selected);

    if (!mounted) return;

    setState(() {
      _selectedBranch = selected;
      _cart = null;
      _cartFromSnapshot = false;
      _drafts = const [];
    });

    await _loadCart(selected.id);
  }

  Future<void> _updateQuantity(
    CartItem item,
    int quantity,
  ) async {
    if (_cartFromSnapshot || _busyItems.contains(item.id) || quantity < 1) {
      return;
    }

    setState(() {
      _busyItems.add(item.id);
      _selfMutation = true;
    });

    try {
      final response =
          await CartService.updateItemQuantity(
        itemId: item.id,
        quantity: quantity,
      );

      if (!mounted) return;

      setState(() {
        _cart = response.cart;
      });
    } catch (error) {
      if (!mounted) return;

      _showError(
        AppErrorMessage.from(error),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyItems.remove(item.id);
          _selfMutation = false;
        });
      }
    }
  }

  Future<void> _removeItem(CartItem item) async {
    if (_cartFromSnapshot || _busyItems.contains(item.id)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: CartFashionStyle.paper,
          title: const Text(
            '¿Quitar del carrito?',
            style: TextStyle(
              color: CartFashionStyle.ink,
            ),
          ),
          content: Text(
            '${item.productVariant.product.name} se eliminará de tu carrito.',
            style: const TextStyle(
              color: CartFashionStyle.grey,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: CartFashionStyle.error,
              ),
              child: const Text('Sí, eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _busyItems.add(item.id);
      _selfMutation = true;
    });

    try {
      final response =
          await CartService.removeItem(item.id);

      if (!mounted) return;

      setState(() {
        _cart = response.cart;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      _showError(
        AppErrorMessage.from(error),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyItems.remove(item.id);
          _selfMutation = false;
        });
      }
    }
  }

  Future<void> _clearCart() async {
    if (_cartFromSnapshot) return;
    final branch = _selectedBranch;
    final cart = _cart;

    if (branch == null ||
        cart == null ||
        cart.items.isEmpty ||
        _clearing) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: CartFashionStyle.paper,
          title: const Text(
            '¿Vaciar carrito?',
            style: TextStyle(
              color: CartFashionStyle.ink,
            ),
          ),
          content: const Text(
            'Se eliminarán todos los productos de este carrito.',
            style: TextStyle(
              color: CartFashionStyle.grey,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: CartFashionStyle.error,
              ),
              child: const Text('Sí, vaciar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _clearing = true;
      _selfMutation = true;
    });

    try {
      final response =
          await CartService.clearMyCart(branch.id);

      if (!mounted) return;

      setState(() {
        _cart = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      _showError(
        AppErrorMessage.from(error),
      );
    } finally {
      if (mounted) {
        setState(() {
          _clearing = false;
          _selfMutation = false;
        });
      }
    }
  }

  Future<void> _goToCheckout() async {
    if (_cartFromSnapshot) return;
    final cart = _cart;
    final branch = _selectedBranch;

    if (cart == null ||
        cart.items.isEmpty ||
        branch == null) {
      return;
    }

    final order = await Navigator.push<CustomerOrder>(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          cartId: cart.id,
        ),
      ),
    );

    if (order == null || !mounted) return;

    setState(() {
      _cart = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Compra ${order.orderCode} creada. El siguiente paso es completar el pago.',
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: CartFashionStyle.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final branch = _selectedBranch;
    final cart = _cart;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Theme(
      data: CartFashionStyle.theme(context),
      child: ColoredBox(
        color: CartFashionStyle.canvas,
        child: SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          final branchId = branch?.id;
          if (branchId != null) {
            await _loadCart(branchId);
          }
        },
        child: CustomScrollView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  10,
                ),
                child: _CartHeader(
                  branch: branch,
                  loadingBranch: _loadingBranches,
                  onChangeBranch: _chooseBranch,
                ),
              ),
            ),
            if (_connectionNotice != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CartFashionStyle.paper,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: CartFashionStyle.line),
                    ),
                    child: Row(children: [
                      Icon(_lastConnection == ConnectionStatus.apiAvailable
                          ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                        color: CartFashionStyle.ink, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_connectionNotice!,
                        style: const TextStyle(
                          color: CartFashionStyle.grey, fontSize: 12))),
                    ]),
                  ),
                ),
              ),
            if (_cartFromSnapshot && _cart != null)
              const SliverToBoxAdapter(child: Padding(
                padding: EdgeInsets.fromLTRB(20, 6, 20, 10),
                child: Text('Carrito del servidor guardado en este dispositivo. '
                    'Es una copia de consulta; los cambios pendientes se muestran aparte.',
                    style: TextStyle(color: CartFashionStyle.grey)),
              )),
            SliverToBoxAdapter(child: _buildDrafts()),
            if (_error != null && _drafts.isNotEmpty)
              const SliverToBoxAdapter(child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text('No hay conexión con el servidor. Estas prendas son solo un borrador local.',
                  style: TextStyle(color: CartFashionStyle.grey)),
              )),
            if (_loading && _drafts.isEmpty && cart == null)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _CartState(
                  loading: true,
                  icon: Icons.shopping_cart_outlined,
                  title: 'Cargando tu carrito...',
                  message:
                      'Estamos consultando tus prendas.',
                ),
              )
            else if (_error != null && _drafts.isEmpty && cart == null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _CartState(
                  icon: Icons.cloud_off_rounded,
                  title:
                      'No pudimos cargar tu carrito',
                  message: _error!,
                  buttonLabel: 'Reintentar',
                  onPressed: branch == null
                      ? null
                      : () => _loadCart(branch.id),
                ),
              )
            else if ((cart == null || cart.items.isEmpty) && _drafts.isEmpty) ...[
              SliverFillRemaining(
                hasScrollBody: false,
                child: _CartState(
                  icon:
                      Icons.shopping_bag_outlined,
                  eyebrow: 'TU CARRITO ESTÁ VACÍO',
                  title:
                      'Tu carrito espera nuevos looks',
                  message:
                      'Descubre prendas que te encanten. Las que elijas para esta sucursal aparecerán aquí.',
                  buttonLabel: 'EXPLORAR PRENDAS',
                  onPressed:
                      widget.onOpenCatalog,
                ),
              ),
            ] else if (cart != null && cart.items.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    2,
                    16,
                    10,
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${cart.totalUnits} ${cart.totalUnits == 1 ? 'unidad' : 'unidades'}',
                        style: const TextStyle(
                          color:
                              CartFashionStyle.grey,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed:
                            _clearing || _cartFromSnapshot ? null : _clearCart,
                        icon: _clearing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.delete_sweep_outlined,
                              ),
                        label: Text(
                          _clearing
                              ? 'Vaciando...'
                              : 'Eliminar todo',
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor:
                              CartFashionStyle.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding:
                    const EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  0,
                ),
                sliver: SliverList(
                  delegate:
                      SliverChildBuilderDelegate(
                    (context, index) {
                      final item = cart.items[index];

                      return CustomerCartItemCard(
                        item: item,
                        busy: _busyItems
                            .contains(item.id),
                        onQuantityChanged:
                            (quantity) =>
                                _updateQuantity(
                          item,
                          quantity,
                        ),
                        onRemove: () =>
                            _removeItem(item),
                      );
                    },
                    childCount: cart.items.length,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    110,
                  ),
                  child: CustomerCartSummaryCard(
                    cart: cart,
                    branchName:
                        branch?.name ??
                        cart.branch?.name ??
                        '',
                    checkoutDisabled:
                        _cartFromSnapshot ||
                        _busyItems.isNotEmpty ||
                        _clearing,
                    onCheckout: _goToCheckout,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ))));
  }
}

class _CartHeader extends StatelessWidget {
  const _CartHeader({
    required this.branch,
    required this.loadingBranch,
    required this.onChangeBranch,
  });

  final StoreBranch? branch;
  final bool loadingBranch;
  final VoidCallback onChangeBranch;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MI CARRITO',
          style: TextStyle(color: CartFashionStyle.muted, fontSize: 11,
              fontWeight: FontWeight.w800, letterSpacing: 1.7),
        ),
        const SizedBox(height: 8),
        const Text(
          'Tus prendas',
          style: TextStyle(color: CartFashionStyle.ink, fontSize: 29,
              fontWeight: FontWeight.w900, letterSpacing: -0.6),
        ),
        const SizedBox(height: 22),
        InkWell(
          onTap:
              loadingBranch ? null : onChangeBranch,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: CartFashionStyle.paper,
              borderRadius:
                  BorderRadius.circular(6),
              border: Border.all(
                color: CartFashionStyle.line,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  color: CartFashionStyle.ink,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Comprando en',
                        style: TextStyle(
                          color:
                              CartFashionStyle.muted,
                          fontSize: 9,
                        ),
                      ),
                      Text(
                        branch?.name ??
                            (loadingBranch
                                ? 'Cargando...'
                                : 'Seleccionar sucursal'),
                        style: const TextStyle(
                          color:
                              CartFashionStyle.ink,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const Text(
                  'Cambiar',
                  style: TextStyle(
                    color: CartFashionStyle.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CartState extends StatelessWidget {
  const _CartState({
    required this.icon,
    required this.title,
    required this.message,
    this.loading = false,
    this.eyebrow,
    this.buttonLabel,
    this.onPressed,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool loading;
  final String? eyebrow;
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
            if (loading)
              const CircularProgressIndicator()
            else
              Icon(
                icon,
                color: CartFashionStyle.muted,
                size: 58,
              ),
            if (eyebrow != null) ...[
              const SizedBox(height: 14),
              Text(
                eyebrow!,
                style: const TextStyle(
                  color: CartFashionStyle.ink,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: CartFashionStyle.ink,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: CartFashionStyle.grey,
                height: 1.35,
              ),
            ),
            if (buttonLabel != null &&
                onPressed != null) ...[
              const SizedBox(height: 16),
              FilledButton(
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

class _OfflineDraftCard extends StatelessWidget {
  const _OfflineDraftCard({required this.item, required this.busy,
    required this.onRemove, required this.onQuantityChanged, required this.onOpen});
  final OfflineCartEntry item;
  final bool busy;
  final VoidCallback onRemove;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: CartFashionStyle.paper,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: CartFashionStyle.line)),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(onTap: onOpen, child: Container(
            width: 96, height: 110,
            decoration: BoxDecoration(color: CartFashionStyle.canvas,
              borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.checkroom_rounded,
              color: CartFashionStyle.muted, size: 44))),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('GUARDADO LOCALMENTE', style: TextStyle(
              color: CartFashionStyle.ink, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text(item.productName, style: const TextStyle(
              color: CartFashionStyle.ink, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 7),
            Text(item.variantLabel, style: const TextStyle(
              color: CartFashionStyle.grey, fontSize: 12)),
          ])),
          IconButton(onPressed: busy ? null : onRemove,
            icon: const Icon(Icons.delete_outline, color: CartFashionStyle.error),
            tooltip: 'Eliminar borrador'),
        ]),
        const SizedBox(height: 14),
        const Divider(height: 1, color: CartFashionStyle.line),
        const SizedBox(height: 10),
        Row(children: [
          IconButton(onPressed: busy || item.quantity <= 1 ? null
            : () => onQuantityChanged(item.quantity - 1),
            icon: const Icon(Icons.remove_circle_outline),
            color: CartFashionStyle.ink),
          Text('${item.quantity}', style: const TextStyle(
            color: CartFashionStyle.ink, fontWeight: FontWeight.bold)),
          IconButton(onPressed: busy ? null
            : () => onQuantityChanged(item.quantity + 1),
            icon: const Icon(Icons.add_circle_outline),
            color: CartFashionStyle.ink),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('Bs ${(item.unitPriceCents / 100).toStringAsFixed(2)} c/u',
              style: const TextStyle(color: CartFashionStyle.grey, fontSize: 11)),
            Text('Bs ${(item.totalCents / 100).toStringAsFixed(2)}',
              style: const TextStyle(color: CartFashionStyle.ink,
                fontWeight: FontWeight.bold, fontSize: 19)),
          ]),
        ]),
      ]),
    );
  }
}
