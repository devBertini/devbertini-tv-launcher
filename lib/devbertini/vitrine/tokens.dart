/*
 * DevBertini theme for LTvLauncher (GPL-3.0, like the rest of this project).
 * Copyright (C) 2026 Claudio Bertini (devBertini)
 *
 * The Vitrine home's colours and type, dark and light (docs/devbertini/DESIGN-VITRINE.md, "Tokens"), and the
 * Aparência setting that picks between them.
 */

import 'package:flauncher/devbertini/brand.dart';
import 'package:flutter/material.dart';

/// Values of the Aparência setting (SettingsService.appearance): Escuro, Claro and Automático.
const String appearanceDark = 'dark';
const String appearanceLight = 'light';
const String appearanceAuto = 'auto';

/// The home starts dark.
const String defaultAppearance = appearanceDark;

/// The brightness [appearance] draws in: Claro always light, Automático light outside the Modo noite hours ([night],
/// 22h to 6h), Escuro and any value this build does not know dark.
Brightness vitrineBrightness(String appearance, {required bool night}) =>
    appearance == appearanceLight || (appearance == appearanceAuto && !night) ? Brightness.light : Brightness.dark;

/// The one family of the Vitrine home, bundled with its licence (pubspec.yaml). It is variable (wght 100 to 900), and a
/// FontWeight of any value sets that axis.
const String vitrineFont = 'Onest';

/// Onest at [size] logical px and [weight] (100 to 900, any value). [line] is the line height in px as the spec gives
/// it, with the leading split evenly above and below the text as CSS does; [tracking] is the letter spacing in px.
TextStyle vitrineText(double size, {int weight = 400, Color? color, double? line, double? tracking}) => TextStyle(
      fontFamily: vitrineFont,
      fontSize: size,
      fontWeight: FontWeight(weight),
      color: color,
      height: line == null ? null : line / size,
      leadingDistribution: line == null ? null : TextLeadingDistribution.even,
      letterSpacing: tracking,
    );

const Color _black = Color(0xFF000000);
const Color _white = Color(0xFFFFFFFF);

/// The colours of the Vitrine home in one brightness, with the accent of one palette. Shadows are given as Flutter
/// blur radii: CSS's blur B is a Gaussian of sigma B / 2, Flutter's radius r one of 0.577 r + 0.5.
@immutable
class VitrineTokens {
  final CinematicPalette palette;
  final Brightness brightness;

  /// The field the home is painted on, top to bottom (one colour on black).
  final Color fieldTop;
  final Color field;
  final Color fieldBottom;

  /// App plates and the selected rail item, with their 1 px edge.
  final Color plate;
  final Color plateEdge;

  /// The quiet capsule (Detalhes), with its 1 px edge on black.
  final Color quiet;
  final Color? quietEdge;

  /// The open rail and the settings panels, with their 1 px edge and, on the light field, their shadow.
  final Color panel;
  final Color panelEdge;
  final List<BoxShadow> panelShadow;

  /// Text: main, secondary and quiet (rail icons at rest).
  final Color ink;
  final Color ink2;
  final Color ink3;

  /// The unfilled part of progress bars.
  final Color track;

  /// Focus rings, the selected rail icon and selections; [onAccent] is what is drawn on it; [accentInk] is the accent
  /// as text; [accentTint] fills a selected choice (the Aparência theme cards).
  final Color accent;
  final Color onAccent;
  final Color accentInk;
  final Color accentTint;

  /// Warnings that are not errors: no internet on the network, what a TV update undid of the setup.
  final Color gold;

  /// The count on Notificações and the ring of the colour under it.
  final Color badge;
  final Color badgeRing;

  /// The count's digits: black on a light fill, white on a dark one.
  Color get onBadge => badge.computeLuminance() > 0.4 ? _black : _white;

  /// The primary capsule (Continuar), its text and its edge on the light field.
  final Color primary;
  final Color primaryInk;
  final Color? primaryEdge;

  /// The one shadow under the focused element, on the light field only.
  final List<BoxShadow> focusShadow;

  /// Laid over the home behind a settings panel.
  final Color dim;

  /// The colours the hero's art dissolves into: downwards, and towards the left and right edges.
  final Color heroFadeDown;
  final Color heroFadeSide;

  const VitrineTokens._({
    required this.palette,
    required this.brightness,
    required this.fieldTop,
    required this.field,
    required this.fieldBottom,
    required this.plate,
    required this.plateEdge,
    required this.quiet,
    required this.quietEdge,
    required this.panel,
    required this.panelEdge,
    required this.panelShadow,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.track,
    required this.accent,
    required this.onAccent,
    required this.accentInk,
    required this.accentTint,
    required this.gold,
    required this.badge,
    required this.badgeRing,
    required this.primary,
    required this.primaryInk,
    required this.primaryEdge,
    required this.focusShadow,
    required this.dim,
    required this.heroFadeDown,
    required this.heroFadeSide,
  });

  /// The home on black: every surface without content is #000, which the TV's Mini LED zones turn fully off.
  factory VitrineTokens.dark(CinematicPalette palette) => VitrineTokens._(
        palette: palette,
        brightness: Brightness.dark,
        fieldTop: _black,
        field: _black,
        fieldBottom: _black,
        plate: _black,
        plateEdge: const Color(0xFF262A31),
        quiet: const Color(0xFF15171C),
        quietEdge: const Color(0xFF262A31),
        panel: _black,
        panelEdge: const Color(0xFF262A31),
        panelShadow: const [],
        ink: const Color(0xFFF2F4F8),
        ink2: const Color(0xFFA3A8B0),
        ink3: const Color(0xFF8A9099),
        track: const Color(0x38F2F4F8),
        accent: palette.blackTone,
        onAccent: _black,
        accentInk: palette.caption,
        accentTint: Color.alphaBlend(palette.blackTone.withValues(alpha: 0.2), _black),
        gold: const Color(0xFFE8B04A),
        badge: palette.badgeOnBlackTone,
        badgeRing: _black,
        primary: const Color(0xFFF2F4F8),
        primaryInk: _black,
        primaryEdge: null,
        focusShadow: const [],
        dim: const Color(0x99000000),
        heroFadeDown: _black,
        heroFadeSide: _black,
      );

  /// The home on the light field.
  factory VitrineTokens.light(CinematicPalette palette) => VitrineTokens._(
        palette: palette,
        brightness: Brightness.light,
        fieldTop: const Color(0xFFEAEEF3),
        field: const Color(0xFFE4E9EF),
        fieldBottom: const Color(0xFFDCE3EB),
        plate: _white,
        plateEdge: const Color(0xFFD3DAE3),
        quiet: const Color(0x1214171C),
        quietEdge: null,
        panel: const Color(0xFFF3F6F9),
        panelEdge: const Color(0xFFD3DAE3),
        // CSS 8px 0 24px rgba(20, 23, 28, 0.10).
        panelShadow: const [BoxShadow(color: Color(0x1A14171C), offset: Offset(8, 0), blurRadius: 20)],
        ink: const Color(0xFF14171C),
        ink2: const Color(0xFF4A525E),
        ink3: const Color(0xFF5B6370),
        track: const Color(0x2414171C),
        accent: palette.lightTone,
        onAccent: _white,
        accentInk: palette.lightInk,
        accentTint: Color.alphaBlend(palette.lightTone.withValues(alpha: 0.12), _white),
        gold: const Color(0xFF7A5410),
        badge: palette.lightInk,
        badgeRing: const Color(0xFFE8ECF1),
        primary: _white,
        primaryInk: const Color(0xFF14171C),
        primaryEdge: const Color(0xFFD3DAE3),
        // CSS 0 6px 14px rgba(20, 23, 28, 0.16).
        focusShadow: const [BoxShadow(color: Color(0x2914171C), offset: Offset(0, 6), blurRadius: 11)],
        dim: const Color(0x6114171C),
        heroFadeDown: const Color(0xFFE2E7EE),
        heroFadeSide: const Color(0xFFE8ECF1),
      );

  /// The tokens of [palette] in [brightness].
  factory VitrineTokens.of(CinematicPalette palette, Brightness brightness) =>
      brightness == Brightness.light ? VitrineTokens.light(palette) : VitrineTokens.dark(palette);

  bool get isDark => brightness == Brightness.dark;

  /// The field as a decoration: black, or the light field's painted vertical gradient.
  BoxDecoration get fieldDecoration => isDark
      ? BoxDecoration(color: field)
      : BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [fieldTop, field, fieldBottom],
            stops: const [0, 0.45, 1],
          ),
        );

  @override
  bool operator ==(Object other) =>
      other is VitrineTokens && other.palette.id == palette.id && other.brightness == brightness;

  @override
  int get hashCode => Object.hash(palette.id, brightness);
}

/// Hands the Vitrine tokens to everything under it (FLauncherApp puts it above every page).
class VitrineTheme extends InheritedWidget {
  final VitrineTokens tokens;

  const VitrineTheme({super.key, required this.tokens, required super.child});

  static final VitrineTokens _fallback = VitrineTokens.dark(CinematicPalette.devBertini);

  /// The tokens in force; dark DevBertini where no VitrineTheme is above (a widget tested alone).
  static VitrineTokens of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<VitrineTheme>()?.tokens ?? _fallback;

  @override
  bool updateShouldNotify(VitrineTheme oldWidget) => oldWidget.tokens != tokens;
}
