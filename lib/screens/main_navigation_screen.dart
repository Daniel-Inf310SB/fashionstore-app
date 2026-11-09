import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants/app_colors.dart';
import '../services/auth_service.dart';
import '../widgets/bottom_nav_bar.dart';

import 'home/home_screen.dart';
import 'catalog/catalog_screen.dart';
import 'reservations/reservations_screen.dart';
import 'cart/cart_screen.dart';
import 'profile/profile_screen.dart';
import 'notifications/notifications_screen.dart';
import 'catalog/product_detail_screen.dart';
import 'cart/checkout_screen.dart';
import 'profile/purchase_history_screen.dart';

import '../models/ai_assistant.dart';
import '../services/cart_service.dart';
import '../services/main_tab_navigation_service.dart';
import '../services/selected_branch_service.dart';
import '../services/ai_assistant_context_service.dart';
import '../services/ai_assistant_navigation_service.dart';
import '../services/push_notification_service.dart';
import '../screens/ai/ai_assistant_screen.dart';
import '../widgets/ai/ai_assistant_floating_button.dart';


class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({
    super.key,
  });

  @override
  State<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}


class _MainNavigationScreenState
    extends State<MainNavigationScreen> {

  int _currentIndex = 0;
  bool _assistantOpen = false;


  late final List<Widget> _screens;


  String _photoUrl = '';


  @override
  void initState() {
    super.initState();

    _screens = [
      HomeScreen(
        onOpenCatalog: () => _changePage(1),
      ),
      CatalogScreen(
        onOpenCart: () => _changePage(3),
      ),
      ReservationsScreen(
        onOpenCatalog: () => _changePage(1),
      ),
      CartScreen(
        onOpenCatalog: () => _changePage(1),
      ),
    ];

    MainTabNavigationService.selectedTab.value = 0;
    MainTabNavigationService.registerCart(() => _changePage(3));
    MainTabNavigationService.registerHome(() => _changePage(0));
    _loadProfilePhoto();

    AIAssistantNavigationService.register(
      _handleAssistantNavigation,
    );
    AIAssistantContextService.enable(
      currentPage: 'home',
    );
  }

  @override
  void dispose() {
    MainTabNavigationService.unregisterCart();
    MainTabNavigationService.unregisterHome();
    AIAssistantNavigationService.unregister();
    AIAssistantContextService.disable();
    super.dispose();
  }


  // =========================
  // CARGAR FOTO DE PERFIL
  // =========================

  Future<void> _loadProfilePhoto() async {
    final photo =
        await AuthService.getUserPhoto();

    if (!mounted) {
      return;
    }

    setState(() {
      _photoUrl =
          photo ?? '';
    });
  }


  // =========================
  // CAMBIAR PÁGINA
  // =========================

  void _changePage(
    int index,
  ) {
    if (index ==
        _currentIndex) {
      return;
    }

    setState(() {
      _currentIndex =
          index;
    });
    MainTabNavigationService.selectedTab.value = index;

    switch (index) {
      case 1:
        AIAssistantContextService.setPage('catalog');
        break;
      case 2:
        AIAssistantContextService.setPage('reservations');
        break;
      case 3:
        AIAssistantContextService.setPage('cart');
        break;
      case 0:
      default:
        AIAssistantContextService.setPage('home');
        break;
    }
  }


  // El acceso al asistente vive exclusivamente en las cuatro pestañas
  // principales. Las rutas secundarias se apilan encima de este Scaffold,
  // por lo que nunca reciben el botón flotante.
  Future<void> _openAssistant() async {
    if (_assistantOpen) return;
    final navigator = PushNotificationService.navigatorKey.currentState;
    if (navigator == null) return;

    final assistantContext = AIAssistantContextService.current;
    setState(() => _assistantOpen = true);
    try {
      final navigation = await navigator.push<CustomerAssistantNavigation>(
        MaterialPageRoute(
          builder: (_) => AIAssistantScreen(
            currentPage: assistantContext.currentPage,
            productId: assistantContext.productId,
            variantId: assistantContext.variantId,
            cartItemId: assistantContext.cartItemId,
            reservationId: assistantContext.reservationId,
          ),
        ),
      );
      if (navigation != null && mounted) {
        await AIAssistantNavigationService.handle(navigation);
      }
    } finally {
      if (mounted) setState(() => _assistantOpen = false);
    }
  }

  // =========================
  // ABRIR PERFIL
  // =========================

  Future<void> _openProfile() async {
    await Navigator.push(
      context,

      MaterialPageRoute(
        builder:
            (_) =>
                const ProfileScreen(),
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadProfilePhoto();
  }



  // =========================
  // ASISTENTE IA
  // =========================

  void _returnToMainShell() {
    Navigator.of(context).popUntil(
      (route) => route.isFirst,
    );
  }


  Future<void> _handleAssistantNavigation(
    CustomerAssistantNavigation navigation,
  ) async {
    switch (navigation.target.toUpperCase()) {
      case 'HOME':
        _returnToMainShell();
        _changePage(0);
        return;

      case 'CATALOG':
        final search =
            navigation.catalogSearch;

        if (search == null) {
          _returnToMainShell();
          _changePage(1);
          return;
        }

        await SelectedBranchService.initialize();

        if (!mounted) {
          return;
        }

        _returnToMainShell();
        _changePage(1);

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CatalogScreen(
              branchId:
                  SelectedBranchService
                      .selectedBranch
                      ?.id,
              initialSearch: search,
            ),
          ),
        );

        return;

      case 'CART':
        _returnToMainShell();
        _changePage(3);
        return;

      case 'RESERVATIONS':
        _returnToMainShell();
        _changePage(2);
        return;

      case 'ORDERS':
        _returnToMainShell();
        AIAssistantContextService.setPage('orders');

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const PurchaseHistoryScreen(),
          ),
        );
        return;

      case 'PRODUCT':
        final productId =
            navigation.productId;

        if (productId == null ||
            productId <= 0) {
          _showAssistantError(
            'No pude identificar el producto.',
          );
          return;
        }

        _returnToMainShell();
        AIAssistantContextService.setProduct(
          productId: productId,
        );

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ProductDetailScreen(
              productId: productId,
              onOpenCart: () {
                Navigator.of(context).pop();
                _changePage(3);
              },
            ),
          ),
        );

        return;

      case 'CHECKOUT':
        await _openAssistantCheckout();
        return;

      default:
        _showAssistantError(
          'La navegación solicitada todavía no está soportada en Flutter.',
        );
    }
  }


  Future<void> _openAssistantCheckout() async {
    await SelectedBranchService.initialize();

    final branch =
        SelectedBranchService.selectedBranch;

    if (!mounted) {
      return;
    }

    if (branch == null) {
      _showAssistantError(
        'Selecciona una sucursal antes de continuar al pago.',
      );
      return;
    }

    try {
      final cartResponse =
          await CartService.getMyCart(
        branch.id,
      );

      final cart =
          cartResponse.cart;

      if (!cartResponse.hasCart ||
          cart == null ||
          cart.items.isEmpty) {
        _showAssistantError(
          'Tu carrito está vacío. Agrega productos antes de continuar al pago.',
        );
        return;
      }

      if (!mounted) {
        return;
      }

      _returnToMainShell();
      AIAssistantContextService.setPage('checkout');

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              CheckoutScreen(
            cartId: cart.id,
          ),
        ),
      );
    } catch (error) {
      _showAssistantError(
        error
            .toString()
            .replaceFirst(
              'Exception: ',
              '',
            ),
      );
    }
  }


  void _showAssistantError(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            AppColors.error,
      ),
    );
  }


  @override
  Widget build(
    BuildContext context,
  ) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Color(0xFFE9E9E9),
      ),
      child: Scaffold(
      backgroundColor:
          AppColors.background,


      // =========================
      // CONTENIDO
      // =========================

      body: Stack(
        clipBehavior:
            Clip.none,

        children: [

          // =========================
          // VISTAS PRINCIPALES
          // =========================

          Positioned.fill(
            child: IndexedStack(
              index:
                  _currentIndex,

              children:
                  _screens,
            ),
          ),


          // Solo las pestañas principales muestran el asistente.
          // Otras pantallas (detalle, perfil, checkout, devoluciones)
          // se abren en rutas superiores y lo ocultan automáticamente.
          if (!_assistantOpen)
            Positioned(
              right: 14,
              bottom: 16,
              child: AIAssistantFloatingButton(
                onTap: _openAssistant,
              ),
            ),

          // =========================
          // BOTÓN NOTIFICACIONES
          // =========================

          if (_currentIndex != 1) Positioned(
            top: 6,
            right: 58,
            child: SafeArea(
              child: Material(
                color: Colors.transparent,
                elevation: 10,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    );
                  },
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color: const Color(0xFFE5E5E5),
                        width: 1.2,
                      ),
                    ),
                    child: const Icon(
                      Icons.notifications_none_rounded,
                      color: const Color(0xFF141414),
                      size: 23,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // =========================
          // BOTÓN PERFIL FLOTANTE
          // =========================

          if (_currentIndex != 1) Positioned(
            top:
                6,

            right:
                10,

            child:
                SafeArea(
              child:
                  Material(
                color:
                    Colors.transparent,

                elevation:
                    10,

                shape:
                    const CircleBorder(),

                child:
                    InkWell(
                  onTap:
                      _openProfile,

                  customBorder:
                      const CircleBorder(),

                  child:
                      Container(
                    width:
                        40,

                    height:
                        40,

                    clipBehavior:
                        Clip.antiAlias,

                    decoration:
                        BoxDecoration(
                      shape:
                          BoxShape.circle,

                      color:
                          Colors.white,

                      border:
                          Border.all(
                        color: const Color(0xFFE5E5E5),

                        width:
                            1.2,
                      ),

                      boxShadow: [
                        BoxShadow(
                          color:
                              Colors.black
                                  .withValues(
                            alpha:
                                0.30,
                          ),

                          blurRadius:
                              12,

                          spreadRadius:
                              1,

                          offset:
                              const Offset(
                            0,
                            4,
                          ),
                        ),
                      ],
                    ),

                    child:
                        _photoUrl.isNotEmpty
                            ? Image.network(
                                _photoUrl,

                                fit:
                                    BoxFit.cover,

                                errorBuilder:
                                    (
                                  context,
                                  error,
                                  stackTrace,
                                ) {
                                  return const Icon(
                                    Icons.person_rounded,

                                    color:
                                        Color(0xFF141414),

                                    size:
                                        23,
                                  );
                                },
                              )
                            : const Icon(
                                Icons.person_rounded,

                                color:
                                    Color(0xFF141414),

                                size:
                                    23,
                              ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),


      // =========================
      // NAVEGACIÓN INFERIOR
      // =========================

      bottomNavigationBar:
          ColoredBox(
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: BottomNavBar(
          currentIndex:
              _currentIndex,

          onTap:
              _changePage,
          ),
        ),
      ),
      ),
    );
  }
}