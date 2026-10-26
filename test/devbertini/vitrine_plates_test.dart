import 'dart:io';

import 'package:flauncher/devbertini/brand.dart';
import 'package:flauncher/devbertini/vitrine/app_row.dart';
import 'package:flauncher/devbertini/vitrine/logos.dart';
import 'package:flauncher/devbertini/vitrine/plate.dart';
import 'package:flauncher/devbertini/vitrine/tokens.dart';
import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/models/app.dart';
import 'package:flauncher/models/category.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/launcher_state.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/application_info_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// A 1x1 white PNG, enough for a logo or a banner to be read and drawn.
final Uint8List _png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00,
  0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0D, 0x49,
  0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xFF, 0xFF, 0xFF, 0x7F, 0x00, 0x09, 0xFB, 0x03, 0xFD, 0x2A, 0x86, 0xE3,
  0x8A, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// The seven brands and the logo height the spec gives each, written out here and not read from the code.
const Map<String, double> _specHeights = {
  'com.netflix.ninja': 25,
  'com.google.android.youtube.tv': 21,
  'com.wbd.stream': 37,
  'com.amazon.amazonvideo.livingroom': 26,
  'tv.twitch.android.app': 25,
  'com.spotify.tv.android': 26,
  'com.android.vending': 34,
};

/// Only what the plates call; anything else a test did not expect fails loudly.
class _FakeApps extends ChangeNotifier implements AppsService {
  final Map<String, Uint8List> banners = {};
  final List<String> bannerRequests = [];
  final List<String> launched = [];
  final List<String> events = [];
  String? pendingPackage;
  int? pendingCategory;

  @override
  Uint8List? cachedBanner(String packageName) => banners[packageName];

  @override
  Uint8List? cachedIcon(String packageName) => null;

  @override
  Future<Uint8List> getAppBanner(String packageName) async {
    bannerRequests.add(packageName);
    return banners[packageName] ?? Uint8List(0);
  }

  @override
  Future<bool> hasCustomBanner(String packageName) async => false;

  @override
  Future<void> launchApp(App app) async => launched.add(app.packageName);

  @override
  String? get pendingReorderFocusPackage => pendingPackage;

  @override
  int? get pendingReorderFocusCategoryId => pendingCategory;

  @override
  void clearPendingReorderFocusPackage() {
    pendingPackage = null;
    pendingCategory = null;
  }

  @override
  void setPendingReorderFocus(String packageName, int categoryId, int index) {
    pendingPackage = packageName;
    pendingCategory = categoryId;
  }

  @override
  void reorderApplication(Category category, int oldIndex, int newIndex) {
    final app = category.applications.removeAt(oldIndex);
    category.applications.insert(newIndex, app);
    events.add('reorder $oldIndex>$newIndex');
    notifyListeners();
  }

  @override
  Future<void> saveApplicationOrderInCategory(Category category) async => events.add('save');

  @override
  void cancelReorderApplication(Category category) => events.add('cancel');

  @override
  bool isAppInFavorites(App app) => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The one setting the options panel's frame reads.
class _FakeSettings extends ChangeNotifier implements SettingsService {
  @override
  String get themes => 'classic';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

App _app(String package, [String? name]) => App(packageName: package, name: name ?? package, version: '1', hidden: false);

Category _category(List<App> apps) => Category.withApplications(name: 'Apps', id: 7, applications: [...apps]);

List<App> _apps(int n) => [for (var i = 0; i < n; i++) _app('com.example.app$i', 'App $i')];

/// The options panel is not this lane's; in flutter_test's square font its rows are wider than the 300 px panel.
/// Its overflow reports are dropped, any other error still fails the test.
void _ignorePanelOverflow() {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
}

late _FakeApps _service;
late LauncherState _launcher;

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  VitrineTokens? tokens,
  VitrineLogos? logos,
  Locale? locale,
}) async {
  _ignorePanelOverflow();
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  _launcher = LauncherState();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppsService>.value(value: _service),
        ChangeNotifierProvider<LauncherState>.value(value: _launcher),
        ChangeNotifierProvider<SettingsService>.value(value: _FakeSettings()),
        if (logos != null) ChangeNotifierProvider<VitrineLogos>.value(value: logos),
      ],
      child: VitrineTheme(
        tokens: tokens ?? VitrineTokens.dark(CinematicPalette.devBertini),
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            backgroundColor: Colors.black,
            body: Align(alignment: Alignment.topLeft, child: child),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// The row as the home places it: from x 100, 860 wide, at y 232.
Future<void> _pumpRow(
  WidgetTester tester,
  Category category, {
  VoidCallback? onAll,
  VoidCallback? onLeft,
  FocusNode? first,
  bool autofocus = true,
  VitrineTokens? tokens,
}) =>
    _pump(
      tester,
      Padding(
        padding: const EdgeInsets.only(left: 100, top: 232),
        child: SizedBox(
          width: 860,
          child: VitrineAppRow(
            category: category,
            onAll: onAll ?? () {},
            firstFocusNode: first,
            autofocusFirst: autofocus,
            onLeftFromFirst: onLeft,
          ),
        ),
      ),
      tokens: tokens,
    );

Finder _plate(String package) => find.byKey(ValueKey('plate:$package'));
Finder get _all => find.byKey(const ValueKey('plate:all'));

/// The focus node of the plate (or Todos) found by [finder].
FocusNode _focusOf(WidgetTester tester, Finder finder) =>
    Focus.of(tester.element(find.descendant(of: finder, matching: find.byType(GestureDetector))));

/// The plate's own rectangle: the list gives each plate a 154 px slot (the plate and the gap after it).
Rect _rectOf(WidgetTester tester, Finder f) =>
    tester.getRect(find.descendant(of: f, matching: find.byType(GestureDetector)));

/// The plate drawn for [package]: the box with the fill and the box with the edge.
BoxDecoration _fill(WidgetTester tester, String package) => tester
    .widgetList<DecoratedBox>(find.descendant(of: _plate(package), matching: find.byType(DecoratedBox)))
    .map((d) => d.decoration)
    .whereType<BoxDecoration>()
    .firstWhere((d) => d.color != null && d.borderRadius != null);

BoxDecoration _edge(WidgetTester tester, String package) => tester
    .widgetList<DecoratedBox>(find.descendant(of: _plate(package), matching: find.byType(DecoratedBox)))
    .map((d) => d.decoration)
    .whereType<BoxDecoration>()
    .firstWhere((d) => d.border != null && d.border!.top.strokeAlign == BorderSide.strokeAlignInside);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => _service = _FakeApps());

  group('VitrinePlate', () {
    testWidgets('is 140x71 with the radius, fill and 1 px edge of the dark theme', (tester) async {
      final app = _app('com.example.one', 'One');
      await _pump(tester, VitrinePlate(key: const ValueKey('plate:com.example.one'), app: app, category: _category([app])));

      expect(tester.getSize(find.byType(VitrinePlate)), const Size(140, 71));
      final fill = _fill(tester, 'com.example.one');
      expect(fill.color, const Color(0xFF000000));
      expect(fill.borderRadius, BorderRadius.circular(12));
      final edge = _edge(tester, 'com.example.one');
      expect(edge.border!.top.color, const Color(0xFF262A31));
      expect(edge.border!.top.width, 1);
    });

    testWidgets('has the white fill and the #D3DAE3 edge in the light theme', (tester) async {
      final app = _app('com.example.one', 'One');
      await _pump(
        tester,
        VitrinePlate(key: const ValueKey('plate:com.example.one'), app: app, category: _category([app])),
        tokens: VitrineTokens.light(CinematicPalette.devBertini),
      );

      expect(tester.getSize(find.byType(VitrinePlate)), const Size(140, 71));
      expect(_fill(tester, 'com.example.one').color, const Color(0xFFFFFFFF));
      expect(_edge(tester, 'com.example.one').border!.top.color, const Color(0xFFD3DAE3));
    });

    testWidgets('draws each known brand logo at the height the spec gives it', (tester) async {
      final dir = Directory.systemTemp.createTempSync('vitrine_plates_');
      addTearDown(() => dir.deleteSync(recursive: true));
      for (final package in _specHeights.keys) {
        File('${dir.path}/logo_light_$package.png').writeAsBytesSync(_png);
      }
      final logos = VitrineLogos(directory: () async => dir);
      await tester.runAsync(logos.load);

      for (final entry in _specHeights.entries) {
        final app = _app(entry.key, 'Brand');
        await _pump(tester, VitrinePlate(app: app, category: _category([app])), logos: logos);
        final image = tester.widget<Image>(find.descendant(of: find.byType(VitrinePlate), matching: find.byType(Image)));
        expect(image.height, entry.value, reason: entry.key);
        // Centred on the plate.
        final plate = tester.getRect(find.byType(VitrinePlate));
        expect(tester.getRect(find.byType(Image)).center, plate.center, reason: entry.key);
        expect(find.text('Brand'), findsNothing, reason: entry.key);
      }
    });

    testWidgets('an unknown app draws its banner covering the plate, decoded at 280 px wide', (tester) async {
      final app = _app('com.example.unknown', 'Unknown');
      _service.banners[app.packageName] = _png;
      await _pump(tester, VitrinePlate(app: app, category: _category([app])));

      final image = tester.widget<Image>(find.descendant(of: find.byType(VitrinePlate), matching: find.byType(Image)));
      expect(image.fit, BoxFit.cover);
      expect(tester.getSize(find.byType(Image)), const Size(140, 71));
      final provider = image.image as ResizeImage;
      expect(provider.width, 280);
      expect(find.text('Unknown'), findsNothing);
      expect(_service.bannerRequests, isEmpty);
    });

    testWidgets('an unknown app with no banner draws its name in 14 px w600, and asks for the banner once', (tester) async {
      final app = _app('com.example.unknown', 'Unknown');
      await _pump(tester, VitrinePlate(app: app, category: _category([app])));
      await tester.pump();

      final text = tester.widget<Text>(find.text('Unknown'));
      expect(text.style!.fontSize, 14);
      expect(text.style!.fontWeight, FontWeight.w600);
      expect(text.style!.color, const Color(0xFFF2F4F8));
      expect(_service.bannerRequests, ['com.example.unknown']);
    });

    testWidgets('a known brand whose logo is not on the device falls back to its name', (tester) async {
      final app = _app('com.netflix.ninja', 'Netflix');
      await _pump(tester, VitrinePlate(app: app, category: _category([app])), logos: VitrineLogos(directory: () async => null));

      expect(find.text('Netflix'), findsOneWidget);
      expect(_service.bannerRequests, isEmpty);
    });

    testWidgets('the name takes the ink of the light theme', (tester) async {
      final app = _app('com.example.unknown', 'Unknown');
      await _pump(
        tester,
        VitrinePlate(app: app, category: _category([app])),
        tokens: VitrineTokens.light(CinematicPalette.devBertini),
      );

      expect(tester.widget<Text>(find.text('Unknown')).style!.color, const Color(0xFF14171C));
    });

    testWidgets('focus grows the plate by 1.06 inside the accent ring, and only that plate', (tester) async {
      final apps = _apps(2);
      final category = _category(apps);
      await _pump(
        tester,
        Row(children: [
          for (final app in apps) VitrinePlate(app: app, category: category, autofocus: app == apps.first),
        ]),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final focused = tester.getSize(find.byType(VitrinePlate).first);
      final resting = tester.getSize(find.byType(VitrinePlate).last);
      expect(focused, const Size(140, 71));
      expect(resting, const Size(140, 71));
      final scales = tester.widgetList<AnimatedScale>(find.byType(AnimatedScale)).map((s) => s.scale).toList();
      expect(scales, [1.06, 1.0]);
    });

    testWidgets('has a Semantics label with the app name', (tester) async {
      final app = _app('com.example.unknown', 'Unknown');
      await _pump(tester, VitrinePlate(app: app, category: _category([app])));

      expect(find.bySemanticsLabel('Unknown'), findsOneWidget);
    });

    testWidgets('OK launches the app', (tester) async {
      final app = _app('com.example.one', 'One');
      await _pump(tester, VitrinePlate(app: app, category: _category([app]), autofocus: true));

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump(const Duration(seconds: 5)); // the launch fade's 4 s timer

      expect(_service.launched, ['com.example.one']);
    });

    testWidgets('every OK key of the remote launches it', (tester) async {
      final app = _app('com.example.one', 'One');
      await _pump(tester, VitrinePlate(app: app, category: _category([app]), autofocus: true));

      for (final key in [
        LogicalKeyboardKey.enter,
        LogicalKeyboardKey.numpadEnter,
        LogicalKeyboardKey.gameButtonA,
        LogicalKeyboardKey.space,
      ]) {
        await tester.sendKeyEvent(key);
        await tester.pump(const Duration(seconds: 5));
      }

      expect(_service.launched.length, 4);
    });

    testWidgets('holding OK opens the options panel and does not launch', (tester) async {
      final app = _app('com.example.one', 'One');
      await _pump(tester, VitrinePlate(app: app, category: _category([app]), autofocus: true));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(ApplicationInfoPanel), findsNothing);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ApplicationInfoPanel), findsOneWidget);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
      await tester.pump(const Duration(seconds: 5));

      expect(_service.launched, isEmpty);
    });

    testWidgets('the menu key opens the options panel at once', (tester) async {
      final app = _app('com.example.one', 'One');
      await _pump(tester, VitrinePlate(app: app, category: _category([app]), autofocus: true));

      await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ApplicationInfoPanel), findsOneWidget);
    });

    testWidgets('Left calls onLeftEdge when the plate has one, and nothing else happens', (tester) async {
      final app = _app('com.example.one', 'One');
      var left = 0;
      await _pump(
        tester,
        VitrinePlate(app: app, category: _category([app]), autofocus: true, onLeftEdge: () => left++),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();

      expect(left, 1);
      expect(_service.launched, isEmpty);
    });
  });

  group('move mode', () {
    Future<void> openMove(WidgetTester tester) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 400));
      // The panel is chosen from while OK is still held down, and OK is released after the panel closed: that key
      // up reaches the plate in the move mode.
      await tester.tap(find.byIcon(Icons.open_with));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
      await tester.pump();
    }

    List<String> order(Category c) => c.applications.map((a) => a.packageName).toList();

    testWidgets('Reordenar in the options panel starts it; arrows move the plate and OK keeps the place', (tester) async {
      final category = _category(_apps(4));
      final first = FocusNode();
      addTearDown(first.dispose);
      await _pumpRow(tester, category, first: first);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight); // app1
      await tester.pump(const Duration(milliseconds: 300));
      await openMove(tester);

      expect(find.byType(ApplicationInfoPanel), findsNothing);
      expect(find.bySemanticsLabel('App 1, moving'), findsOneWidget);
      // The OK that chose the option is still being released: it must not drop the plate.
      expect(_service.events, isEmpty);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 300));
      expect(order(category), ['com.example.app0', 'com.example.app2', 'com.example.app1', 'com.example.app3']);
      expect(_service.events, ['reorder 1>2']);
      // The plate keeps the focus and the move mode in its new place.
      expect(find.bySemanticsLabel('App 1, moving'), findsOneWidget);
      expect(FocusManager.instance.primaryFocus, _focusOf(tester, _plate('com.example.app1')));

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      expect(_service.events, ['reorder 1>2', 'save']);
      expect(find.bySemanticsLabel('App 1'), findsOneWidget);
    });

    testWidgets('moving the first plate keeps the focus on it though the row hands its node to another', (tester) async {
      final category = _category(_apps(3));
      final first = FocusNode();
      addTearDown(first.dispose);
      await _pumpRow(tester, category, first: first);
      await openMove(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 300));

      expect(order(category).first, 'com.example.app1');
      expect(find.bySemanticsLabel('App 0, moving'), findsOneWidget);
      expect(_focusOf(tester, _plate('com.example.app0')).hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump(const Duration(milliseconds: 300));
      expect(order(category).first, 'com.example.app0');
      expect(_focusOf(tester, _plate('com.example.app0')).hasPrimaryFocus, isTrue);
      expect(find.bySemanticsLabel('App 0, moving'), findsOneWidget);
    });

    testWidgets('a plate cannot be moved past either end of the apps, nor onto "Todos"', (tester) async {
      final category = _category(_apps(2));
      await _pumpRow(tester, category);
      await openMove(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(_service.events, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(_service.events, ['reorder 0>1']);
      expect(order(category), ['com.example.app1', 'com.example.app0']);
    });

    testWidgets('Back puts the order back and holds the Back navigation for a moment; Left does not leave the row', (tester) async {
      final category = _category(_apps(3));
      var leftFromFirst = 0;
      await _pumpRow(tester, category, onLeft: () => leftFromFirst++);
      await openMove(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(leftFromFirst, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(_service.events, ['cancel']);
      expect(find.bySemanticsLabel('App 0'), findsOneWidget);
      expect(find.bySemanticsLabel('App 0, moving'), findsNothing);
      // Back while moving only cancels the move: the home's own Back action, which would read the settings (absent
      // here, so it would throw), is held off for a moment.
      final context = tester.element(find.byType(VitrineAppRow));
      expect(() => Provider.of<LauncherState>(context, listen: false).handleBackNavigation(context), returnsNormally);
    });
  });

  group('VitrineAllPlate', () {
    testWidgets('is the same plate with the apps icon at 22 px and "Todos" in 16 px w600 ink-2', (tester) async {
      await _pump(tester, VitrineAllPlate(onPressed: () {}), locale: const Locale('pt'));

      expect(tester.getSize(find.byType(VitrineAllPlate)), const Size(140, 71));
      expect(tester.getSize(find.byIcon(Icons.apps_rounded)), const Size(22, 22));
      final text = tester.widget<Text>(find.text('Todos'));
      expect(text.style!.fontSize, 16);
      expect(text.style!.fontWeight, FontWeight.w600);
      expect(text.style!.color, const Color(0xFFA3A8B0));
      // Icon, 6 px, text: centred as a group.
      final icon = tester.getRect(find.byIcon(Icons.apps_rounded)), label = tester.getRect(find.text('Todos'));
      expect(label.left - icon.right, 6);
      expect((icon.left + label.right) / 2, tester.getRect(find.byType(VitrineAllPlate)).center.dx);
    });

    testWidgets('says "All" in English and has the light theme ink-2', (tester) async {
      await _pump(
        tester,
        VitrineAllPlate(onPressed: () {}),
        locale: const Locale('en'),
        tokens: VitrineTokens.light(CinematicPalette.devBertini),
      );

      // The test locale is the platform's English: the label is the English one.
      expect(find.text('All'), findsOneWidget);
      expect(tester.widget<Text>(find.text('All')).style!.color, const Color(0xFF4A525E));
    });

    testWidgets('OK calls onPressed once', (tester) async {
      var pressed = 0;
      await _pump(tester, VitrineAllPlate(onPressed: () => pressed++, autofocus: true));

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();

      expect(pressed, 1);
    });
  });

  group('VitrineAppRow', () {
    testWidgets('lays out the label, 9 px, then the plates 14 px apart with Todos last', (tester) async {
      final apps = _apps(3);
      await _pumpRow(tester, _category(apps));

      final label = tester.getRect(find.text('Apps'));
      expect(label.top, 232);
      expect(label.height, 18);
      final style = tester.widget<Text>(find.text('Apps')).style!;
      expect(style.fontSize, 15);
      expect(style.fontWeight, FontWeight.w600);

      // y 259..330, x from 100, a 14 px gap.
      final rects = [for (final a in apps) _rectOf(tester, _plate(a.packageName)), _rectOf(tester, _all)];
      for (var i = 0; i < rects.length; i++) {
        expect(rects[i].size, const Size(140, 71), reason: 'plate $i');
        expect(rects[i].top, 259, reason: 'plate $i');
        expect(rects[i].left, 100 + i * 154.0, reason: 'plate $i');
      }
      expect(tester.getSize(find.byType(VitrineAppRow)).height, 18 + 9 + 71);
      expect(tester.getSize(find.byType(VitrineAppRow)).width, 860);
    });

    testWidgets('shows five whole plates and the sixth peeking 90 px at the edge of the 960 wide screen', (tester) async {
      final apps = _apps(8);
      await _pumpRow(tester, _category(apps));

      for (var i = 0; i < 5; i++) {
        expect(_rectOf(tester, _plate(apps[i].packageName)).right, lessThanOrEqualTo(960 - 90 - 14), reason: 'plate $i');
      }
      final sixth = _rectOf(tester, _plate(apps[5].packageName));
      expect(960 - sixth.left, 90);
    });

    testWidgets('draws the label in the ink of each theme', (tester) async {
      await _pumpRow(tester, _category(_apps(1)));
      expect(tester.widget<Text>(find.text('Apps')).style!.color, const Color(0xFFF2F4F8));

      await _pumpRow(tester, _category(_apps(1)), tokens: VitrineTokens.light(CinematicPalette.devBertini));
      await tester.pump();
      expect(tester.widget<Text>(find.text('Apps')).style!.color, const Color(0xFF14171C));
    });

    testWidgets('builds only the plates near the viewport', (tester) async {
      await _pumpRow(tester, _category(_apps(60)));

      expect(find.byType(VitrinePlate).evaluate().length, lessThan(12));
      expect(find.byType(VitrineAllPlate), findsNothing);
    });

    testWidgets('autofocuses the first plate, which takes the focus node it was given', (tester) async {
      final first = FocusNode();
      addTearDown(first.dispose);
      await _pumpRow(tester, _category(_apps(3)), first: first);
      await tester.pump();

      expect(first.hasPrimaryFocus, isTrue);
      expect(_focusOf(tester, _plate('com.example.app0')), same(first));
    });

    testWidgets('does not take the focus unless asked to', (tester) async {
      await _pumpRow(tester, _category(_apps(3)), autofocus: false);
      await tester.pump();

      expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<VitrinePlate>(), isNull);
    });

    testWidgets('Right and Left move the focus along the row', (tester) async {
      final apps = _apps(4);
      await _pumpRow(tester, _category(apps));
      bool focused(String p) => _focusOf(tester, _plate(p)).hasPrimaryFocus;

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 300));
      expect(focused('com.example.app1'), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 300));
      expect(focused('com.example.app3'), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 300));
      expect(_focusOf(tester, _all).hasPrimaryFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump(const Duration(milliseconds: 300));
      expect(focused('com.example.app3'), isTrue);
    });

    testWidgets('Left on the first plate calls back; on any other it moves the focus instead', (tester) async {
      var left = 0;
      await _pumpRow(tester, _category(_apps(3)), onLeft: () => left++);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump(const Duration(milliseconds: 300));
      expect(left, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump(const Duration(milliseconds: 300));
      expect(left, 1);
      expect(_focusOf(tester, _plate('com.example.app0')).hasPrimaryFocus, isTrue);
    });

    testWidgets('Todos is the first when the category has no apps, and Left on it calls back', (tester) async {
      var left = 0, all = 0;
      await _pumpRow(tester, _category(const []), onLeft: () => left++, onAll: () => all++);
      await tester.pump();

      expect(_rectOf(tester, _all).left, 100);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();

      expect(left, 1);
      expect(all, 1);
    });

    testWidgets('OK on Todos calls onAll', (tester) async {
      var all = 0;
      await _pumpRow(tester, _category(_apps(1)), onAll: () => all++);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();

      expect(all, 1);
    });

    testWidgets('a focus far right scrolls the row only as far as needed, leaving the next plate peeking', (tester) async {
      final apps = _apps(9);
      await _pumpRow(tester, _category(apps));
      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(scrollable.position.pixels, 0);

      // Plates 0 to 4 are whole: moving along them does not scroll.
      for (var i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(scrollable.position.pixels, 0);

      // The sixth was peeking: now it is whole and the seventh shows 90 px at the edge.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      final focused = _rectOf(tester, _plate(apps[5].packageName));
      final next = _rectOf(tester, _plate(apps[6].packageName));
      expect(focused.left, 716);
      expect(focused.right, lessThanOrEqualTo(960 - 90 - 14));
      expect(960 - next.left, 90);
      expect(scrollable.position.pixels, 154);

      // Going back one plate does not scroll while it is in view.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(scrollable.position.pixels, 154);
    });

    testWidgets('the last plate, Todos, ends at the right edge with nothing to peek', (tester) async {
      final apps = _apps(9);
      await _pumpRow(tester, _category(apps));

      for (var i = 0; i < 9; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
      }

      expect(_focusOf(tester, _all).hasPrimaryFocus, isTrue);
      expect(_rectOf(tester, _all).right, lessThanOrEqualTo(960));
      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(scrollable.position.pixels, scrollable.position.maxScrollExtent);
    });

    testWidgets('going back left shows the previous plate peeking before the focused one', (tester) async {
      final apps = _apps(9);
      await _pumpRow(tester, _category(apps));
      for (var i = 0; i < 9; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
      }
      for (var i = 0; i < 6; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
      }

      // Focus is on plate 3 now: whole, with the plate before it showing 90 px at the left edge.
      final focused = _rectOf(tester, _plate(apps[3].packageName));
      final before = _rectOf(tester, _plate(apps[2].packageName));
      expect(focused.left, greaterThanOrEqualTo(100));
      expect(before.right - 100, 90);
    });

    testWidgets('follows the order when a plate is moved', (tester) async {
      final apps = _apps(3);
      final category = _category(apps);
      await _pumpRow(tester, category);

      _service.reorderApplication(category, 0, 2);
      await tester.pump();

      expect(_rectOf(tester, _plate('com.example.app1')).left, 100);
      expect(_rectOf(tester, _plate('com.example.app2')).left, 254);
      expect(_rectOf(tester, _plate('com.example.app0')).left, 408);
      expect(_rectOf(tester, _all).left, 562);
    });
  });
}
