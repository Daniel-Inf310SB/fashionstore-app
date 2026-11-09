import 'package:flutter/material.dart';

/// Paleta local de la experiencia de reservas.
/// No modifica el tema global ni la lógica comercial.
abstract final class ReservationFashionStyle {
  static const Color background = Color(0xFFF7F7F7);
  static const Color surface = Colors.white;
  static const Color surfaceLight = Color(0xFFF4F4F4);
  static const Color primary = Color(0xFF151515);
  static const Color primaryLight = Color(0xFF151515);
  static const Color textPrimary = Color(0xFF171717);
  static const Color textSecondary = Color(0xFF676767);
  static const Color textMuted = Color(0xFF858585);
  static const Color divider = Color(0xFFE4E4E4);
  static const Color success = Color(0xFF237451);
  static const Color warning = Color(0xFF946218);
  static const Color error = Color(0xFFBA3747);

  static ThemeData theme(BuildContext context) {
    final previous = Theme.of(context);
    return previous.copyWith(
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      colorScheme: previous.colorScheme.copyWith(
        brightness: Brightness.light,
        primary: primary,
        onPrimary: Colors.white,
        surface: surface,
        onSurface: textPrimary,
        error: error,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(color: textPrimary, fontSize: 19,
          fontWeight: FontWeight.w800),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),
      cardTheme: const CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: divider),
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
      dividerColor: divider,
    );
  }
}
