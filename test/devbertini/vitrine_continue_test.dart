import 'dart:io';

import 'package:flauncher/devbertini/brand.dart';
import 'package:flauncher/devbertini/cinematic.dart';
import 'package:flauncher/devbertini/vitrine/continue_cards.dart';
import 'package:flauncher/devbertini/vitrine/focus.dart';
import 'package:flauncher/devbertini/vitrine/logos.dart';
import 'package:flauncher/devbertini/vitrine/tokens.dart';
import 'package:flauncher/models/watch_next_program.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/watch_next_service.dart';
import 'package:flauncher/widgets/watch_next_info_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import '../mocks.mocks.dart';

// A 1x1 white PNG, enough for a logo to be read and drawn.
final List<int> _png = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00,
  0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0D, 0x49,
  0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xFF, 0xFF, 0xFF, 0x7F, 0x00, 0x09, 0xFB, 0x03, 0xFD, 0x2A, 0x86, 0xE3,
  0x8A, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

const _min = 60000;

/// Material's English strings for any locale: the page is tested in Portuguese and the dialogs still need them.
class _AnyLocaleMaterial extends LocalizationsDelegate<MaterialLocalizations> {
  const _AnyLocaleMaterial();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) => DefaultMaterialLocalizations.delegate.load(const Locale('en'));

  @override
  bool shouldReload(_AnyLocaleMaterial old) => false;
}

WatchNextProgram program({
  int id = 1,
  String package = 'com.wbd.stream',
  String title = 'House of the Dragon',
  int position = 20 * _min,
  int duration = 90 * _min,
  String art = '',
}) =>
    WatchNextProgram(
      id: id,
      packageName: package,
      title: title,
      description: 'Description',
      watchNextType: 0,
      lastEngagementTime: 0,
      playbackPosition: position,
      duration: duration,
      intentUri: 'intent:',
      posterArtUri: art,
    );

Finder cardOf(int id) => find.byWidgetPredicate((w) => w is VitrineContinueCard && w.program.id == id);

void main() {
  late MockAppsService apps;
  late MockWatchNextService watchNext;
  late MockSettingsService settings;

  setUp(() {
    apps = MockAppsService();
    watchNext = MockWatchNextService();
    settings = MockSettingsService();
    when(apps.cachedBanner(any)).thenReturn(null);
    when(apps.cachedIcon(any)).thenReturn(null);
    when(apps.applications).thenReturn([]);
    when(watchNext.launch(any)).thenAnswer((_) async => true);
  });

  void screen(WidgetTester tester) {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(1920, 1080);
    addTearDown(tester.view.reset);
  }

  /// [child] at x 100, y 386 of the TV's 960x540 canvas, 860 wide, as the home puts the row.
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Brightness brightness = Brightness.dark,
    String language = 'pt',
    VitrineLogos? logos,
  }) async {
    screen(tester);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppsService>.value(value: apps),
          ChangeNotifierProvider<WatchNextService>.value(value: watchNext),
          ChangeNotifierProvider<SettingsService>.value(value: settings),
          if (logos != null) ChangeNotifierProvider<VitrineLogos>.value(value: logos),
        ],
        child: VitrineTheme(
          tokens: VitrineTokens.of(CinematicPalette.devBertini, brightness),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Localizations(
              locale: Locale(language),
              delegates: const [DefaultWidgetsLocalizations.delegate, _AnyLocaleMaterial()],
              child: Scaffold(
                body: Stack(
                  children: [
                    Positioned(
                      left: 100,
                      top: 386,
                      child: SizedBox(width: 860, child: Align(alignment: Alignment.topLeft, child: child)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget oneCard(WatchNextProgram p, {FocusNode? node, VoidCallback? onLeft}) => UnconstrainedBox(
        alignment: Alignment.topLeft,
        child: VitrineContinueCard(program: p, focusNode: node, onLeftEdge: onLeft),
      );

  Finder inCard(int id, Finder what) => find.descendant(of: cardOf(id), matching: what);

  group('the card', () {
    testWidgets('is 180x93 with a radius of 10, and the title, the time left and the bar sit where the spec says',
        (tester) async {
      await pump(tester, oneCard(program(position: 20 * _min, duration: 90 * _min)));
      final card = tester.getRect(cardOf(1));
      expect(card.size, const Size(180, 93));
      expect(card.topLeft, const Offset(100, 386));
      final clip = tester.widget<ClipRRect>(inCard(1, find.byType(ClipRRect)));
      expect(clip.borderRadius, BorderRadius.circular(10));

      final title = tester.getRect(find.text('House of the Dragon'));
      expect(title.left, card.left + 9);
      expect(title.bottom, card.bottom - 23);
      expect(title.height, 16);
      final titleStyle = tester.widget<Text>(find.text('House of the Dragon')).style!;
      expect(titleStyle.fontSize, 13);
      expect(titleStyle.fontWeight, FontWeight.w600);
      expect(titleStyle.color, const Color(0xFFFFFFFF));
      expect(titleStyle.fontFamily, vitrineFont);

      final left = tester.getRect(find.text('70 min restantes'));
      expect(left.left, card.left + 9);
      expect(left.bottom, card.bottom - 9);
      expect(tester.widget<Text>(find.text('70 min restantes')).style!.fontSize, 12);

      final fill = tester.getRect(inCard(1, find.byType(FractionallySizedBox)));
      expect(fill.height, 2);
      expect(fill.left, card.left + 9);
      expect(fill.bottom, card.bottom - 5);
      expect(fill.width, closeTo(162 * 20 / 90, 0.01));
    });

    testWidgets('rounds the minutes left up and counts them in English', (tester) async {
      // 29 min 1 s left: 30.
      await pump(tester, oneCard(program(position: 60 * _min, duration: 89 * _min + 1000)), language: 'en');
      expect(find.text('30 min left'), findsOneWidget);
      // One second left: 1.
      await pump(tester, oneCard(program(position: 90 * _min - 1000, duration: 90 * _min)), language: 'en');
      expect(find.text('1 min left'), findsOneWidget);
    });

    testWidgets('has no bar and no minutes when the length is unknown', (tester) async {
      await pump(tester, oneCard(program(position: 5 * _min, duration: 0)));
      expect(find.text('House of the Dragon'), findsOneWidget);
      expect(find.textContaining('min'), findsNothing);
      expect(inCard(1, find.byType(FractionallySizedBox)), findsNothing);
    });

    testWidgets('has no minutes but a full bar when nothing is left, and the bar never passes full', (tester) async {
      await pump(tester, oneCard(program(position: 120 * _min, duration: 90 * _min)));
      expect(find.textContaining('min'), findsNothing);
      expect(tester.getSize(inCard(1, find.byType(FractionallySizedBox))).width, 162);
    });

    testWidgets('cuts a long title with an ellipsis inside its 162 px', (tester) async {
      await pump(tester, oneCard(program(title: 'A very long episode title that does not fit the card at all')));
      final text = tester.widget<Text>(find.textContaining('A very long'));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(tester.getSize(find.textContaining('A very long')).width, lessThanOrEqualTo(162));
    });

    testWidgets('draws the same in both themes: white text, dark base, the scrim', (tester) async {
      for (final brightness in Brightness.values) {
        await pump(tester, oneCard(program()), brightness: brightness);
        expect(tester.widget<Text>(find.text('House of the Dragon')).style!.color, const Color(0xFFFFFFFF));
        expect(tester.widget<Text>(find.text('70 min restantes')).style!.color, const Color(0xFFE3E6EB));
        final base = tester.widget<ColoredBox>(inCard(1, find.byType(ColoredBox)).first);
        expect(base.color, const Color(0xFF1A1D22));
        final scrims = tester
            .widgetList<DecoratedBox>(inCard(1, find.byType(DecoratedBox)))
            .where((d) => (d.decoration is BoxDecoration) && (d.decoration as BoxDecoration).gradient != null);
        expect(scrims, hasLength(1));
        final gradient = (scrims.single.decoration as BoxDecoration).gradient! as LinearGradient;
        expect(gradient.colors.last, const Color(0xE0000000));
        expect(gradient.stops, [0.0, 0.34, 0.52, 1.0]);
      }
    });

    testWidgets('draws the service logo 15 px tall at the top right, on its black variant in both themes',
        (tester) async {
      final dir = Directory.systemTemp.createTempSync('vitrine_continue_');
      addTearDown(() => dir.deleteSync(recursive: true));
      File('${dir.path}/logo_black_com.wbd.stream.png').writeAsBytesSync(_png);
      File('${dir.path}/logo_light_com.wbd.stream.png').writeAsBytesSync([..._png, 0]);
      final logos = VitrineLogos(directory: () async => dir);
      await tester.runAsync(logos.load);
      for (final brightness in Brightness.values) {
        await pump(tester, oneCard(program()), brightness: brightness, logos: logos);
        final card = tester.getRect(cardOf(1));
        final logo = find.descendant(of: cardOf(1), matching: find.byType(VitrineLogo));
        final rect = tester.getRect(logo);
        expect(rect.height, 15);
        expect(rect.right, card.right - 8);
        expect(rect.top, card.top + 7);
        final image = tester.widget<Image>(find.descendant(of: logo, matching: find.byType(Image)));
        final bytes = ((image.image as ResizeImage).imageProvider as MemoryImage).bytes;
        expect(bytes.length, _png.length, reason: 'the black variant, on the light theme too');
      }
    });

    testWidgets('draws the program art decoded 360 wide in its own proportions, the app banner when it has no web address', (tester) async {
      await pump(tester, oneCard(program(art: 'https://example.com/art.jpg')));
      var image = tester.widget<Image>(inCard(1, find.byType(Image)).first);
      var resized = image.image as ResizeImage;
      expect(resized.imageProvider, isA<NetworkImage>());
      expect((resized.imageProvider as NetworkImage).url, 'https://example.com/art.jpg');
      expect(resized.width, 360);
      expect(resized.height, isNull);
      expect(image.fit, BoxFit.cover);

      final banner = Uint8List.fromList(_png);
      when(apps.cachedBanner('com.wbd.stream')).thenReturn(banner);
      await pump(tester, oneCard(program(art: 'content://provider/art/1')));
      image = tester.widget<Image>(inCard(1, find.byType(Image)).first);
      resized = image.image as ResizeImage;
      expect(resized.imageProvider, isA<MemoryImage>());
      expect((resized.imageProvider as MemoryImage).bytes, same(banner));
      expect(resized.width, 360);
      expect(resized.height, isNull);
    });

    testWidgets('falls back to the banner when the web art fails to load', (tester) async {
      final banner = Uint8List.fromList(_png);
      when(apps.cachedBanner('com.wbd.stream')).thenReturn(banner);
      await pump(tester, oneCard(program(art: 'https://example.com/art.jpg')));
      // flutter_test answers every HTTP request with an error.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
      final images = tester.widgetList<Image>(inCard(1, find.byType(Image))).toList();
      expect(images.any((i) => (i.image as ResizeImage).imageProvider is MemoryImage), isTrue);
    });

    testWidgets('draws no image at all without art, banner or logo, only the base colour', (tester) async {
      await pump(tester, oneCard(program()));
      expect(inCard(1, find.byType(Image)), findsNothing);
      expect(find.text('House of the Dragon'), findsOneWidget);
    });

    testWidgets('has a semantic label with the title and the time left', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, oneCard(program()));
      expect(find.bySemanticsLabel('House of the Dragon, 70 min restantes'), findsOneWidget);
      handle.dispose();
    });
  });

  group('the focus', () {
    testWidgets('puts the accent ring and the 1.06 scale on the card that has it, in both themes', (tester) async {
      for (final brightness in Brightness.values) {
        final node = FocusNode();
        addTearDown(node.dispose);
        await pump(tester, oneCard(program(), node: node), brightness: brightness);
        final tokens = VitrineTokens.of(CinematicPalette.devBertini, brightness);
        final frame = inCard(1, find.byType(VitrineFocusFrame));
        expect(tester.widget<VitrineFocusFrame>(frame).focused, isFalse);
        expect(tester.widget<VitrineFocusFrame>(frame).radius, 10);
        expect(tester.widget<VitrineFocusFrame>(frame).scale, 1.06);
        expect(tester.widget<AnimatedScale>(inCard(1, find.byType(AnimatedScale))).scale, 1);

        node.requestFocus();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.widget<VitrineFocusFrame>(frame).focused, isTrue);
        expect(tester.widget<AnimatedScale>(inCard(1, find.byType(AnimatedScale))).scale, 1.06);
        final rings = tester
            .widgetList<DecoratedBox>(inCard(1, find.byType(DecoratedBox)))
            .where((d) => d.decoration is BoxDecoration && (d.decoration as BoxDecoration).border != null);
        expect(rings, hasLength(1));
        final border = (rings.single.decoration as BoxDecoration).border! as Border;
        expect(border.top.color, tokens.accent);
        expect(border.top.width, 3);

        node.unfocus();
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.widget<VitrineFocusFrame>(frame).focused, isFalse);
      }
    });
  });

  group('the remote', () {
    testWidgets('OK, from any validation key, resumes the program', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      final p = program();
      await pump(tester, oneCard(p, node: node));
      node.requestFocus();
      await tester.pump();
      for (final key in [LogicalKeyboardKey.select, LogicalKeyboardKey.enter, LogicalKeyboardKey.gameButtonA]) {
        await tester.sendKeyEvent(key);
        verify(watchNext.launch(p)).called(1);
        expect(devBertiniLaunching.value, isTrue);
        devBertiniLaunching.value = false;
      }
      expect(find.byType(WatchNextInfoPanel), findsNothing);
      // devBertiniStartLaunch lifts the fade after 4 s.
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('holding OK for 500 ms opens the options and does not resume', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await pump(tester, oneCard(program(), node: node));
      node.requestFocus();
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(WatchNextInfoPanel), findsNothing);
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(find.byType(WatchNextInfoPanel), findsOneWidget);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
      await tester.pump(const Duration(milliseconds: 400));
      verifyNever(watchNext.launch(any));
      expect(devBertiniLaunching.value, isFalse);
    });

    testWidgets('a short press resumes on release and never opens the options', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      final p = program();
      await pump(tester, oneCard(p, node: node));
      node.requestFocus();
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
      await tester.pump(const Duration(milliseconds: 200));
      verifyNever(watchNext.launch(any));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
      verify(watchNext.launch(p)).called(1);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(WatchNextInfoPanel), findsNothing);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a release that never had its press here (a dialog closed on it) resumes nothing', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await pump(tester, oneCard(program(), node: node));
      node.requestFocus();
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
      verifyNever(watchNext.launch(any));
    });

    testWidgets('moving the focus away in the middle of a press drops it', (tester) async {
      final a = FocusNode(), b = FocusNode();
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      await pump(
        tester,
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            VitrineContinueCard(program: program(id: 1), focusNode: a),
            VitrineContinueCard(program: program(id: 2), focusNode: b),
          ],
        ),
      );
      a.requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
      b.requestFocus();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(WatchNextInfoPanel), findsNothing);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
      verifyNever(watchNext.launch(any));
    });

    testWidgets('Left calls back when the card is the row first, and does nothing without a callback', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      var calls = 0;
      await pump(tester, oneCard(program(), node: node, onLeft: () => calls++));
      node.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      expect(calls, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(calls, 1);

      await pump(tester, oneCard(program(), node: node));
      node.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      expect(calls, 1);
      expect(node.hasFocus, isTrue);
    });
  });

  group('the row', () {
    List<WatchNextProgram> programs(int n) => [for (var i = 1; i <= n; i++) program(id: i, title: 'Program $i')];

    testWidgets('takes no space at all without programs', (tester) async {
      await pump(tester, const VitrineContinueRow(programs: []));
      expect(tester.getSize(find.byType(VitrineContinueRow)), Size.zero);
      expect(find.text('Continuar assistindo'), findsNothing);
      expect(find.byType(VitrineContinueCard), findsNothing);
    });

    testWidgets('puts the label at y 386 and the cards at y 411, 12 px apart, in both languages and themes',
        (tester) async {
      for (final brightness in Brightness.values) {
        await pump(tester, VitrineContinueRow(programs: programs(3)), brightness: brightness);
        final ink = VitrineTokens.of(CinematicPalette.devBertini, brightness).ink;
        final row = tester.getRect(find.byType(VitrineContinueRow));
        expect(row.topLeft, const Offset(100, 386));
        expect(row.height, 17 + 8 + 93);
        final label = find.text('Continuar assistindo');
        expect(tester.getTopLeft(label), const Offset(100, 386));
        expect(tester.getSize(label).height, 17);
        final style = tester.widget<Text>(label).style!;
        expect(style.fontSize, 14);
        expect(style.fontWeight, FontWeight.w600);
        expect(style.color, ink);
        expect(style.fontFamily, vitrineFont);

        final first = tester.getRect(cardOf(1));
        final second = tester.getRect(cardOf(2));
        final third = tester.getRect(cardOf(3));
        expect(first.topLeft, const Offset(100, 411));
        expect(first.size, const Size(180, 93));
        expect(second.left - first.right, 12);
        expect(third.left - second.right, 12);
        expect(second.top, 411);
      }
      await pump(tester, VitrineContinueRow(programs: programs(2)), language: 'en');
      expect(find.text('Continue watching'), findsOneWidget);
    });

    testWidgets('shows four whole cards and the fifth peeking 90 px at the screen edge, and builds only what it needs',
        (tester) async {
      await pump(tester, VitrineContinueRow(programs: programs(40)));
      final fifth = tester.getRect(cardOf(5));
      // The row runs from x 100 to the screen's right edge, 960.
      expect(fifth.left, 100 + 4 * 192);
      expect(960 - fifth.left, 92);
      expect(tester.getRect(cardOf(4)).right, lessThan(960 - 92));
      expect(find.byType(VitrineContinueCard).evaluate().length, lessThan(15));
    });

    testWidgets('the first card takes the given node and calls back on Left; the others do not', (tester) async {
      final first = FocusNode();
      addTearDown(first.dispose);
      var calls = 0;
      await pump(tester, VitrineContinueRow(programs: programs(3), firstFocusNode: first, onLeftFromFirst: () => calls++));
      first.requestFocus();
      await tester.pump();
      expect(tester.widget<VitrineContinueCard>(cardOf(1)).focusNode, same(first));
      expect(tester.widget<VitrineContinueCard>(cardOf(2)).focusNode, isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(tester.widget<VitrineFocusFrame>(inCard(2, find.byType(VitrineFocusFrame))).focused, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(calls, 0, reason: 'Left on the second card goes back to the first');
      expect(first.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      expect(calls, 1);
    });

    testWidgets('scrolls only as far as needed to keep the focused card in view with the next one peeking',
        (tester) async {
      final first = FocusNode();
      addTearDown(first.dispose);
      await pump(tester, VitrineContinueRow(programs: programs(8), firstFocusNode: first));
      first.requestFocus();
      await tester.pumpAndSettle();
      // Cards 1 to 4 fit: moving along them scrolls nothing.
      for (var i = 0; i < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
      }
      expect(tester.getRect(cardOf(1)).left, 100);
      expect(tester.getRect(cardOf(4)).left, 100 + 3 * 192);

      // The fifth: the row scrolls until the sixth peeks about 90 px inside the screen's edge.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      final fifth = tester.getRect(cardOf(5));
      final sixth = tester.getRect(cardOf(6));
      expect(tester.widget<VitrineFocusFrame>(inCard(5, find.byType(VitrineFocusFrame))).focused, isTrue);
      expect(fifth.right, lessThan(960 - 90));
      expect(960 - sixth.left, closeTo(90, 1));
      expect(fifth.left, greaterThan(100));
      expect(tester.getRect(cardOf(1)).left, lessThan(100));

      // Back to the first: the row is where it started.
      for (var i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
      }
      expect(tester.getRect(cardOf(1)).left, 100);

      // The last card: the row stops at its end, nothing to peek.
      for (var i = 0; i < 7; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
      }
      expect(tester.widget<VitrineFocusFrame>(inCard(8, find.byType(VitrineFocusFrame))).focused, isTrue);
      final last = tester.getRect(cardOf(8));
      expect(last.right, lessThanOrEqualTo(960));
      expect(last.right, greaterThan(960 - 12 - 1));
    });

    testWidgets('keeps the first card focus ring inside what the row paints', (tester) async {
      final first = FocusNode();
      addTearDown(first.dispose);
      await pump(tester, VitrineContinueRow(programs: programs(3), firstFocusNode: first));
      first.requestFocus();
      await tester.pumpAndSettle();
      final clip = tester.widget<ClipRect>(find.byWidgetPredicate((w) => w is ClipRect && w.clipper != null));
      final rect = clip.clipper!.getClip(const Size(860, 93));
      // The ring (3 px) and the 1.06 scale (2.7 px) reach 6 px past the first card on the left and above.
      expect(rect.left, lessThanOrEqualTo(-6));
      expect(rect.top, lessThanOrEqualTo(-6));
      expect(rect.right, 860);
    });

    testWidgets('holds each card in its own repaint layer and draws no blur or opacity layer', (tester) async {
      await pump(tester, VitrineContinueRow(programs: programs(5)));
      expect(find.descendant(of: find.byType(VitrineContinueRow), matching: find.byType(BackdropFilter)), findsNothing);
      expect(find.descendant(of: find.byType(VitrineContinueRow), matching: find.byType(Opacity)), findsNothing);
      expect(find.descendant(of: find.byType(VitrineContinueRow), matching: find.byType(ShaderMask)), findsNothing);
      for (var i = 1; i <= 5; i++) {
        expect(inCard(i, find.byType(RepaintBoundary)), findsWidgets);
      }
    });
  });
}
