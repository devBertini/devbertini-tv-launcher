/*
 * DevBertini theme for LTvLauncher (GPL-3.0, like the rest of this project).
 * Copyright (C) 2026 Claudio Bertini (devBertini)
 */

import 'package:flutter/material.dart';

/// Theme ids stored in SettingsService.themes for the cinematic looks: the Vitrine home, each with its own colours.
const String devBertiniTheme = 'devbertini';
const String auroraTheme = 'aurora';
const String cinemaTheme = 'cinema';
const String neonTheme = 'neon';
const String oceanTheme = 'oceano';

/// Whether [theme] uses the cinematic layout, the Vitrine home.
bool isCinematicTheme(String theme) => CinematicPalette.all.any((palette) => palette.id == theme);

/// The colours of one cinematic theme.
class CinematicPalette {
  final String id;
  final String name;

  /// Glow around focused cards and controls.
  final Color glow;

  /// Fill of a focused control, and the text and icons on it.
  final Color focusFill;
  final Color focusInk;

  /// Small caps captions.
  final Color caption;

  /// Background of the icon squares in the settings, and the focus of the launcher's own pages.
  final Color tileTint;

  /// The Vitrine home's accent (docs/devbertini/DESIGN-VITRINE.md, "Tokens"): its tone on the light field and on
  /// black, and the accent as text on the light field (at least 5:1 on every light surface). On black the
  /// [caption] colour is the accent as text.
  final Color lightTone;
  final Color blackTone;
  final Color lightInk;

  /// The notification count's fill on black, when it is not [lightTone] (a palette whose light tone is a dark ink).
  final Color? badgeOnBlack;

  /// The notification count's fill on black.
  Color get badgeOnBlackTone => badgeOnBlack ?? lightTone;

  const CinematicPalette({
    required this.id,
    required this.name,
    required this.glow,
    required this.focusFill,
    required this.focusInk,
    required this.caption,
    required this.tileTint,
    required this.lightTone,
    required this.blackTone,
    required this.lightInk,
    this.badgeOnBlack,
  });

  /// The launcher's own palette: no hue of its own, so it sits with any art. On black its accent is the soft white of
  /// the text and the Continuar capsule; on the light field, the ink.
  static const devBertini = CinematicPalette(
    id: devBertiniTheme,
    name: 'DevBertini',
    glow: Color(0xFFF2F4F8),
    focusFill: Color(0xFFFFF8EC),
    focusInk: Color(0xFF000000),
    caption: Color(0xFFF2F4F8),
    tileTint: Color(0xFF4A525E),
    lightTone: Color(0xFF14171C),
    blackTone: Color(0xFFF2F4F8),
    lightInk: Color(0xFF14171C),
    badgeOnBlack: Color(0xFFF2F4F8),
  );

  static const aurora = CinematicPalette(
    id: auroraTheme,
    name: 'Aurora',
    glow: Color(0xFF10B981),
    focusFill: Color(0xFFD1FAE5),
    focusInk: Color(0xFF022C22),
    caption: Color(0xFF6EE7B7),
    tileTint: Color(0xFF059669),
    lightTone: Color(0xFF047857),
    blackTone: Color(0xFF10B981),
    lightInk: Color(0xFF065F46),
  );

  static const cinema = CinematicPalette(
    id: cinemaTheme,
    name: 'Cinema Dourado',
    glow: Color(0xFFE0A63A),
    focusFill: Color(0xFFF2C46D),
    focusInk: Color(0xFF1A1205),
    caption: Color(0xFFE8B44A),
    tileTint: Color(0xFFA8771F),
    lightTone: Color(0xFF8A5A0B),
    blackTone: Color(0xFFE0A63A),
    lightInk: Color(0xFF6F4A08),
  );

  static const neon = CinematicPalette(
    id: neonTheme,
    name: 'Neon',
    glow: Color(0xFFFF2BD6),
    focusFill: Color(0xFFFF2BD6),
    focusInk: Color(0xFFFFFFFF),
    caption: Color(0xFFF472D0),
    tileTint: Color(0xFFC026D3),
    lightTone: Color(0xFFB5179E),
    blackTone: Color(0xFFFF2BD6),
    lightInk: Color(0xFF9A1286),
  );

  static const ocean = CinematicPalette(
    id: oceanTheme,
    name: 'Oceano',
    glow: Color(0xFF0EA5E9),
    focusFill: Color(0xFFBAE6FD),
    focusInk: Color(0xFF082F49),
    caption: Color(0xFF7DD3FC),
    tileTint: Color(0xFF0369A1),
    lightTone: Color(0xFF0369A1),
    blackTone: Color(0xFF0EA5E9),
    lightInk: Color(0xFF075985),
  );

  static const List<CinematicPalette> all = [devBertini, aurora, cinema, neon, ocean];

  static CinematicPalette of(String theme) =>
      all.firstWhere((palette) => palette.id == theme, orElse: () => devBertini);

  /// Hex of the glow, for the launcher's accent colour setting (switches, sliders, panels).
  String get glowHex => glow.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
}

/// Hands the current cinematic palette to everything under it.
class CinematicThemeScope extends InheritedWidget {
  final CinematicPalette palette;

  const CinematicThemeScope({super.key, required this.palette, required super.child});

  static CinematicPalette of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CinematicThemeScope>()?.palette ?? CinematicPalette.devBertini;

  @override
  bool updateShouldNotify(CinematicThemeScope old) => old.palette.id != palette.id;
}

/// The studio's dark palette on true black: a Mini LED panel turns its zones fully off for #000, so every surface
/// without content stays exactly black. The devBertini intro's values on iOS, except the tile and the soft ink, which
/// take the Vitrine's neutral graphite and grey so no purple shows on the TVs.
class DevBertiniColors {
  static const Color background = Color(0xFF000000);
  static const Color ink = Color(0xFFF5F0E8);
  static const Color inkSoft = Color(0xFFA3A8B0);
  static const Color tile = Color(0xFF4A525E);
  static const Color stem = Color(0xFFFFF8EC);
  static const Color bowl = Color(0xFFFFC468);
}

/// The smallest share of the screen the home can be shrunk to (Screen area setting).
const double devBertiniMinScreenArea = 0.86;

/// Display name of a category: the three categories the launcher creates on first run keep their
/// English names in the database, so they are translated here when the TV speaks Portuguese.
String categoryDisplayName(BuildContext context, String name) {
  if (Localizations.localeOf(context).languageCode != 'pt') {
    return name;
  }
  switch (name) {
    case 'TV Apps':
      return 'Apps';
    case 'Non-TV Apps':
      return 'Outros apps';
    case 'Favorites':
      return 'Favoritos';
    default:
      return name;
  }
}