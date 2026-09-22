import 'package:flutter/material.dart';

/// A single note colour with variants tuned for light and dark themes.
///
/// Notes store only the palette [id] (an int), so the palette can evolve
/// visually without a data migration.
@immutable
class NoteColor {
  const NoteColor({
    required this.id,
    required this.name,
    required this.light,
    required this.dark,
    required this.accent,
  });

  final int id;
  final String name;

  /// Card background in light theme.
  final Color light;

  /// Card background in dark theme.
  final Color dark;

  /// A saturated accent used for edit-screen headers / indicators.
  final Color accent;

  Color background(Brightness b) => b == Brightness.dark ? dark : light;
}

/// Noteflow's original note palette. `id == 0` is the neutral default.
///
/// These are independent, hand-picked values — not copied from any other app.
class NoteColors {
  const NoteColors._();

  static const List<NoteColor> all = [
    NoteColor(
      id: 0,
      name: 'Default',
      light: Color(0xFFFFFFFF),
      dark: Color(0xFF2A2D34),
      accent: Color(0xFF5B6472),
    ),
    NoteColor(
      id: 1,
      name: 'Amber',
      light: Color(0xFFFFF3D6),
      dark: Color(0xFF4A3B1B),
      accent: Color(0xFFE0A32E),
    ),
    NoteColor(
      id: 2,
      name: 'Coral',
      light: Color(0xFFFFE0DB),
      dark: Color(0xFF4A2A26),
      accent: Color(0xFFE86A5A),
    ),
    NoteColor(
      id: 3,
      name: 'Rose',
      light: Color(0xFFFDDDEA),
      dark: Color(0xFF44202F),
      accent: Color(0xFFD65C87),
    ),
    NoteColor(
      id: 4,
      name: 'Lilac',
      light: Color(0xFFE9DEFB),
      dark: Color(0xFF322546),
      accent: Color(0xFF8A63D2),
    ),
    NoteColor(
      id: 5,
      name: 'Sky',
      light: Color(0xFFD7EAFB),
      dark: Color(0xFF1F3345),
      accent: Color(0xFF3D8BD4),
    ),
    NoteColor(
      id: 6,
      name: 'Teal',
      light: Color(0xFFD2F0EA),
      dark: Color(0xFF1C3B37),
      accent: Color(0xFF2F9E8B),
    ),
    NoteColor(
      id: 7,
      name: 'Sage',
      light: Color(0xFFDDF0D6),
      dark: Color(0xFF25391F),
      accent: Color(0xFF5FA84E),
    ),
    NoteColor(
      id: 8,
      name: 'Sand',
      light: Color(0xFFEDE6D8),
      dark: Color(0xFF3A352A),
      accent: Color(0xFFAE9B6E),
    ),
    NoteColor(
      id: 9,
      name: 'Slate',
      light: Color(0xFFDFE3E8),
      dark: Color(0xFF2E343B),
      accent: Color(0xFF6B7783),
    ),
  ];

  /// Returns the colour for [id], falling back to the neutral default.
  static NoteColor byId(int id) {
    if (id >= 0 && id < all.length) return all[id];
    return all.first;
  }
}
