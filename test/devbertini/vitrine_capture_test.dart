/// Captures of the real Vitrine home at 1920x1080 (the 960x540 canvas at the TV's device pixel ratio 2), for the
/// README: Onest, the Material icons, the brand logos of `build/devbertini-logos` (tools/devbertini/logo_art.py; the
/// plates show the apps' names without them) and landscapes painted here, so no picture of a real show or stream
/// appears. Skipped in the normal runs: it writes files.
///
///     VITRINE_CAPTURE=1 flutter test test/devbertini/vitrine_capture_test.dart
///
/// Writes build/vitrine-capture/home-dark.png, rail-dark.png and home-light.png.
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flauncher/devbertini/brand.dart';
import 'package:flauncher/devbertini/cinematic.dart';
import 'package:flauncher/devbertini/profile_model.dart';
import 'package:flauncher/devbertini/vitrine/dedication.dart';
import 'package:flauncher/devbertini/vitrine/home.dart';
import 'package:flauncher/devbertini/vitrine/logos.dart';
import 'package:flauncher/devbertini/vitrine/material_theme.dart';
import 'package:flauncher/devbertini/vitrine/tokens.dart';
import 'package:flauncher/models/app.dart';
import 'package:flauncher/models/category.dart';
import 'package:flauncher/models/watch_next_program.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/launcher_state.dart';
import 'package:flauncher/providers/notifications_service.dart';
import 'package:flauncher/providers/now_playing_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/tv_inputs_service.dart';
import 'package:flauncher/providers/watch_next_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

const _out = 'build/vitrine-capture';
const _youTube = 'com.google.android.youtube.tv';
const _twitch = 'tv.twitch.android.app';

class _Playing extends ChangeNotifier implements NowPlayingService {
  @override
  NowPlaying? get current => const NowPlaying('com.spotify.tv.android', 'Neon Horizon', 'The Midnight Drive', true);

  @override
  Uint8List? get art => null;

  @override
  double? get progress => 0.38;

  @override
  Duration? get remaining => const Duration(minutes: 3, seconds: 12);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Profile extends ChangeNotifier implements ProfilesController {
  final LauncherProfile _main = LauncherProfile(id: mainProfileId, name: 'Sala', color: 0);

  @override
  List<LauncherProfile> get profiles => [_main];

  @override
  LauncherProfile get current => _main;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

WatchNextProgram _program(int id, String package, String title, int left, double watched, {String description = ''}) {
  final duration = (left / (1 - watched) * 60000).round();
  return WatchNextProgram(
    id: id,
    packageName: package,
    title: title,
    description: description,
    watchNextType: 0,
    lastEngagementTime: 100 - id,
    playbackPosition: duration - left * 60000,
    duration: duration,
    intentUri: '',
    posterArtUri: '',
  );
}

/// The colours of one painted landscape: the sky from top to bottom, the sun and the nearest ridge.
typedef _Scene = (Color, Color, Color, Color);

const List<_Scene> _scenes = [
  (Color(0xFF07152E), Color(0xFF1E6E6A), Color(0xFF9EF0D0), Color(0xFF04101C)), // aurora
  (Color(0xFF2B1240), Color(0xFFE0785A), Color(0xFFFFD9A0), Color(0xFF1A0B1F)), // dusk
  (Color(0xFF3A2416), Color(0xFFE8A55A), Color(0xFFFFF0C0), Color(0xFF24150C)), // desert
  (Color(0xFF06283D), Color(0xFF2B8BB0), Color(0xFFCFF3FF), Color(0xFF031722)), // ocean
  (Color(0xFF160B33), Color(0xFFB4357A), Color(0xFFFFB3E1), Color(0xFF0C061C)), // synth
  (Color(0xFF0E2A1C), Color(0xFF6FA36B), Color(0xFFF3F7D2), Color(0xFF07170F)), // forest
];

/// A landscape of [scene]: a sky, a sun with its glow and three ridges, as a PNG of 1280x720.
Future<Uint8List> _paint(_Scene scene, int seed) async {
  const w = 1280.0, h = 720.0;
  final (top, bottom, sun, ridge) = scene;
  final random = math.Random(seed);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, w, h),
    Paint()..shader = ui.Gradient.linear(Offset.zero, const Offset(0, h), [top, bottom]),
  );
  final centre = Offset(w * (0.55 + random.nextDouble() * 0.3), h * (0.32 + random.nextDouble() * 0.12));
  canvas.drawCircle(centre, 260,
      Paint()..shader = ui.Gradient.radial(centre, 260, [sun.withValues(alpha: 0.45), sun.withValues(alpha: 0)]));
  canvas.drawCircle(centre, 56, Paint()..color = sun);
  for (var layer = 0; layer < 3; layer++) {
    final base = h * (0.55 + layer * 0.12);
    final colour = Color.lerp(bottom, ridge, 0.45 + layer * 0.27)!;
    final phase = random.nextDouble() * math.pi * 2;
    final path = Path()..moveTo(0, h);
    for (var x = 0.0; x <= w; x += 8) {
      final y = base -
          math.sin(x / (180 + layer * 60) + phase) * (38 - layer * 8) -
          math.sin(x / 61 + phase * 2) * (9 - layer * 2);
      path.lineTo(x, y);
    }
    path
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(path, Paint()..color = colour);
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(w.toInt(), h.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return bytes!.buffer.asUint8List();
}

Future<void> _font(String family, Future<ByteData> bytes) async {
  final loader = FontLoader(family)..addFont(bytes);
  await loader.load();
}

/// The Flutter SDK the test runs from: FLUTTER_ROOT, else five folders above flutter_tester
/// (`<root>/bin/cache/artifacts/engine/<platform>/flutter_tester`).
String _flutterRoot() {
  final fromEnv = Platform.environment['FLUTTER_ROOT'];
  if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 5; i++) {
    dir = dir.parent;
  }
  return dir.path;
}

void main() {
  final capture = Platform.environment['VITRINE_CAPTURE'] == '1';

  // The pictures show the public build's signature, whatever the build they are rendered from.
  setUpAll(() => VitrineDedication.shown = false);
  tearDownAll(() => VitrineDedication.shown = true);

  testWidgets('captures of the Vitrine home', (tester) async {
    expect(VitrineDedication.of(VitrineTokens.dark(CinematicPalette.devBertini)), isNull);
    await tester.runAsync(() async {
      await _font('Onest', rootBundle.load('assets/fonts/Onest/Onest-Variable.ttf'));
      final icons = File('${_flutterRoot()}/bin/cache/artifacts/material_fonts/materialicons-regular.otf');
      await _font('MaterialIcons', Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    });

    // Made-up programs on the two services where anyone publishes: a hero and five more in the row. Each has a
    // package of its own, so each gets its own painted landscape; the logos are the services'.
    final hero = _program(1, 'capture.hero', 'Aurora over the fjords', 38, 0.58,
        description: 'Uma viagem lenta em 4K pelos céus do norte, filmada ao longo de três invernos.');
    final rows = [
      _program(2, 'capture.card2', 'Retro speedrun night', 52, 0.22),
      _program(3, 'capture.card3', 'Desert road trip, 8 hours', 17, 0.72),
      _program(4, 'capture.card4', 'Ocean sounds for sleep', 31, 0.40),
      _program(5, 'capture.card5', 'Synth from scratch', 9, 0.86),
      _program(6, 'capture.card6', 'Lofi beats to focus', 44, 0.30),
    ];
    final service = {
      'capture.hero': _youTube,
      'capture.card2': _twitch,
      'capture.card3': _youTube,
      'capture.card4': _youTube,
      'capture.card5': _twitch,
      'capture.card6': _youTube,
    };
    final banners = <String, Uint8List>{};
    await tester.runAsync(() async {
      var i = 0;
      for (final package in service.keys) {
        banners[package] = await _paint(_scenes[i % _scenes.length], i + 7);
        i++;
      }
    });

    // The logos of the device, and each made-up program under its service's logo.
    final logos = Directory.systemTemp.createTempSync('vitrine_capture_logos_');
    addTearDown(() => logos.deleteSync(recursive: true));
    // Without logos (tools/devbertini/logo_art.py) the plates show the apps' names.
    final made = Directory('build/devbertini-logos');
    for (final file in made.existsSync() ? made.listSync().whereType<File>() : const <File>[]) {
      file.copySync('${logos.path}/${file.uri.pathSegments.last}');
    }
    for (final MapEntry(key: package, value: of) in service.entries) {
      for (final kind in ['black', 'light']) {
        final logo = File('build/devbertini-logos/logo_${kind}_$of.png');
        if (logo.existsSync()) logo.copySync('${logos.path}/logo_${kind}_$package.png');
      }
    }
    final vitrineLogos = VitrineLogos(directory: () async => logos);
    await tester.runAsync(vitrineLogos.load);

    final apps = [
      for (final (package, name) in [
        ('com.netflix.ninja', 'Netflix'),
        (_youTube, 'YouTube'),
        ('com.wbd.stream', 'HBO Max'),
        ('com.amazon.amazonvideo.livingroom', 'Prime Video'),
        (_twitch, 'Twitch'),
        ('com.spotify.tv.android', 'Spotify'),
        ('com.android.vending', 'Google Play Store'),
      ])
        App(packageName: package, name: name, version: '1', hidden: false),
    ];
    final main = fakeCategory(name: 'TV Apps', order: 0, type: CategoryType.row)..applications.addAll(apps);
    final appsService = MockAppsService();
    when(appsService.initialized).thenReturn(true);
    when(appsService.launcherSections).thenReturn([main]);
    when(appsService.applications).thenReturn(apps);
    when(appsService.cachedBanner(any)).thenAnswer((call) => banners[call.positionalArguments.first]);
    when(appsService.cachedIcon(any)).thenReturn(null);
    when(appsService.getAppBanner(any)).thenAnswer((_) async => Uint8List(0));
    when(appsService.pendingReorderFocusPackage).thenReturn(null);
    when(appsService.getApp(any)).thenAnswer(
        (call) => apps.where((app) => app.packageName == call.positionalArguments.first).firstOrNull);
    final settings = MockSettingsService();
    when(settings.themes).thenReturn(devBertiniTheme);
    when(settings.timeFormat).thenReturn(SettingsService.defaultTimeFormat);
    when(settings.showContinueWatching).thenReturn(true);
    when(settings.hiddenWatchNextProgramIds).thenReturn(const []);
    when(settings.hiddenWatchNextPackages).thenReturn(const []);
    when(settings.continueWatchingMaxItems).thenReturn(15);
    final watchNext = MockWatchNextService();
    when(watchNext.hasPermission).thenReturn(true);
    when(watchNext.programs).thenReturn([hero, ...rows]);
    final inputs = MockTvInputsService();
    when(inputs.hasInputs).thenReturn(true);
    when(inputs.devices).thenReturn(const []);
    final notifications = MockNotificationsService();
    when(notifications.hasPermission).thenReturn(true);
    when(notifications.notifications).thenReturn([
      for (var i = 0; i < 3; i++)
        NotificationItem(key: '$i', packageName: 'x', title: 't', text: 't', isClearable: true),
    ]);

    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final boundary = GlobalKey();

    Future<void> shoot(Brightness brightness, String name, {List<LogicalKeyboardKey> keys = const []}) async {
      final tokens = VitrineTokens.of(CinematicPalette.devBertini, brightness);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AppsService>.value(value: appsService),
          ChangeNotifierProvider<SettingsService>.value(value: settings),
          ChangeNotifierProvider<WatchNextService>.value(value: watchNext),
          ChangeNotifierProvider<TvInputsService>.value(value: inputs),
          ChangeNotifierProvider<NotificationsService>.value(value: notifications),
          ChangeNotifierProvider<NowPlayingService>.value(value: _Playing()),
          ChangeNotifierProvider<ProfilesController>.value(value: _Profile()),
          ChangeNotifierProvider<VitrineLogos>.value(value: vitrineLogos),
          ChangeNotifierProvider(create: (_) => LauncherState()),
        ],
        child: RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: const Locale('pt', 'BR'),
            supportedLocales: const [Locale('pt', 'BR'), Locale('en')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: vitrineMaterialTheme(tokens),
            builder: (context, child) => VitrineTheme(tokens: tokens, child: child!),
            // As FLauncher puts it: on no Scaffold.
            home: const VitrineHome(),
          ),
        ),
      ));
      // The pictures decode off the test's clock; then one frame draws them.
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
        await tester.pump(const Duration(milliseconds: 400));
      }
      for (final key in keys) {
        await tester.sendKeyEvent(key);
        await tester.pump(const Duration(milliseconds: 300));
      }
      for (var i = 0; i < 2; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
        await tester.pump(const Duration(milliseconds: 500));
      }
      await tester.runAsync(() async {
        final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 2);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory(_out).createSync(recursive: true);
        File('$_out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
      });
    }

    await shoot(Brightness.dark, 'home-dark');
    await shoot(Brightness.dark, 'rail-dark',
        keys: [LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.arrowDown]);
    await shoot(Brightness.light, 'home-light');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
    devBertiniLaunching.value = false;
  }, skip: !capture);
}
