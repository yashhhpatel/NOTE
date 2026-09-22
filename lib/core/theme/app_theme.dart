import 'package:flutter/material.dart';

/// Noteflow's original design language: a calm, paper-inspired look built on
/// Material 3 with a distinct teal-forward seed colour.
class AppTheme {
  const AppTheme._();

  /// Brand seed — Noteflow's signature teal. Not derived from any other app.
  static const Color seed = Color(0xFF2F9E8B);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
    );

    return base.copyWith(
      scaffoldBackgroundColor: brightness == Brightness.dark
          ? const Color(0xFF16181C)
          : const Color(0xFFF6F7F9),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: base.scaffoldBackgroundColor,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
      ),
      cardTheme: CardTheme(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: scheme.outlineVariant.withOpacity(0.5),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        isDense: true,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: 8,
      ),
    );
  }
}
