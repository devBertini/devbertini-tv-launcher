import 'package:flauncher/devbertini/brand.dart';
import 'package:flauncher/devbertini/cinematic.dart';
import 'package:flauncher/devbertini/tv_extras.dart';
import 'package:flauncher/devbertini/vitrine/appearance_page.dart';
import 'package:flauncher/devbertini/vitrine/focus.dart';
import 'package:flauncher/devbertini/vitrine/tokens.dart';
import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/settings/settings_panel.dart';
import 'package:flauncher/widgets/settings/themes_page.dart';
import 'package:flauncher/widgets/side_panel_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

late SettingsService _settings;
late SharedPreferences _prefs;

/// The TV's canvas: 960x540 logical px at a device pixel ratio of 2.
void _tv(WidgetTester tester) {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

VitrineTokens _tokens(Brightness brightness, [CinematicPalette palette = CinematicPalette.devBertini]) =>
    VitrineTokens.of(palette, brightness);

/// [home] inside the real settings service, the Vitrine tokens of [brightness] and the app's localizations.
Widget _app(Widget home, {Brightness brightness = Brightness.dark, String lang = 'pt'}) {
  final palette = CinematicPalette.of(_settings.themes);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsService>.value(value: _settings),
      ChangeNotifierProvider<NightModeService>(create: (_) => NightModeService(_prefs)),
      ChangeNotifierProvider<OpenMeteoService>(create: (_) => OpenMeteoService(_prefs)),
    ],
    child: MaterialApp(
      locale: Locale(lang),
      localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
      supportedLocales: AppLocalizations.supportedLocales,
      home: VitrineTheme(
        tokens: VitrineTokens.of(palette, brightness),
        child: Scaffold(backgroundColor: Colors.transparent, body: home),
      ),
    ),
  );
}

/// The page where the panel puts it: a 384 px panel on the right.
Widget _panelWith(Widget page) => SidePanelDialog(width: 384, isRightSide: true, child: page);

/// The Vitrine focus frame of the card or row that holds [label].
Finder _frameOf(String label) => find.ancestor(of: find.text(label), matching: find.byType(VitrineFocusFrame)).first;

/// The fill of the card or row that holds [label]: the first decoration under its frame that has a colour.
Color? _fillOf(WidgetTester tester, String label) => tester
    .widgetList<DecoratedBox>(find.descendant(of: _frameOf(label), matching: find.byType(DecoratedBox)))
    .map((box) => box.decoration)
    .whereType<BoxDecoration>()
    .firstWhere((d) => d.color != null)
    .color;

/// Where the card or row that holds [label] is drawn, scale included (the frame scales the layer it holds).
Rect _drawnRect(WidgetTester tester, String label) =>
    tester.getRect(find.descendant(of: _frameOf(label), matching: find.byType(DecoratedBox)).first);

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

/// The Container of the panel [SidePanelDialog] draws in the cinematic looks.
Container _panelContainer(WidgetTester tester) =>
    tester.widget<Container>(find.descendant(of: find.byType(SidePanelDialog), matching: find.byType(Container)).first);

/// The 1 px edge the panel paints over its inner side.
Border _edge(Container panel) => (panel.foregroundDecoration as BoxDecoration).border! as Border;

Color? _textColor(WidgetTester tester, String text) => tester.widget<Text>(find.text(text)).style?.color;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Real text widths: the test font is a wide square.
    final loader = FontLoader(vitrineFont)..addFont(rootBundle.load('assets/fonts/Onest/Onest-Variable.ttf'));
    await loader.load();
  });

  setUp(() async {
    SharedPreferencesStorePlatform.instance = InMemorySharedPreferencesStore.empty();
    _prefs = await SharedPreferences.getInstance();
    await _prefs.clear();
    _settings = SettingsService(_prefs);
  });

  group('Aparência page', () {
    testWidgets('draws the mockup panel: crumb, title, three theme cards, the help and five accent rows', (
      tester,
    ) async {
      _tv(tester);
      await tester.pumpWidget(_app(_panelWith(const VitrineAppearancePage())));
      await tester.pumpAndSettle();

      expect(find.text('Configurações'), findsOneWidget);
      expect(find.text('Tela inicial'), findsOneWidget);
      expect(find.text('Aparência'), findsOneWidget);
      expect(find.text('Tema'), findsOneWidget);
      expect(find.text('Automático fica escuro das 22h às 6h, no mesmo horário do Modo noite.'), findsOneWidget);
      expect(find.text('Cor de destaque'), findsOneWidget);
      for (final name in ['Claro', 'Escuro', 'Automático', for (final p in CinematicPalette.all) p.name]) {
        expect(find.text(name), findsOneWidget, reason: name);
      }

      // The panel is 384 wide; the content keeps 28 from its inner edge and 48 from the screen's: 308 wide, so each
      // card is (308 - 2 x 10) / 3 = 96 wide and 6 + 52 + 30 = 88 tall, 10 apart.
      final panelLeft = 960.0 - 384;
      final light = tester.getRect(_frameOf('Claro'));
      final dark = tester.getRect(_frameOf('Escuro'));
      final darkDrawn = _drawnRect(tester, 'Escuro'); // focused: drawn 6% larger, around the same centre
      final auto = tester.getRect(_frameOf('Automático'));
      expect(light.left, closeTo(panelLeft + 28, 0.01));
      expect(light.width, closeTo(96, 0.01));
      expect(light.height, closeTo(88, 0.01));
      expect(auto.right, closeTo(960 - 48, 0.01));
      expect(auto.width, closeTo(96, 0.01));
      expect(dark.center.dx, closeTo(light.right + 10 + 48, 0.01));
      expect(darkDrawn.width, closeTo(96 * 1.06, 0.01));
      expect(darkDrawn.center.dx, closeTo(dark.center.dx, 0.01));

      // Five rows 34 tall with 4 between them, all inside the screen without scrolling.
      final rows = [for (final p in CinematicPalette.all) tester.getRect(_frameOf(p.name))];
      for (final row in rows) {
        expect(row.height, closeTo(34, 0.01));
        expect(row.width, closeTo(308, 0.01));
      }
      for (var i = 1; i < rows.length; i++) {
        expect(rows[i].top - rows[i - 1].bottom, closeTo(4, 0.01));
      }
      expect(rows.last.bottom, lessThanOrEqualTo(540));
      // Title at the mockup's y: panel top 34, the 18 px crumb, 4 and the 32 px title line.
      expect(tester.getTopLeft(find.text('Aparência')).dy, closeTo(34 + 18 + 4, 6));
    });

    testWidgets('English strings under an English locale', (tester) async {
      _tv(tester);
      await tester.pumpWidget(_app(_panelWith(const VitrineAppearancePage()), lang: 'en'));
      await tester.pumpAndSettle();
      for (final text in [
        'Settings',
        'Home screen',
        'Appearance',
        'Theme',
        'Light',
        'Dark',
        'Automatic',
        'Accent color',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(find.text('Automatic turns dark from 10 pm to 6 am, the same hours as Night mode.'), findsOneWidget);
    });

    testWidgets('the chosen theme and accent carry the check and the tint, and follow the settings', (tester) async {
      _tv(tester);
      await tester.pumpWidget(_app(_panelWith(const VitrineAppearancePage())));
      await tester.pumpAndSettle();
      final t = _tokens(Brightness.dark);

      Finder check(String label) => find.descendant(of: _frameOf(label), matching: find.byIcon(Icons.check_rounded));
      Color? fill(String label) => _fillOf(tester, label);

      // Defaults: Escuro and the DevBertini palette.
      expect(check('Escuro'), findsOneWidget);
      expect(check('Claro'), findsNothing);
      expect(check('Automático'), findsNothing);
      expect(fill('Escuro'), t.accentTint);
      expect(fill('Claro'), t.quiet);
      expect(_textColor(tester, 'Escuro'), t.accentInk);
      expect(_textColor(tester, 'Claro'), t.ink);
      expect(check('DevBertini'), findsOneWidget);
      for (final p in CinematicPalette.all.where((p) => p.id != devBertiniTheme)) {
        expect(check(p.name), findsNothing, reason: p.name);
      }

      await _settings.setAppearance(appearanceAuto);
      await _settings.setThemes(cinemaTheme);
      await tester.pumpAndSettle();
      expect(check('Automático'), findsOneWidget);
      expect(check('Escuro'), findsNothing);
      expect(check('Cinema Dourado'), findsOneWidget);
      expect(check('DevBertini'), findsNothing);

      await _settings.setAppearance(appearanceLight);
      await tester.pumpAndSettle();
      expect(check('Claro'), findsOneWidget);
      expect(check('Automático'), findsNothing);

      // A value this build does not know reads as Escuro, the way the theme does.
      await _settings.setAppearance('sepia');
      await tester.pumpAndSettle();
      expect(check('Escuro'), findsOneWidget);
    });

    testWidgets('OK on each theme card sets the Aparência setting; the arrows move between the cards', (tester) async {
      _tv(tester);
      await tester.pumpWidget(_app(_panelWith(const VitrineAppearancePage())));
      await tester.pumpAndSettle();
      expect(_settings.appearance, appearanceDark);

      // The chosen card holds the focus when the page opens (Escuro).
      await _key(tester, LogicalKeyboardKey.arrowLeft);
      await _key(tester, LogicalKeyboardKey.select);
      expect(_settings.appearance, appearanceLight);

      await _key(tester, LogicalKeyboardKey.arrowRight);
      await _key(tester, LogicalKeyboardKey.arrowRight);
      await _key(tester, LogicalKeyboardKey.enter);
      expect(_settings.appearance, appearanceAuto);

      await _key(tester, LogicalKeyboardKey.arrowLeft);
      await _key(tester, LogicalKeyboardKey.select);
      expect(_settings.appearance, appearanceDark);
    });

    testWidgets('OK on each accent row sets the palette in the theme setting', (tester) async {
      _tv(tester);
      await tester.pumpWidget(_app(_panelWith(const VitrineAppearancePage())));
      await tester.pumpAndSettle();

      // Down from the cards reaches the first row (DevBertini); one Down more per palette.
      await _key(tester, LogicalKeyboardKey.arrowDown);
      for (final palette in CinematicPalette.all) {
        if (palette != CinematicPalette.all.first) await _key(tester, LogicalKeyboardKey.arrowDown);
        await _key(tester, LogicalKeyboardKey.select);
        expect(_settings.themes, palette.id, reason: palette.name);
        // The Vitrine accent in force is the palette's: the page's tokens are rebuilt by the app, here by hand.
      }
      // The last palette's check shows, and OK again keeps it.
      expect(find.descendant(of: _frameOf('Oceano'), matching: find.byIcon(Icons.check_rounded)), findsOneWidget);
    });

    testWidgets('focus: a card scales to 1.06 under the 3 px accent ring, a row keeps scale 1 with a plate fill', (
      tester,
    ) async {
      _tv(tester);
      await tester.pumpWidget(_app(_panelWith(const VitrineAppearancePage())));
      await tester.pumpAndSettle();
      final t = _tokens(Brightness.dark);

      final card = tester.widget<VitrineFocusFrame>(_frameOf('Escuro'));
      expect(card.focused, isTrue);
      expect(card.scale, 1.06);
      expect(card.radius, 12);
      expect(tester.widget<VitrineFocusFrame>(_frameOf('Claro')).focused, isFalse);

      await _key(tester, LogicalKeyboardKey.arrowDown);
      final row = tester.widget<VitrineFocusFrame>(_frameOf('DevBertini'));
      expect(row.focused, isTrue);
      expect(row.scale, 1);
      expect(row.radius, 10);
      expect(tester.widget<VitrineFocusFrame>(_frameOf('Escuro')).focused, isFalse);
      expect(tester.getRect(_frameOf('DevBertini')).height, closeTo(34, 0.01));

      // The ring is 3 px of the accent.
      final ring = tester
          .widgetList<DecoratedBox>(find.descendant(of: _frameOf('DevBertini'), matching: find.byType(DecoratedBox)))
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.border != null && d.border!.top.width == 3);
      expect(ring.border!.top.color, t.accent);
    });

    testWidgets('the swatches are the palettes\' tone for the theme in force', (tester) async {
      _tv(tester);
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(_app(_panelWith(const VitrineAppearancePage()), brightness: brightness));
        await tester.pumpAndSettle();
        final swatches = tester
            .widgetList<DecoratedBox>(find.byType(DecoratedBox))
            .map((box) => box.decoration)
            .whereType<BoxDecoration>()
            .where((d) => d.shape == BoxShape.circle)
            .map((d) => d.color)
            .toList();
        expect(swatches, [
          for (final p in CinematicPalette.all) brightness == Brightness.dark ? p.blackTone : p.lightTone,
        ]);
      }
    });

    for (final brightness in Brightness.values) {
      testWidgets('draws in the ${brightness.name} theme with its tokens', (tester) async {
        _tv(tester);
        await _settings.setAppearance(brightness == Brightness.light ? appearanceLight : appearanceDark);
        await tester.pumpWidget(_app(_panelWith(const VitrineAppearancePage()), brightness: brightness));
        await tester.pumpAndSettle();
        final t = _tokens(brightness);

        expect(tester.takeException(), isNull);
        expect(_textColor(tester, 'Aparência'), t.ink);
        expect(_textColor(tester, 'Tema'), t.ink);
        expect(_textColor(tester, 'Cor de destaque'), t.ink);
        expect(_textColor(tester, 'Configurações'), t.ink2);
        expect(_textColor(tester, 'Automático fica escuro das 22h às 6h, no mesmo horário do Modo noite.'), t.ink2);
        final fillOfUnselected = _fillOf(tester, 'Automático');
        expect(fillOfUnselected, brightness == Brightness.dark ? t.quiet : t.plate);
        // The panel under the page is the theme's panel colour, with the edge on its inner side.
        expect(_panelContainer(tester).decoration, isA<BoxDecoration>().having((d) => d.color, 'color', t.panel));
        expect(_edge(_panelContainer(tester)).left.color, t.panelEdge);
      });
    }

    testWidgets('every choice has a Semantics label, and the chosen ones are selected', (tester) async {
      _tv(tester);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(_panelWith(const VitrineAppearancePage())));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.bySemanticsLabel('Escuro')),
        isSemantics(label: 'Escuro', isButton: true, hasSelectedState: true, isSelected: true, hasTapAction: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Claro')),
        isSemantics(label: 'Claro', isButton: true, hasSelectedState: true, isSelected: false, hasTapAction: true),
      );
      for (final label in ['Claro', 'Automático', for (final p in CinematicPalette.all) p.name]) {
        expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      }
      handle.dispose();
    });
  });

  group('the shell', () {
    testWidgets('the panel takes tokens.panel in both themes, with the edge inside and the shadow on light only', (
      tester,
    ) async {
      _tv(tester);
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          _app(const SidePanelDialog(width: 384, isRightSide: true, child: Text('conteúdo')), brightness: brightness),
        );
        await tester.pumpAndSettle();
        final t = _tokens(brightness);
        final panel = _panelContainer(tester);
        final decoration = panel.decoration as BoxDecoration;
        expect(decoration.color, t.panel, reason: brightness.name);
        expect(_edge(panel).left.color, t.panelEdge);
        expect(_edge(panel).right, BorderSide.none);
        if (brightness == Brightness.dark) {
          expect(decoration.boxShadow, isEmpty);
          expect(t.panel, const Color(0xFF000000));
        } else {
          // Cast towards the content, which is on the left of a right-hand panel.
          expect(decoration.boxShadow, hasLength(1));
          expect(decoration.boxShadow!.single.offset.dx, -t.panelShadow.single.offset.dx);
          expect(decoration.boxShadow!.single.color, t.panelShadow.single.color);
        }
        expect(tester.getRect(find.byWidget(panel)), const Rect.fromLTWH(576, 0, 384, 540));
      }
    });

    testWidgets('a left-hand panel keeps the edge on its right and the shadow as the tokens give it', (tester) async {
      _tv(tester);
      await tester.pumpWidget(
        _app(const SidePanelDialog(width: 250, child: Text('conteúdo')), brightness: Brightness.light),
      );
      await tester.pumpAndSettle();
      final t = _tokens(Brightness.light);
      final panel = _panelContainer(tester);
      expect(_edge(panel).right.color, t.panelEdge);
      expect(_edge(panel).left, BorderSide.none);
      expect((panel.decoration as BoxDecoration).boxShadow!.single.offset, t.panelShadow.single.offset);
      expect(tester.getRect(find.byWidget(panel)), const Rect.fromLTWH(0, 0, 250, 540));
    });

    testWidgets('the settings panel dims with tokens.dim and sits on the left, where the rail is, 384 wide, in both themes', (
      tester,
    ) async {
      _tv(tester);
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(_app(const SettingsPanel(), brightness: brightness));
        await tester.pumpAndSettle();
        final t = _tokens(brightness);
        final scaffold = tester
            .widgetList<Scaffold>(find.byType(Scaffold))
            .firstWhere((s) => s.backgroundColor == t.dim);
        expect(scaffold.backgroundColor, t.dim, reason: brightness.name);
        final dialog = tester.widget<SidePanelDialog>(find.byType(SidePanelDialog));
        expect(dialog.isRightSide, isFalse);
        expect(dialog.width, 384);
        expect(tester.getRect(find.byWidget(_panelContainer(tester))), const Rect.fromLTWH(0, 0, 384, 540));
        expect(_panelContainer(tester).decoration, isA<BoxDecoration>().having((d) => d.color, 'color', t.panel));
        // The first page: "Configurações" and its groups, in the ink of the theme.
        expect(find.text('Tela inicial'), findsOneWidget);
        expect(_textColor(tester, 'Configurações'), t.ink);
        expect(_textColor(tester, 'Tela inicial'), t.ink);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('the older themes keep the left panel and the dark scrim', (tester) async {
      _tv(tester);
      await _settings.setThemes('modern');
      await tester.pumpWidget(_app(const SettingsPanel()));
      await tester.pumpAndSettle();
      final dialog = tester.widget<SidePanelDialog>(find.byType(SidePanelDialog));
      expect(dialog.isRightSide, isFalse);
      expect(dialog.width, 350);
      expect(
        tester
            .widgetList<Scaffold>(find.byType(Scaffold))
            .any((s) => s.backgroundColor == Colors.black.withValues(alpha: 0.70)),
        isTrue,
      );
    });

    testWidgets('Tela inicial offers Aparência (opening the new page) and Seções under its own entry', (tester) async {
      _tv(tester);
      await tester.pumpWidget(_app(const SettingsPanel(), brightness: Brightness.light));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tela inicial'));
      await tester.pumpAndSettle();
      expect(find.text('Aparência'), findsOneWidget);
      expect(find.text('Escuro, DevBertini'), findsOneWidget); // what is in force, under the entry
      expect(find.text('Seções'), findsOneWidget);
      expect(find.text('Cor de destaque'), findsNothing); // no old accent colour page in the cinematic themes
      expect(find.byType(VitrineAppearancePage), findsNothing);

      await tester.tap(find.text('Aparência'));
      await tester.pumpAndSettle();
      expect(find.byType(VitrineAppearancePage), findsOneWidget);
      expect(find.text('Cor de destaque'), findsOneWidget);

      // Back closes the page inside the panel first.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(VitrineAppearancePage), findsNothing);
      expect(find.text('Seções'), findsOneWidget);
    });

    testWidgets('the tile of Aparência says the theme and the palette in force', (tester) async {
      _tv(tester);
      await _settings.setAppearance(appearanceAuto);
      await _settings.setThemes(oceanTheme);
      await tester.pumpWidget(_app(const SettingsPanel()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tela inicial'));
      await tester.pumpAndSettle();
      expect(find.text('Automático, Oceano'), findsOneWidget);
    });

    testWidgets('the settings rows read in the ink of each theme and take the plate with the ring when focused', (
      tester,
    ) async {
      _tv(tester);
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(const SizedBox()); // a fresh tree: the first row autofocuses again
        await tester.pumpWidget(
          _app(
            _panelWith(
              Column(
                children: [
                  DevBertiniTile(
                    icon: Icons.home_outlined,
                    title: 'Linha um',
                    subtitle: 'detalhe',
                    autofocus: true,
                    onPressed: () {},
                  ),
                  DevBertiniTile(icon: Icons.tune_rounded, title: 'Linha dois', onPressed: () {}),
                  const DevBertiniStepperValue('5 min'),
                ],
              ),
            ),
            brightness: brightness,
          ),
        );
        await tester.pumpAndSettle();
        final t = _tokens(brightness);
        expect(_textColor(tester, 'Linha um'), t.ink, reason: brightness.name);
        expect(_textColor(tester, 'detalhe'), t.ink2);
        expect(tester.widget<VitrineFocusFrame>(_frameOf('Linha um')).focused, isTrue);
        expect(tester.widget<VitrineFocusFrame>(_frameOf('Linha um')).scale, 1);
        expect(tester.widget<VitrineFocusFrame>(_frameOf('Linha dois')).focused, isFalse);
        final focusedFill = _fillOf(tester, 'Linha um');
        expect(focusedFill, brightness == Brightness.dark ? t.quiet : t.plate);
        final restFill = _fillOf(tester, 'Linha dois');
        expect(restFill, Colors.transparent);
        await _key(tester, LogicalKeyboardKey.arrowDown);
        expect(tester.widget<VitrineFocusFrame>(_frameOf('Linha dois')).focused, isTrue);
        expect(tester.widget<VitrineFocusFrame>(_frameOf('Linha um')).focused, isFalse);
      }
    });

    testWidgets('ThemesPage shows the Aparência page in the cinematic looks', (tester) async {
      _tv(tester);
      await tester.pumpWidget(_app(_panelWith(const ThemesPage())));
      await tester.pumpAndSettle();
      expect(find.byType(VitrineAppearancePage), findsOneWidget);
    });
  });
}
