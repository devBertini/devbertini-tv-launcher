import 'dart:io';
import 'dart:ui' as ui;

import 'package:flauncher/devbertini/brand.dart';
import 'package:flauncher/devbertini/cinematic.dart';
import 'package:flauncher/devbertini/tv_extras.dart';
import 'package:flauncher/devbertini/vitrine/clock.dart';
import 'package:flauncher/devbertini/vitrine/field.dart';
import 'package:flauncher/devbertini/vitrine/focus.dart';
import 'package:flauncher/devbertini/vitrine/hero.dart';
import 'package:flauncher/devbertini/vitrine/logos.dart';
import 'package:flauncher/devbertini/vitrine/tokens.dart';
import 'package:flauncher/models/app.dart';
import 'package:flauncher/models/watch_next_program.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/watch_next_service.dart';
import 'package:flauncher/widgets/watch_next_info_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

// A 1x1 white PNG, enough for the art and the logos to be decoded and drawn.
final Uint8List _png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00,
  0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0D, 0x49,
  0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xFF, 0xFF, 0xFF, 0x7F, 0x00, 0x09, 0xFB, 0x03, 0xFD, 0x2A, 0x86, 0xE3,
  0x8A, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class _Apps extends ChangeNotifier implements AppsService {
  final Map<String, Uint8List> banners = {};
  final List<App> list = [];

  @override
  Uint8List? cachedBanner(String packageName) => banners[packageName];

  @override
  Uint8List? cachedIcon(String packageName) => null;

  @override
  App? getApp(String packageName) => list.where((a) => a.packageName == packageName).firstOrNull;

  @override
  List<App> get applications => list;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Watch extends ChangeNotifier implements WatchNextService {
  final List<WatchNextProgram> launched = [];

  @override
  Future<bool> launch(WatchNextProgram program) async {
    launched.add(program);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Settings extends ChangeNotifier implements SettingsService {
  String format = 'H:mm';

  @override
  String get timeFormat => format;

  @override
  String get themes => devBertiniTheme;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Weather extends ChangeNotifier implements OpenMeteoService {
  WeatherNow? value;

  void set(WeatherNow? next) {
    value = next;
    notifyListeners();
  }

  @override
  WeatherNow? now([DateTime? clock]) => value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sleep extends ChangeNotifier implements SleepTimerService {
  DateTime? when;

  @override
  DateTime? get at => when;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

WatchNextProgram _program({
  int id = 1,
  String package = 'com.wbd.stream',
  String title = 'The Penguin',
  String description = 'Oz Cobb takes the void left by the death of Falcone to rule the Gotham underworld.',
  int position = 0,
  int duration = 0,
  String art = '',
}) =>
    WatchNextProgram(
      id: id,
      packageName: package,
      title: title,
      description: description,
      watchNextType: 0,
      lastEngagementTime: 0,
      playbackPosition: position,
      duration: duration,
      intentUri: 'intent:#Intent;end',
      posterArtUri: art,
    );

const int _minute = Duration.millisecondsPerMinute;
const Key _shot = ValueKey('shot');

/// The 960x540 canvas at the TV's device pixel ratio 2, with the app's services above it and the dialogs' navigator.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  VitrineTokens? tokens,
  Locale locale = const Locale('pt', 'BR'),
  _Apps? apps,
  _Watch? watch,
  _Settings? settings,
  _Weather? weather,
  _Sleep? sleep,
  VitrineLogos? logos,
  double dpr = 2,
}) async {
  tester.view.physicalSize = Size(960 * dpr, 540 * dpr);
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        if (apps != null) ChangeNotifierProvider<AppsService>.value(value: apps),
        if (watch != null) ChangeNotifierProvider<WatchNextService>.value(value: watch),
        ChangeNotifierProvider<SettingsService>.value(value: settings ?? _Settings()),
        if (weather != null) ChangeNotifierProvider<OpenMeteoService>.value(value: weather),
        if (sleep != null) ChangeNotifierProvider<SleepTimerService>.value(value: sleep),
        if (logos != null) ChangeNotifierProvider<VitrineLogos>.value(value: logos),
      ],
      child: VitrineTheme(
        tokens: tokens ?? VitrineTokens.dark(CinematicPalette.devBertini),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: locale,
          supportedLocales: const [Locale('pt', 'BR'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: RepaintBoundary(key: _shot, child: ColoredBox(color: const Color(0xFFFF0000), child: child)),
        ),
      ),
    ),
  );
}

/// Lets the images decode (a real asynchronous job), then plays the 300 ms cross-fade out.
Future<void> _settleImages(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// The 960x540 canvas as pixels (RGBA, 960 per row), as drawn.
Future<ByteData> _pixels(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_shot));
  final ui.Image image = (await tester.runAsync(() => boundary.toImage()))!;
  expect(image.width, 960);
  expect(image.height, 540);
  return (await tester.runAsync(() => image.toByteData()))!;
}

List<int> _rgb(ByteData px, int x, int y) {
  final i = (y * 960 + x) * 4;
  return [px.getUint8(i), px.getUint8(i + 1), px.getUint8(i + 2)];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    await initializeDateFormatting('en');
  });

  setUp(() => devBertiniLaunching.value = false);

  final dark = VitrineTokens.dark(CinematicPalette.devBertini);
  final light = VitrineTokens.light(CinematicPalette.devBertini);

  group('VitrineField', () {
    Finder pictures() => find.descendant(of: find.byType(VitrineField), matching: find.byType(RawImage));
    List<int> rgb(Color c) => [(c.toARGB32() >> 16) & 0xFF, (c.toARGB32() >> 8) & 0xFF, c.toARGB32() & 0xFF];
    void near(List<int> got, Color want, String reason) {
      for (var i = 0; i < 3; i++) {
        expect(got[i], closeTo(rgb(want)[i], 2), reason: '$reason (dithered)');
      }
    }

    testWidgets('light: the gradient painted once into one picture of the screen, the child over it', (tester) async {
      const spot = SizedBox(width: 10, height: 10, child: ColoredBox(color: Color(0xFF00FF00)));
      await _pump(tester, const VitrineField(child: Align(alignment: Alignment.topLeft, child: spot)), tokens: light);
      expect(pictures(), findsOneWidget);
      final image = tester.widget<RawImage>(pictures()).image!;
      expect([image.width, image.height], [1920, 1080]);
      final px = await _pixels(tester);
      near(_rgb(px, 300, 0), light.fieldTop, 'top');
      near(_rgb(px, 300, 243), light.field, 'at 45%');
      near(_rgb(px, 300, 539), light.fieldBottom, 'bottom');
      expect(_rgb(px, 5, 5), [0, 255, 0], reason: 'the child over the field');
    });

    testWidgets('dark: a plain black fill, no picture', (tester) async {
      await _pump(tester, const VitrineField(), tokens: dark);
      expect(pictures(), findsNothing);
      expect(_rgb(await _pixels(tester), 300, 100), [0, 0, 0]);
    });

    testWidgets('a new theme paints a new picture', (tester) async {
      await _pump(tester, const VitrineField(), tokens: light);
      final first = tester.widget<RawImage>(pictures()).image;
      await _pump(tester, const VitrineField(), tokens: VitrineTokens.light(CinematicPalette.aurora));
      expect(tester.widget<RawImage>(pictures()).image, isNot(same(first)));
      await _pump(tester, const VitrineField(), tokens: dark);
      expect(pictures(), findsNothing);
    });
  });

  group('VitrineBackdrop', () {
    Finder pictures() => find.descendant(of: find.byType(VitrineBackdrop), matching: find.byType(RawImage));

    /// The art the backdrop reads, from its private stateful part.
    ImageProvider? artOf(WidgetTester tester) =>
        (tester.widget(find.byWidgetPredicate((w) => '${w.runtimeType}' == '_Backdrop')) as dynamic).image
            as ImageProvider?;

    testWidgets('reads the banner decoded at 1580 px, 790 times the device pixel ratio', (tester) async {
      final apps = _Apps()..banners['com.wbd.stream'] = _png;
      await _pump(tester, SizedBox.expand(child: VitrineBackdrop(program: _program())), apps: apps);
      final art = artOf(tester) as ResizeImage;
      expect(art.width, 1580);
      expect(art.imageProvider, isA<MemoryImage>());
      await _pump(tester, SizedBox.expand(child: VitrineBackdrop(program: _program())), apps: apps, dpr: 1);
      expect((artOf(tester) as ResizeImage).width, 790);
    });

    testWidgets('a program whose app gives a web address reads it, under a ResizeImage', (tester) async {
      await _pump(tester, SizedBox.expand(child: VitrineBackdrop(program: _program(art: 'https://example.com/p.jpg'))),
          apps: _Apps());
      final art = artOf(tester) as ResizeImage;
      expect(art.width, 1580);
      expect((art.imageProvider as NetworkImage).url, 'https://example.com/p.jpg');
    });

    testWidgets('a program with no art (no web address, no banner) or no AppsService draws only the field',
        (tester) async {
      await _pump(tester, SizedBox.expand(child: VitrineBackdrop(program: _program(art: 'content://x/1'))),
          apps: _Apps());
      await _settleImages(tester);
      expect(artOf(tester), isNull);
      expect(pictures(), findsNothing);
      await _pump(tester, SizedBox.expand(child: VitrineBackdrop(program: _program())));
      await _settleImages(tester);
      expect(pictures(), findsNothing);
      expect(_rgb(await _pixels(tester), 640, 100), [255, 0, 0], reason: 'dark: nothing drawn over the black surface');
    });

    testWidgets('dark: field, art and fades come out as the live layers paint them, as one picture of the screen',
        (tester) async {
      final apps = _Apps()..banners['com.wbd.stream'] = _png;
      await _pump(tester, SizedBox.expand(child: VitrineBackdrop(program: _program())), apps: apps, tokens: dark);
      await _settleImages(tester);
      expect(pictures(), findsOneWidget);
      final image = tester.widget<RawImage>(pictures()).image!;
      expect([image.width, image.height], [1920, 1080], reason: 'the screen at the device pixel ratio');
      expect(find.descendant(of: find.byType(VitrineBackdrop), matching: find.byType(Image)), findsNothing);
      expect(find.descendant(of: find.byType(VitrineBackdrop), matching: find.byType(CustomPaint)), findsNothing);
      final px = await _pixels(tester);
      expect(_rgb(px, 300, 100), [0, 0, 0], reason: 'left fade is solid up to x 380');
      expect(_rgb(px, 100, 100), [0, 0, 0], reason: 'left of the art, the field');
      for (final c in _rgb(px, 640, 100)) {
        expect(c, greaterThan(250), reason: 'art fully visible between the fades');
      }
      expect(_rgb(px, 640, 400), [0, 0, 0], reason: 'down fade is solid from y 361');
      expect(_rgb(px, 640, 263)[0], inInclusiveRange(140, 175), reason: '42 of 85 px into the down fade');
      expect(_rgb(px, 950, 100)[0], lessThan(30), reason: 'right scrim 0.94 at the edge');
      expect(_rgb(px, 640, 430), [0, 0, 0], reason: 'below the art, the black field');
    });

    testWidgets('light: the fades in the light colours over the light field', (tester) async {
      final apps = _Apps()..banners['com.wbd.stream'] = _png;
      await _pump(tester, SizedBox.expand(child: VitrineBackdrop(program: _program())), apps: apps, tokens: light);
      await _settleImages(tester);
      final px = await _pixels(tester);
      int channel(Color c, int shift) => (c.toARGB32() >> shift) & 0xFF;
      List<int> rgb(Color c) => [channel(c, 16), channel(c, 8), channel(c, 0)];
      expect(_rgb(px, 300, 100), rgb(light.heroFadeSide));
      expect(_rgb(px, 640, 400), rgb(light.heroFadeDown));
      for (final c in _rgb(px, 640, 100)) {
        expect(c, greaterThan(250));
      }
      final bottom = _rgb(px, 640, 539), field = rgb(light.fieldBottom);
      for (var i = 0; i < 3; i++) {
        expect(bottom[i], closeTo(field[i], 2), reason: 'the field to the bottom of the screen (dithered)');
      }
    });

    testWidgets('Modo noite darkens the art by the night dim, inside the art box only', (tester) async {
      final apps = _Apps()..banners['com.wbd.stream'] = _png;
      await _pump(tester, SizedBox.expand(child: VitrineBackdrop(program: _program(), night: true)), apps: apps,
          tokens: dark);
      await _settleImages(tester);
      final px = await _pixels(tester);
      expect(_rgb(px, 640, 100)[0], inInclusiveRange(160, 170), reason: '255 at 65%');
      expect(_rgb(px, 640, 430), [0, 0, 0]);
    });

    testWidgets('no program: nothing painted on the dark field, the field alone on the light one', (tester) async {
      await _pump(tester, const SizedBox.expand(child: VitrineBackdrop(program: null)), apps: _Apps(), tokens: dark);
      await _settleImages(tester);
      expect(pictures(), findsNothing);
      expect(_rgb(await _pixels(tester), 300, 100), [255, 0, 0], reason: 'the black surface shows: nothing drawn');

      await _pump(tester, const SizedBox.expand(child: VitrineBackdrop(program: null)), apps: _Apps(), tokens: light);
      await _settleImages(tester);
      final px = await _pixels(tester);
      int channel(Color c, int shift) => (c.toARGB32() >> shift) & 0xFF;
      expect(_rgb(px, 300, 0)[0], closeTo(channel(light.fieldTop, 16), 2), reason: 'the live field (dithered)');
    });

    testWidgets('a web picture that does not load falls back to the app banner', (tester) async {
      final apps = _Apps()..banners['com.wbd.stream'] = _png;
      await _pump(tester, SizedBox.expand(child: VitrineBackdrop(program: _program(art: 'https://example.com/a.jpg'))),
          apps: apps, tokens: dark);
      await _settleImages(tester);
      await _settleImages(tester);
      expect(pictures(), findsOneWidget);
      for (final c in _rgb(await _pixels(tester), 640, 100)) {
        expect(c, greaterThan(250), reason: 'the banner is the art');
      }
    });

    testWidgets('a new art cross-fades once, for 300 ms; a new theme swaps the picture at once', (tester) async {
      final apps = _Apps()
        ..banners['com.wbd.stream'] = _png
        ..banners['com.netflix.ninja'] = _png;
      Widget backdrop(WatchNextProgram p) => SizedBox.expand(child: VitrineBackdrop(program: p));
      await _pump(tester, backdrop(_program()), apps: apps, tokens: dark);
      await _settleImages(tester);
      expect(pictures(), findsOneWidget);

      await _pump(tester, backdrop(_program(id: 2, package: 'com.netflix.ninja')), apps: apps, tokens: dark);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(pictures(), findsNWidgets(2), reason: 'old and new while they cross-fade');
      await tester.pump(const Duration(milliseconds: 250));
      expect(pictures(), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);

      final before = tester.widget<RawImage>(pictures()).image;
      await _pump(tester, backdrop(_program(id: 2, package: 'com.netflix.ninja')), apps: apps, tokens: light);
      await tester.pump();
      expect(pictures(), findsOneWidget, reason: 'no cross-fade for a theme');
      expect(tester.widget<RawImage>(pictures()).image, isNot(same(before)));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('the same art for a new program keeps its picture', (tester) async {
      final apps = _Apps()..banners['com.wbd.stream'] = _png;
      Widget backdrop(WatchNextProgram p) => SizedBox.expand(child: VitrineBackdrop(program: p));
      await _pump(tester, backdrop(_program()), apps: apps);
      await _settleImages(tester);
      final before = tester.widget<RawImage>(pictures()).image;
      await _pump(tester, backdrop(_program(id: 2, title: 'Other')), apps: apps);
      await tester.pump(const Duration(milliseconds: 50));
      expect(pictures(), findsOneWidget);
      expect(tester.widget<RawImage>(pictures()).image, same(before));
    });

    testWidgets('lives in its own layer and takes no input', (tester) async {
      final apps = _Apps()..banners['com.wbd.stream'] = _png;
      await _pump(tester, SizedBox.expand(child: VitrineBackdrop(program: _program())), apps: apps);
      expect(find.descendant(of: find.byType(VitrineBackdrop), matching: find.byType(RepaintBoundary)), findsWidgets);
      expect(find.descendant(of: find.byType(VitrineBackdrop), matching: find.byType(IgnorePointer)), findsWidgets);
    });
  });

  group('VitrineHeroInfo', () {
    final long = 'Oz Cobb takes the void left by the death of Falcone to rule the Gotham underworld, and nothing '
        'stands in his way, not even the family that made him.';

    Rect rectOf(WidgetTester tester, Finder f) => tester.getRect(f);

    testWidgets('lays out as the spec: logo 19, title 28/32, bar 72x3 and minutes, two-line synopsis, capsules 26',
        (tester) async {
      final dir = Directory.systemTemp.createTempSync('vitrine_hero_');
      final file = File('${dir.path}/logo_black_com.wbd.stream.png')..writeAsBytesSync(_png);
      addTearDown(() {
        file.deleteSync();
        dir.deleteSync();
      });
      final logos = VitrineLogos(directory: () async => dir);
      await tester.runAsync(logos.load);
      final program = _program(description: long, position: 50 * _minute, duration: 90 * _minute);
      await _pump(
        tester,
        Align(alignment: Alignment.topLeft, child: VitrineHeroInfo(program: program)),
        apps: _Apps(),
        watch: _Watch(),
        logos: logos,
      );
      final block = rectOf(tester, find.byType(VitrineHeroInfo));
      expect(block, const Rect.fromLTWH(0, 0, 300, 149), reason: '19 + 5 + 32 + 5 + 15 + 5 + 32 + 10 + 26');
      final logo = rectOf(tester, find.byType(Image));
      expect(logo.top, 0);
      expect(logo.left, 0);
      expect(logo.height, 19);
      final title = rectOf(tester, find.text('The Penguin'));
      expect(title.top, 24);
      expect(title.height, 32);
      final style = tester.widget<Text>(find.text('The Penguin')).style!;
      expect((style.fontSize, style.fontWeight, style.letterSpacing), (28.0, FontWeight.w400, -0.6));
      final bar = rectOf(tester, find.byKey(const ValueKey('vitrine-hero-bar')));
      expect(bar.size, const Size(72, 3));
      expect(bar.left, 0);
      expect(bar.center.dy, closeTo(61 + 7.5, 0.01), reason: 'centred on the 15 px line of the minutes');
      final minutes = rectOf(tester, find.text('40 min restantes'));
      expect(minutes.left, 72 + 8);
      expect(minutes.top, 61);
      final synopsis = rectOf(tester, find.text(long));
      expect(synopsis.top, 81);
      expect(synopsis.height, 32, reason: 'two lines of 16 at most');
      expect(synopsis.width, lessThanOrEqualTo(285));
      expect(tester.widget<Text>(find.text(long)).maxLines, 2);
      expect(tester.widget<Text>(find.text(long)).overflow, TextOverflow.ellipsis);
      final play = rectOf(tester, find.ancestor(of: find.text('Continuar'), matching: find.byType(VitrineFocusFrame)));
      final info = rectOf(tester, find.ancestor(of: find.text('Detalhes'), matching: find.byType(VitrineFocusFrame)));
      expect(play.top, 123);
      expect(play.height, 26);
      expect(info.top, 123);
      expect(info.height, 26);
      expect(play.left, 0);
      expect(info.left, play.right + 7);
    });

    testWidgets('the capsule: 9 px, the 16 px icon, 4 px, the label, 13 px; radius 13, scale 1.05', (tester) async {
      await _pump(
        tester,
        Align(alignment: Alignment.topLeft, child: VitrineHeroInfo(program: _program())),
        apps: _Apps(),
        watch: _Watch(),
      );
      for (final label in ['Continuar', 'Detalhes']) {
        final frame = find.ancestor(of: find.text(label), matching: find.byType(VitrineFocusFrame));
        final capsule = tester.getRect(frame);
        final text = tester.getRect(find.text(label));
        final icon = tester.getRect(find.descendant(of: frame, matching: find.byType(Icon)));
        expect(icon.size, const Size(16, 16));
        expect(icon.left - capsule.left, 9, reason: label);
        expect(text.left - icon.right, 4, reason: label);
        expect(capsule.right - text.right, 13, reason: label);
        final widget = tester.widget<VitrineFocusFrame>(frame);
        expect((widget.radius, widget.scale), (13.0, 1.05));
        final face = tester.widget<Text>(find.text(label)).style!;
        expect((face.fontSize, face.fontWeight), (12.0, FontWeight.w600));
      }
    });

    testWidgets('minutes are rounded up, and the bar fills by position over duration', (tester) async {
      Future<void> show(int position, int duration) async {
        await _pump(
          tester,
          Align(
            alignment: Alignment.topLeft,
            child: VitrineHeroInfo(program: _program(position: position, duration: duration)),
          ),
          apps: _Apps(),
          watch: _Watch(),
        );
      }

      await show(50 * _minute, 90 * _minute);
      expect(find.text('40 min restantes'), findsOneWidget, reason: 'exactly 40 min left');
      final fill = find.descendant(
        of: find.byKey(const ValueKey('vitrine-hero-bar')),
        matching: find.byType(FractionallySizedBox),
      );
      expect(tester.getSize(fill).width, closeTo(72 * 50 / 90, 0.01));

      await show(50 * _minute - 1, 90 * _minute);
      expect(find.text('41 min restantes'), findsOneWidget, reason: '1 ms over 40 min rounds up');
      await show(0, 45 * _minute);
      expect(find.text('45 min restantes'), findsOneWidget);
      expect(tester.getSize(fill).width, 0);
      await show(89 * _minute + 59999, 90 * _minute);
      expect(find.text('1 min restantes'), findsOneWidget, reason: 'the last 1 ms is still a minute');
      await show(95 * _minute, 90 * _minute);
      expect(find.text('0 min restantes'), findsOneWidget, reason: 'a position past the end never goes negative');
      expect(tester.getSize(fill).width, 72);
    });

    testWidgets('no duration: no bar and no minutes, and the synopsis comes up', (tester) async {
      await _pump(
        tester,
        Align(alignment: Alignment.topLeft, child: VitrineHeroInfo(program: _program(description: long, duration: 0))),
        apps: _Apps(),
        watch: _Watch(),
      );
      expect(find.byKey(const ValueKey('vitrine-hero-bar')), findsNothing);
      expect(find.textContaining('min restantes'), findsNothing);
      expect(tester.getRect(find.text(long)).top, 61, reason: '19 + 5 + 32 + 5');
      expect(tester.getRect(find.byType(VitrineHeroInfo)).height, 19 + 5 + 32 + 5 + 32 + 10 + 26);
    });

    testWidgets('no synopsis: the capsules follow the minutes', (tester) async {
      await _pump(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: VitrineHeroInfo(program: _program(description: '', duration: 60 * _minute)),
        ),
        apps: _Apps(),
        watch: _Watch(),
      );
      final play = find.ancestor(of: find.text('Continuar'), matching: find.byType(VitrineFocusFrame));
      expect(tester.getRect(play).top, 19 + 5 + 32 + 5 + 15 + 10);
    });

    testWidgets('a synopsis that only repeats the title is left out, as no synopsis', (tester) async {
      await _pump(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: VitrineHeroInfo(
            program: _program(title: 'Felps - 346 |', description: ' felps - 346 | ', duration: 60 * _minute),
          ),
        ),
        apps: _Apps(),
        watch: _Watch(),
      );
      expect(find.text('Felps - 346 |'), findsOneWidget);
      final play = find.ancestor(of: find.text('Continuar'), matching: find.byType(VitrineFocusFrame));
      expect(tester.getRect(play).top, 19 + 5 + 32 + 5 + 15 + 10);
    });

    testWidgets('a long title keeps one line with an ellipsis, a short one is not cut', (tester) async {
      await _pump(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: VitrineHeroInfo(program: _program(title: 'A title that is far too long to fit on the screen at all')),
        ),
        apps: _Apps(),
        watch: _Watch(),
      );
      final text = tester.widget<Text>(find.textContaining('A title'));
      expect((text.maxLines, text.overflow), (1, TextOverflow.ellipsis));
      expect(tester.getRect(find.textContaining('A title')).height, 32);
      expect(tester.getRect(find.byType(VitrineHeroInfo)).width, 300, reason: 'the block stays 300 wide');
    });

    testWidgets('without the logo file the app name stands in, 19 px tall', (tester) async {
      final apps = _Apps()..list.add(App(packageName: 'com.wbd.stream', name: 'HBO Max', version: '1', hidden: false));
      await _pump(
        tester,
        Align(alignment: Alignment.topLeft, child: VitrineHeroInfo(program: _program())),
        apps: apps,
        watch: _Watch(),
      );
      expect(find.text('HBO Max'), findsOneWidget);
      expect(tester.getRect(find.text('HBO Max')).height, 19);
    });

    testWidgets('both themes: the capsules take the token colours; the quiet one has its edge on black',
        (tester) async {
      for (final t in [dark, light]) {
        await _pump(
          tester,
          Align(alignment: Alignment.topLeft, child: VitrineHeroInfo(program: _program())),
          apps: _Apps(),
          watch: _Watch(),
          tokens: t,
        );
        Color? fill(String label) {
          final frame = find.ancestor(of: find.text(label), matching: find.byType(VitrineFocusFrame));
          final boxes = tester.widgetList<DecoratedBox>(find.descendant(of: frame, matching: find.byType(DecoratedBox)));
          return boxes.map((b) => (b.decoration as BoxDecoration).color).whereType<Color>().first;
        }

        expect(fill('Continuar'), t.primary, reason: 'brightness ${t.brightness}');
        expect(fill('Detalhes'), t.quiet, reason: 'brightness ${t.brightness}');
        expect(tester.widget<Text>(find.text('Continuar')).style!.color, t.primaryInk);
        expect(tester.widget<Text>(find.text('Detalhes')).style!.color, t.ink);
        expect(tester.widget<Text>(find.text('The Penguin')).style!.color, t.ink);
        expect(tester.widget<Text>(find.text(_program().description)).style!.color, t.ink2);
        Border? edge(String label) {
          final frame = find.ancestor(of: find.text(label), matching: find.byType(VitrineFocusFrame));
          final foreground = tester
              .widgetList<DecoratedBox>(find.descendant(of: frame, matching: find.byType(DecoratedBox)))
              .where((b) => b.position == DecorationPosition.foreground)
              .map((b) => (b.decoration as BoxDecoration).border)
              .whereType<Border>()
              .toList();
          return foreground.isEmpty ? null : foreground.first;
        }

        expect(edge('Continuar')?.top.color, t.primaryEdge);
        expect(edge('Detalhes')?.top.color, t.quietEdge);
      }
    });

    testWidgets('the focus is the capsule\'s own: Right and Left move it, only that capsule shows the ring',
        (tester) async {
      final resume = FocusNode();
      addTearDown(resume.dispose);
      await _pump(
        tester,
        Align(alignment: Alignment.topLeft, child: VitrineHeroInfo(program: _program(), resumeFocusNode: resume)),
        apps: _Apps(),
        watch: _Watch(),
      );
      bool focused(String label) => tester
          .widget<VitrineFocusFrame>(find.ancestor(of: find.text(label), matching: find.byType(VitrineFocusFrame)))
          .focused;
      expect((focused('Continuar'), focused('Detalhes')), (false, false));
      resume.requestFocus();
      await tester.pump();
      expect(resume.hasPrimaryFocus, isTrue);
      expect((focused('Continuar'), focused('Detalhes')), (true, false));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect((focused('Continuar'), focused('Detalhes')), (false, true));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect((focused('Continuar'), focused('Detalhes')), (true, false));
    });

    testWidgets('OK on Continuar starts the launch fade and resumes the program, once per press', (tester) async {
      final resume = FocusNode();
      addTearDown(resume.dispose);
      final watch = _Watch();
      final program = _program();
      await _pump(
        tester,
        Align(alignment: Alignment.topLeft, child: VitrineHeroInfo(program: program, resumeFocusNode: resume)),
        apps: _Apps(),
        watch: watch,
      );
      resume.requestFocus();
      await tester.pump();
      for (final key in [LogicalKeyboardKey.select, LogicalKeyboardKey.enter, LogicalKeyboardKey.gameButtonA]) {
        devBertiniLaunching.value = false;
        watch.launched.clear();
        await tester.sendKeyEvent(key);
        await tester.pump(const Duration(seconds: 5)); // the launch fade lifts by itself after 4 s
        expect(watch.launched, [program], reason: '$key');
      }
      // A key held down repeats; the program is resumed once.
      watch.launched.clear();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
      await tester.pump(const Duration(seconds: 5));
      expect(watch.launched, hasLength(1));
      // Another key does nothing.
      watch.launched.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      expect(watch.launched, isEmpty);
    });

    testWidgets('OK on Continuar sets the launching flag before the program is launched', (tester) async {
      final resume = FocusNode();
      addTearDown(resume.dispose);
      final flagWhenLaunched = <bool>[];
      final watch = _Watch();
      final program = _program();
      await _pump(
        tester,
        Align(alignment: Alignment.topLeft, child: VitrineHeroInfo(program: program, resumeFocusNode: resume)),
        apps: _Apps(),
        watch: watch,
      );
      resume.requestFocus();
      await tester.pump();
      expect(devBertiniLaunching.value, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      flagWhenLaunched.add(devBertiniLaunching.value);
      expect(flagWhenLaunched, [true]);
      expect(watch.launched, [program]);
      await tester.pump(const Duration(seconds: 5));
      expect(devBertiniLaunching.value, isFalse);
    });

    testWidgets('OK on Detalhes opens the program\'s WatchNextInfoPanel', (tester) async {
      final resume = FocusNode();
      addTearDown(resume.dispose);
      final watch = _Watch();
      final program = _program();
      await _pump(
        tester,
        Align(alignment: Alignment.topLeft, child: VitrineHeroInfo(program: program, resumeFocusNode: resume)),
        apps: _Apps(),
        watch: watch,
      );
      resume.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(find.byType(WatchNextInfoPanel), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 500));
      final panel = tester.widget<WatchNextInfoPanel>(find.byType(WatchNextInfoPanel));
      expect(panel.program, same(program));
      expect(watch.launched, isEmpty, reason: 'Detalhes does not resume');
      expect(devBertiniLaunching.value, isFalse);
    });

    testWidgets('a click does the same as OK (air mouse)', (tester) async {
      final watch = _Watch();
      await _pump(
        tester,
        Align(alignment: Alignment.topLeft, child: VitrineHeroInfo(program: _program())),
        apps: _Apps(),
        watch: watch,
      );
      await tester.tap(find.text('Continuar'));
      await tester.pump(const Duration(seconds: 5));
      expect(watch.launched, hasLength(1));
      await tester.tap(find.text('Detalhes'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(WatchNextInfoPanel), findsOneWidget);
    });

    testWidgets('the capsules have semantics labels with the title; English text under an English locale',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        Align(alignment: Alignment.topLeft, child: VitrineHeroInfo(program: _program(duration: 30 * _minute))),
        apps: _Apps(),
        watch: _Watch(),
      );
      expect(find.bySemanticsLabel('Continuar The Penguin'), findsOneWidget);
      expect(find.bySemanticsLabel('Detalhes de The Penguin'), findsOneWidget);
      await _pump(
        tester,
        Align(alignment: Alignment.topLeft, child: VitrineHeroInfo(program: _program(duration: 30 * _minute))),
        apps: _Apps(),
        watch: _Watch(),
        locale: const Locale('en'),
      );
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Details'), findsOneWidget);
      expect(find.text('30 min left'), findsOneWidget);
      expect(find.bySemanticsLabel('Continue The Penguin'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('lives in its own layer', (tester) async {
      await _pump(
        tester,
        Align(alignment: Alignment.topLeft, child: VitrineHeroInfo(program: _program())),
        apps: _Apps(),
        watch: _Watch(),
      );
      final outer = find.descendant(of: find.byType(VitrineHeroInfo), matching: find.byType(RepaintBoundary));
      expect(outer, findsWidgets);
      expect(tester.getRect(outer.first), tester.getRect(find.byType(VitrineHeroInfo)));
    });
  });

  group('VitrineClock', () {
    final base = DateTime(2026, 10, 25, 20, 14, 10);

    Widget clock(DateTime Function() now) => Align(alignment: Alignment.topRight, child: VitrineClock(now: () => now()));

    testWidgets('date, time and nothing else without weather, sleep timer or services', (tester) async {
      await _pump(tester, clock(() => base));
      expect(find.text('domingo, 25 out.'), findsOneWidget);
      expect(find.text('20:14'), findsOneWidget);
      expect(find.textContaining('°'), findsNothing);
      expect(find.byType(Icon), findsNothing);
      expect(find.textContaining('Desliga'), findsNothing);
      expect(tester.getSize(find.byType(VitrineClock)).height, 15 + 1 + 27, reason: 'a 15 px line without the icon');
    });

    testWidgets('geometry: the 16 px line, the 27 px time 1 px below, the sleep line 1 px below that, right-aligned',
        (tester) async {
      final weather = _Weather()..value = WeatherNow(24.4, 2, false, base);
      final sleep = _Sleep()..when = DateTime(2026, 10, 25, 23, 30);
      await _pump(tester, clock(() => base), weather: weather, sleep: sleep);
      final date = tester.getRect(find.text('domingo, 25 out.'));
      final time = tester.getRect(find.text('20:14'));
      final off = tester.getRect(find.text('Desliga às 23:30'));
      final block = tester.getRect(find.byType(VitrineClock));
      expect(date.height, 15);
      expect(time.height, 27);
      expect(time.top, 16 + 1, reason: 'the 16 px weather icon makes the first line 16 tall');
      expect(off.height, 15);
      expect(off.top, time.bottom + 1);
      expect(block.height, 16 + 1 + 27 + 1 + 15);
      expect(date.right, block.right);
      expect(time.right, block.right);
      expect(off.right, block.right);
      expect(block.right, 960);
    });

    testWidgets('type: time 25 w300 tracking 0.3, date 12 ink-2, temperature 12 w600 ink; both themes', (tester) async {
      final weather = _Weather()..value = WeatherNow(24.4, 2, false, base);
      final sleep = _Sleep()..when = DateTime(2026, 10, 25, 23, 30);
      for (final t in [dark, light]) {
        await _pump(tester, clock(() => base), weather: weather, sleep: sleep, tokens: t);
        TextStyle style(String s) => tester.widget<Text>(find.text(s)).style!;
        final time = style('20:14');
        expect((time.fontSize, time.fontWeight, time.letterSpacing, time.color), (25.0, FontWeight.w300, 0.3, t.ink));
        final date = style('domingo, 25 out.');
        expect((date.fontSize, date.color), (12.0, t.ink2));
        final temp = style('24°');
        expect((temp.fontSize, temp.fontWeight, temp.color), (12.0, FontWeight.w600, t.ink));
        expect(style('Desliga às 23:30').color, t.ink2);
        final icon = tester.widget<Icon>(find.byType(Icon));
        expect((icon.size, icon.color), (16.0, t.ink2));
      }
    });

    testWidgets('with weather: its icon and the rounded temperature before the date, gaps 5 and 8', (tester) async {
      final weather = _Weather()..value = WeatherNow(24.6, 2, false, base);
      await _pump(tester, clock(() => base), weather: weather);
      final icon = find.byIcon(WeatherNow.iconFor(2, false));
      expect(icon, findsOneWidget);
      expect(find.text('25°'), findsOneWidget);
      final i = tester.getRect(icon), temp = tester.getRect(find.text('25°')), date = tester.getRect(find.text('domingo, 25 out.'));
      expect(i.size, const Size(16, 16));
      expect(temp.left - i.right, 5);
      expect(date.left - temp.right, 8);
    });

    testWidgets('the weather appears and goes with its service, without waiting for the minute', (tester) async {
      final weather = _Weather();
      await _pump(tester, clock(() => base), weather: weather);
      expect(find.textContaining('°'), findsNothing);
      weather.set(WeatherNow(18, 61, true, base));
      await tester.pump();
      expect(find.text('18°'), findsOneWidget);
      expect(find.byIcon(WeatherNow.iconFor(61, true)), findsOneWidget);
      weather.set(null);
      await tester.pump();
      expect(find.textContaining('°'), findsNothing);
    });

    testWidgets('"Desliga às HH:MM" shows while the sleep timer is set and goes when it is cleared', (tester) async {
      final sleep = _Sleep();
      await _pump(tester, clock(() => base), sleep: sleep);
      expect(find.textContaining('Desliga'), findsNothing);
      sleep.when = DateTime(2026, 10, 25, 6, 5);
      sleep.notifyListeners();
      await tester.pump();
      expect(find.text('Desliga às 06:05'), findsOneWidget);
      sleep.when = null;
      sleep.notifyListeners();
      await tester.pump();
      expect(find.textContaining('Desliga'), findsNothing);
    });

    testWidgets('English under an English locale', (tester) async {
      final sleep = _Sleep()..when = DateTime(2026, 10, 25, 23, 30);
      await _pump(tester, clock(() => base), sleep: sleep, locale: const Locale('en'));
      expect(find.text('Sunday, 25 Oct'), findsOneWidget);
      expect(find.text('Turns off at 23:30'), findsOneWidget);
    });

    testWidgets('the time takes the Settings format', (tester) async {
      final settings = _Settings()..format = 'h:mm a';
      await _pump(tester, clock(() => base), settings: settings);
      expect(find.byWidgetPredicate((w) => w is Text && RegExp(r'^8:14\s?PM$').hasMatch(w.data ?? '')), findsOneWidget);
      settings.format = 'HH:mm';
      settings.notifyListeners();
      await tester.pump();
      expect(find.text('20:14'), findsOneWidget);
    });

    testWidgets('rebuilds once a minute, on the minute, and not in between', (tester) async {
      var now = base; // 20:14:10: the minute turns in 50 s
      await _pump(tester, clock(() => now));
      expect(find.text('20:14'), findsOneWidget);
      now = DateTime(2026, 10, 25, 20, 15, 0);
      await tester.pump(const Duration(seconds: 49));
      expect(find.text('20:14'), findsOneWidget, reason: 'no tick before the minute');
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('20:15'), findsOneWidget, reason: 'the tick on the minute');
      now = DateTime(2026, 10, 25, 20, 16, 0);
      await tester.pump(const Duration(seconds: 59));
      expect(find.text('20:15'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('20:16'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('a tick that lands a hair early rebuilds again at once instead of waiting a minute', (tester) async {
      var now = DateTime(2026, 10, 25, 20, 14, 59, 400);
      await _pump(tester, clock(() => now));
      now = DateTime(2026, 10, 25, 20, 15, 0, 0);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('20:15'), findsOneWidget);
    });

    testWidgets('coming back to the front shows the right minute at once', (tester) async {
      var now = base;
      await _pump(tester, clock(() => now));
      now = DateTime(2026, 10, 25, 21, 42, 3);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.text('20:14'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('21:42'), findsOneWidget);
      // The next tick is counted from the new time: 57 s to 21:43.
      now = DateTime(2026, 10, 25, 21, 43, 0);
      await tester.pump(const Duration(seconds: 57));
      expect(find.text('21:43'), findsOneWidget);
    });

    testWidgets('lives in its own layer and leaves no timer behind when removed', (tester) async {
      await _pump(tester, clock(() => base));
      expect(find.descendant(of: find.byType(VitrineClock), matching: find.byType(RepaintBoundary)), findsWidgets);
      await tester.pumpWidget(const SizedBox());
      // flutter_test fails the test if a timer is still pending here.
      await tester.pump(const Duration(minutes: 2));
    });

    testWidgets('without a clock of its own it reads the real one', (tester) async {
      await _pump(tester, const Align(alignment: Alignment.topRight, child: VitrineClock()));
      final real = DateTime.now();
      final hour = real.hour.toString();
      expect(find.textContaining(RegExp('^$hour:')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
