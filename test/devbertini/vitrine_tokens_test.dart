import 'dart:convert';

import 'package:flauncher/devbertini/brand.dart';
import 'package:flauncher/devbertini/profile_model.dart';
import 'package:flauncher/devbertini/vitrine/material_theme.dart';
import 'package:flauncher/devbertini/vitrine/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG contrast of two opaque colours.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('appearance', () {
    test('Escuro is dark day and night', () {
      expect(vitrineBrightness(appearanceDark, night: false), Brightness.dark);
      expect(vitrineBrightness(appearanceDark, night: true), Brightness.dark);
    });

    test('Claro is light day and night', () {
      expect(vitrineBrightness(appearanceLight, night: false), Brightness.light);
      expect(vitrineBrightness(appearanceLight, night: true), Brightness.light);
    });

    test('Automatico is dark in the night hours and light outside them', () {
      expect(vitrineBrightness(appearanceAuto, night: true), Brightness.dark);
      expect(vitrineBrightness(appearanceAuto, night: false), Brightness.light);
    });

    test('the home starts dark, and a value this build does not know draws dark', () {
      expect(defaultAppearance, appearanceDark);
      expect(vitrineBrightness('', night: false), Brightness.dark);
      expect(vitrineBrightness('sepia', night: false), Brightness.dark);
    });
  });

  group('tokens', () {
    test('dark DevBertini matches the spec', () {
      final t = VitrineTokens.dark(CinematicPalette.devBertini);
      expect(t.brightness, Brightness.dark);
      expect([t.fieldTop, t.field, t.fieldBottom, t.plate, t.panel], everyElement(const Color(0xFF000000)));
      expect(t.plateEdge, const Color(0xFF262A31));
      expect(t.quiet, const Color(0xFF15171C));
      expect(t.ink, const Color(0xFFF2F4F8));
      expect(t.ink2, const Color(0xFFA3A8B0));
      expect(t.ink3, const Color(0xFF8A9099));
      // No hue of its own: the accent is the soft white of the text and the Continuar capsule.
      expect(t.accent, const Color(0xFFF2F4F8));
      expect(t.accentInk, const Color(0xFFF2F4F8));
      expect(t.badge, const Color(0xFFF2F4F8));
      expect(t.onBadge, const Color(0xFF000000));
      expect(t.gold, const Color(0xFFE8B04A));
      expect(t.primary, const Color(0xFFF2F4F8));
      expect(t.focusShadow, isEmpty);
      expect(t.panelShadow, isEmpty);
    });

    test('light DevBertini matches the spec', () {
      final t = VitrineTokens.light(CinematicPalette.devBertini);
      expect(t.brightness, Brightness.light);
      expect(t.fieldTop, const Color(0xFFEAEEF3));
      expect(t.field, const Color(0xFFE4E9EF));
      expect(t.fieldBottom, const Color(0xFFDCE3EB));
      expect(t.plate, const Color(0xFFFFFFFF));
      expect(t.plateEdge, const Color(0xFFD3DAE3));
      expect(t.panel, const Color(0xFFF3F6F9));
      expect(t.ink, const Color(0xFF14171C));
      expect(t.ink2, const Color(0xFF4A525E));
      expect(t.ink3, const Color(0xFF5B6370));
      // The ink on the light field.
      expect(t.accent, const Color(0xFF14171C));
      expect(t.accentInk, const Color(0xFF14171C));
      expect(t.badge, const Color(0xFF14171C));
      expect(t.onBadge, const Color(0xFFFFFFFF));
      expect(t.gold, const Color(0xFF7A5410));
      expect(t.focusShadow, hasLength(1));
      expect(t.panelShadow, hasLength(1));
    });

    test('each palette brings its two accent tones', () {
      const tones = {
        devBertiniTheme: (Color(0xFF14171C), Color(0xFFF2F4F8)),
        auroraTheme: (Color(0xFF047857), Color(0xFF10B981)),
        cinemaTheme: (Color(0xFF8A5A0B), Color(0xFFE0A63A)),
        neonTheme: (Color(0xFFB5179E), Color(0xFFFF2BD6)),
        oceanTheme: (Color(0xFF0369A1), Color(0xFF0EA5E9)),
      };
      expect(CinematicPalette.all.map((p) => p.id), unorderedEquals(tones.keys));
      for (final palette in CinematicPalette.all) {
        expect(VitrineTokens.light(palette).accent, tones[palette.id]!.$1, reason: palette.id);
        expect(VitrineTokens.dark(palette).accent, tones[palette.id]!.$2, reason: palette.id);
      }
    });

    test('every palette keeps its text and its count readable in both themes', () {
      for (final palette in CinematicPalette.all) {
        final light = VitrineTokens.light(palette), dark = VitrineTokens.dark(palette);
        for (final surface in [light.fieldTop, light.field, light.fieldBottom, light.panel, light.plate]) {
          expect(_contrast(light.accentInk, surface), greaterThanOrEqualTo(4.5), reason: '${palette.id} accent text');
          expect(_contrast(light.gold, surface), greaterThanOrEqualTo(4.5), reason: '${palette.id} Dourado');
        }
        expect(_contrast(dark.accentInk, dark.field), greaterThanOrEqualTo(4.5), reason: '${palette.id} accent text');
        for (final t in [light, dark]) {
          expect(_contrast(t.onBadge, t.badge), greaterThanOrEqualTo(4.5), reason: '${palette.id} count');
          expect(_contrast(t.badge, t.panel), greaterThanOrEqualTo(3), reason: '${palette.id} count on the rail');
          expect(_contrast(t.onAccent, t.accent), greaterThanOrEqualTo(4.5), reason: '${palette.id} on accent');
          expect(_contrast(t.accent, t.field), greaterThanOrEqualTo(3), reason: '${palette.id} focus ring');
        }
      }
    });

    test('the studio mark and the first profile carry no purple, so none shows on the TVs', () {
      bool purple(Color c) {
        final hsv = HSVColor.fromColor(c);
        return hsv.saturation > 0.25 && hsv.hue >= 240 && hsv.hue <= 300;
      }

      // The check sees the violet tile and the soft violet the mark had.
      expect(purple(const Color(0xFF6A4FE6)), isTrue);
      expect(purple(const Color(0xFFB7A4FF)), isTrue);
      expect(purple(DevBertiniColors.tile), isFalse);
      expect(purple(DevBertiniColors.inkSoft), isFalse);
      expect(purple(profileColors.first), isFalse);
      // The mark's strokes stay readable on its tile.
      expect(_contrast(DevBertiniColors.stem, DevBertiniColors.tile), greaterThanOrEqualTo(4.5));
      expect(_contrast(DevBertiniColors.bowl, DevBertiniColors.tile), greaterThanOrEqualTo(3));
    });

    test('tokens are equal by palette and brightness', () {
      final palette = CinematicPalette.aurora;
      expect(VitrineTokens.of(palette, Brightness.dark), VitrineTokens.dark(palette));
      expect(VitrineTokens.of(palette, Brightness.light), VitrineTokens.light(palette));
      expect(VitrineTokens.dark(palette), isNot(VitrineTokens.light(palette)));
      expect(VitrineTokens.dark(palette), isNot(VitrineTokens.dark(CinematicPalette.neon)));
    });

    test('the field is black on dark and a top-to-bottom gradient on light', () {
      expect(VitrineTokens.dark(CinematicPalette.devBertini).fieldDecoration.gradient, isNull);
      final gradient = VitrineTokens.light(CinematicPalette.devBertini).fieldDecoration.gradient as LinearGradient;
      expect(gradient.colors, const [Color(0xFFEAEEF3), Color(0xFFE4E9EF), Color(0xFFDCE3EB)]);
      expect(gradient.stops, const [0, 0.45, 1]);
      expect(gradient.begin, Alignment.topCenter);
    });
  });

  group('type', () {
    test('Onest at any weight, with the spec line height split evenly', () {
      final style = vitrineText(28, weight: 450, line: 32, tracking: -0.6);
      expect(style.fontFamily, vitrineFont);
      expect(style.fontWeight!.value, 450);
      expect(style.height, 32 / 28);
      expect(style.leadingDistribution, TextLeadingDistribution.even);
      expect(style.letterSpacing, -0.6);
      final plain = vitrineText(12);
      expect(plain.fontWeight!.value, 400);
      expect(plain.height, isNull);
      expect(plain.leadingDistribution, isNull);
    });

    test('Onest and its licence are bundled', () async {
      final fonts = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List<dynamic>;
      final onest = fonts.firstWhere((f) => f['family'] == vitrineFont);
      expect((onest['fonts'] as List).single['asset'], 'assets/fonts/Onest/Onest-Variable.ttf');
      expect((await rootBundle.load('assets/fonts/Onest/Onest-Variable.ttf')).lengthInBytes, greaterThan(100000));
      expect(await rootBundle.loadString('assets/fonts/Onest/OFL.txt'), contains('SIL Open Font License'));
    });
  });

  group('theme', () {
    testWidgets('VitrineTheme hands down its tokens, dark DevBertini without one', (tester) async {
      late VitrineTokens seen;
      Widget probe() => Builder(builder: (context) {
            seen = VitrineTheme.of(context);
            return const SizedBox();
          });
      await tester.pumpWidget(probe());
      expect(seen, VitrineTokens.dark(CinematicPalette.devBertini));
      final light = VitrineTokens.light(CinematicPalette.ocean);
      await tester.pumpWidget(VitrineTheme(tokens: light, child: probe()));
      expect(seen, light);
    });

    test('the pages theme follows the tokens', () {
      for (final t in [VitrineTokens.dark(CinematicPalette.cinema), VitrineTokens.light(CinematicPalette.cinema)]) {
        final theme = vitrineMaterialTheme(t);
        expect(theme.brightness, t.brightness);
        expect(theme.colorScheme.primary, t.accent);
        expect(theme.colorScheme.onPrimary, t.onAccent);
        expect(theme.colorScheme.surface, t.panel);
        expect(theme.scaffoldBackgroundColor, t.field);
        expect(theme.dialogTheme.backgroundColor, t.panel);
        expect(theme.textTheme.bodyMedium!.fontFamily, vitrineFont);
        expect(theme.dialogTheme.titleTextStyle!.color, t.ink);
      }
    });
  });
}
