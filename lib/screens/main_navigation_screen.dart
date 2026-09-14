import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../services/auth_service.dart';
import '../widgets/bottom_nav_bar.dart';

import 'home/home_screen.dart';
import 'catalog/catalog_screen.dart';
import 'reservations/reservations_screen.dart';
import 'cart/cart_screen.dart';
import 'profile/profile_screen.dart';


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


  final List<Widget> _screens = const [
    HomeScreen(),
    CatalogScreen(),
    ReservationsScreen(),
    CartScreen(),
  ];


  String _photoUrl = '';


  @override
  void initState() {
    super.initState();

    _loadProfilePhoto();
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


  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
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


          // =========================
          // BOTÓN PERFIL FLOTANTE
          // =========================

          Positioned(
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
                          AppColors.surface,

                      border:
                          Border.all(
                        color:
                            AppColors.primary
                                .withValues(
                          alpha:
                              0.35,
                        ),

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
                                        AppColors.textPrimary,

                                    size:
                                        23,
                                  );
                                },
                              )
                            : const Icon(
                                Icons.person_rounded,

                                color:
                                    AppColors.textPrimary,

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
          SafeArea(
        top:
            false,

        child:
            BottomNavBar(
          currentIndex:
              _currentIndex,

          onTap:
              _changePage,
        ),
      ),
    );
  }
}