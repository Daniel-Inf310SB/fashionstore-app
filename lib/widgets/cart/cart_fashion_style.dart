import 'package:flutter/material.dart';

/// Colores locales del carrito. No altera el tema ni la lógica del resto de la app.
class CartFashionStyle {
  static const Color paper = Color(0xFFFFFFFF);
  static const Color canvas = Color(0xFFF7F7F7);
  static const Color ink = Color(0xFF151515);
  static const Color grey = Color(0xFF696969);
  static const Color muted = Color(0xFF969696);
  static const Color line = Color(0xFFE5E5E5);
  static const Color success = Color(0xFF23704B);
  static const Color error = Color(0xFFB02A39);

  static ThemeData theme(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: ink,
        onPrimary: paper,
        surface: paper,
        onSurface: ink,
        error: error,
      ),
      textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink),
      dividerColor: line,
      iconTheme: const IconThemeData(color: ink),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: ink),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: paper,
          disabledBackgroundColor: line,
          disabledForegroundColor: muted,
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: const BorderSide(color: line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: ink),
      ),
    );
  }
}
