/*
 * DevBertini theme for LTvLauncher (GPL-3.0, like the rest of this project).
 */

import 'package:flauncher/devbertini/vitrine/tokens.dart';
import 'package:flutter/material.dart';

/// The Material theme of the launcher's pages (settings, dialogs, panels) in the Vitrine colours of [t]: Onest
/// everywhere, the panel colour for surfaces, the palette's accent for focus, switches, sliders and selections.
ThemeData vitrineMaterialTheme(VitrineTokens t) {
  final accent = t.accent;
  final typography = Typography.material2018();
  final text = t.isDark ? typography.white : typography.black;
  return ThemeData(
    useMaterial3: true,
    brightness: t.brightness,
    fontFamily: vitrineFont,
    colorScheme: ColorScheme.fromSeed(
      seedColor: accent,
      brightness: t.brightness,
      primary: accent,
      onPrimary: t.onAccent,
      secondary: accent,
      onSecondary: t.onAccent,
      surface: t.panel,
      onSurface: t.ink,
      onSurfaceVariant: t.ink2,
      outline: t.plateEdge,
      outlineVariant: t.plateEdge,
    ),
    cardColor: t.panel,
    canvasColor: t.panel,
    scaffoldBackgroundColor: t.field,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    splashColor: Colors.transparent,
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: t.ink,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        splashFactory: NoSplash.splashFactory,
      ),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: t.panel,
      titleTextStyle: text.titleLarge?.copyWith(fontFamily: vitrineFont, color: t.ink),
      contentTextStyle: text.bodyMedium?.copyWith(fontFamily: vitrineFont, color: t.ink),
    ),
    appBarTheme: const AppBarTheme(elevation: 0, backgroundColor: Colors.transparent),
    typography: typography,
    inputDecorationTheme: InputDecorationTheme(
      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.ink)),
      labelStyle: text.bodyMedium?.copyWith(fontFamily: vitrineFont, color: t.ink2),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: accent,
      selectionColor: accent.withValues(alpha: 0.4),
      selectionHandleColor: accent,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: accent),
    sliderTheme: SliderThemeData(
      activeTrackColor: accent,
      thumbColor: accent,
      inactiveTrackColor: accent.withValues(alpha: 0.3),
    ),
    toggleButtonsTheme: ToggleButtonsThemeData(
      selectedColor: accent,
      fillColor: accent.withValues(alpha: 0.1),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? accent : null),
      trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? accent.withValues(alpha: 0.5) : null),
    ),
    tabBarTheme: TabBarThemeData(indicatorColor: accent),
  );
}
