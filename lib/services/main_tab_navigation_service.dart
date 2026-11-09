import 'package:flutter/material.dart';

/// Permite volver a las pestañas de la navegación principal sin crear
/// otro MainNavigationScreen ni perder su estado.
class MainTabNavigationService {
  MainTabNavigationService._();

  /// El IndexedStack conserva las pestañas: este valor informa cuál está visible.
  static final ValueNotifier<int> selectedTab = ValueNotifier<int>(0);

  static VoidCallback? _openCart;
  static VoidCallback? _openHome;

  static void registerCart(VoidCallback callback) => _openCart = callback;

  static void unregisterCart() => _openCart = null;

  static void registerHome(VoidCallback callback) => _openHome = callback;

  static void unregisterHome() => _openHome = null;

  /// Regresa al inicio existente, sin crear otra navegación principal.
  static void openHome(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    _openHome?.call();
  }

  static void openCart(BuildContext context) {
    final callback = _openCart;
    if (callback == null) {
      Navigator.of(context).maybePop();
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
    callback();
  }
}
