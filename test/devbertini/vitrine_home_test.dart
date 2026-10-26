import 'package:flauncher/custom_traversal_policy.dart';
import 'package:flauncher/devbertini/brand.dart';
import 'package:flauncher/devbertini/cinematic.dart';
import 'package:flauncher/devbertini/profile_model.dart';
import 'package:flauncher/devbertini/vitrine/app_row.dart';
import 'package:flauncher/devbertini/vitrine/apps_page.dart';
import 'package:flauncher/devbertini/vitrine/continue_cards.dart';
import 'package:flauncher/devbertini/vitrine/hero.dart';
import 'package:flauncher/devbertini/vitrine/home.dart';
import 'package:flauncher/devbertini/vitrine/plate.dart';
import 'package:flauncher/devbertini/vitrine/rail.dart';
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
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

WatchNextProgram _program(int id, String package, {String title = 'Program', int position = 600000}) =>
    WatchNextProgram(
      id: id,
      packageName: package,
      title: '$title $id',
      description: 'A synopsis.',
      watchNextType: 0,
      lastEngagementTime: 1000 - id,
      playbackPosition: position,
      duration: 3600000,
      intentUri: '',
      posterArtUri: '',
    );

/// Nothing plays: the island reads only the current track.
class _NoMusic extends ChangeNotifier implements NowPlayingService {
  @override
  NowPlaying? get current => null;

  @override
  Uint8List? get art => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _OneProfile extends ChangeNotifier implements ProfilesController {
  final LauncherProfile _main = LauncherProfile(id: mainProfileId, name: 'Bertini', color: 0);

  @override
  List<LauncherProfile> get profiles => [_main];

  @override
  LauncherProfile get current => _main;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('what the home shows', () {
    final apps = [
      fakeApp(packageName: 'a.visible', name: 'Visible'),
      App(packageName: 'b.hidden', name: 'Hidden', version: '1', hidden: true),
    ];

    test('Watch Next newest first, without hidden programs, packages and apps, up to the limit', () {
      final programs = [
        _program(1, 'a.visible'),
        _program(2, 'b.hidden'),
        _program(3, 'c.blocked'),
        _program(4, 'a.visible'),
        _program(5, 'a.visible'),
      ];
      final shown = vitrinePrograms(
        programs: programs,
        hiddenProgramIds: const ['4'],
        hiddenPackages: const ['c.blocked'],
        applications: apps,
        maxItems: 0,
      );
      expect(shown.map((p) => p.id), [1, 5]);
      expect(
        vitrinePrograms(
          programs: programs,
          hiddenProgramIds: const [],
          hiddenPackages: const [],
          applications: apps,
          maxItems: 2,
        ).map((p) => p.id),
        [1, 3],
      );
    });

    test('the Apps row is the first category with apps', () {
      final empty = fakeCategory(name: 'Empty', order: 0);
      final main = fakeCategory(name: 'Main', order: 1)..applications.add(apps.first);
      final other = fakeCategory(name: 'Other', order: 2)..applications.add(apps.first);
      expect(vitrineMainCategory([empty, main, other]), same(main));
      expect(vitrineMainCategory([empty]), isNull);
    });
  });

  group('the home', () {
    late MockAppsService appsService;
    late MockSettingsService settings;
    late MockWatchNextService watchNext;
    late MockTvInputsService inputs;
    late MockNotificationsService notifications;
    late Category main;
    late List<App> mainApps;

    setUp(() {
      appsService = MockAppsService();
      settings = MockSettingsService();
      watchNext = MockWatchNextService();
      inputs = MockTvInputsService();
      notifications = MockNotificationsService();
      mainApps = [
        for (var i = 1; i <= 8; i++) fakeApp(packageName: 'app.number$i', name: 'App $i'),
        fakeApp(packageName: spotifyPackage, name: 'Spotify'),
      ];
      main = fakeCategory(name: 'Main', order: 0, type: CategoryType.row)..applications.addAll(mainApps);
      when(appsService.initialized).thenReturn(true);
      when(appsService.launcherSections).thenReturn([main]);
      when(appsService.applications).thenReturn(mainApps);
      when(appsService.cachedBanner(any)).thenReturn(null);
      when(appsService.cachedIcon(any)).thenReturn(null);
      when(appsService.getAppBanner(any)).thenAnswer((_) async => Uint8List(0));
      when(appsService.pendingReorderFocusPackage).thenReturn(null);
      when(appsService.getApp(any)).thenAnswer(
          (call) => mainApps.where((app) => app.packageName == call.positionalArguments.first).firstOrNull);
      when(appsService.launchApp(any)).thenAnswer((_) async {});
      when(settings.themes).thenReturn(devBertiniTheme);
      when(settings.timeFormat).thenReturn(SettingsService.defaultTimeFormat);
      when(settings.showContinueWatching).thenReturn(true);
      when(settings.hiddenWatchNextProgramIds).thenReturn(const []);
      when(settings.hiddenWatchNextPackages).thenReturn(const []);
      when(settings.continueWatchingMaxItems).thenReturn(15);
      when(watchNext.hasPermission).thenReturn(true);
      when(inputs.hasInputs).thenReturn(true);
      when(inputs.devices).thenReturn(const []);
      when(notifications.hasPermission).thenReturn(true);
      when(notifications.notifications).thenReturn(const []);
    });

    Future<void> pump(WidgetTester tester, {List<WatchNextProgram> programs = const []}) async {
      when(watchNext.programs).thenReturn(programs);
      // A fresh tree each time: the mocks do not notify, so a second pump would keep the first one's state.
      await tester.pumpWidget(const SizedBox());
      await tester.binding.setSurfaceSize(const Size(960, 540));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AppsService>.value(value: appsService),
          ChangeNotifierProvider<SettingsService>.value(value: settings),
          ChangeNotifierProvider<WatchNextService>.value(value: watchNext),
          ChangeNotifierProvider<TvInputsService>.value(value: inputs),
          ChangeNotifierProvider<NotificationsService>.value(value: notifications),
          ChangeNotifierProvider<NowPlayingService>.value(value: _NoMusic()),
          ChangeNotifierProvider<ProfilesController>.value(value: _OneProfile()),
          ChangeNotifierProvider(create: (_) => LauncherState()),
        ],
        child: MaterialApp(
          locale: const Locale('pt', 'BR'),
          supportedLocales: const [Locale('pt', 'BR'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) =>
              VitrineTheme(tokens: VitrineTokens.dark(CinematicPalette.devBertini), child: child!),
          // As FLauncher puts it: on no Scaffold, inside its row-by-row traversal.
          home: FocusTraversalGroup(policy: RowByRowTraversalPolicy(), child: const VitrineHome()),
        ),
      ));
      await tester.pumpAndSettle();
    }

    Future<void> settleLaunch(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 5));
      devBertiniLaunching.value = false;
    }

    testWidgets('with Watch Next: the hero at 100,50, Apps at y 232, Continuar assistindo at y 386', (tester) async {
      await pump(tester, programs: [_program(1, 'app.number1'), _program(2, 'app.number2'), _program(3, 'app.number3')]);
      expect(tester.getTopLeft(find.byType(VitrineHeroInfo)), const Offset(100, 50));
      expect(tester.getTopLeft(find.byType(VitrineAppRow)), const Offset(100, 232));
      expect(tester.getTopLeft(find.byType(VitrinePlate).first), const Offset(100, 259));
      expect(tester.getTopLeft(find.byType(VitrineContinueRow)), const Offset(100, 386));
      // The hero is the newest program; the row holds the rest.
      expect(find.text('Program 1'), findsOneWidget);
      expect(find.byType(VitrineContinueCard), findsNWidgets(2));
    });

    testWidgets('on no Scaffold, as FLauncher mounts it, no text takes the yellow underline', (tester) async {
      await pump(tester, programs: [_program(1, 'app.number1'), _program(2, 'app.number2')]);
      final underlined = tester
          .widgetList<RichText>(find.byType(RichText))
          .where((text) => text.text.style?.decoration == TextDecoration.underline)
          .map((text) => text.text.toPlainText())
          .toList();
      expect(underlined, isEmpty);
    });

    testWidgets('one program: the hero only; none: no hero and the Apps row moves up', (tester) async {
      await pump(tester, programs: [_program(1, 'app.number1')]);
      expect(find.byType(VitrineHeroInfo), findsOneWidget);
      expect(find.byType(VitrineContinueRow), findsNothing);
      await pump(tester);
      expect(find.byType(VitrineHeroInfo), findsNothing);
      expect(tester.getTopLeft(find.byType(VitrineAppRow)).dy, vitrineAppsTopAlone);
    });

    testWidgets('Continuar assistindo turned off hides the hero and the row', (tester) async {
      when(settings.showContinueWatching).thenReturn(false);
      await pump(tester, programs: [_program(1, 'app.number1'), _program(2, 'app.number2')]);
      expect(find.byType(VitrineHeroInfo), findsNothing);
      expect(find.byType(VitrineContinueRow), findsNothing);
    });

    testWidgets('the first plate has the focus; Left opens the rail on Início; Right puts the focus back', (tester) async {
      await pump(tester, programs: [_program(1, 'app.number1')]);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'vitrine first plate');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'vitrine-rail-home');
      expect(tester.getSize(find.byKey(const ValueKey('vitrine-rail'))).width, greaterThan(VitrineRail.collapsedWidth));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'vitrine first plate');
      expect(tester.getSize(find.byKey(const ValueKey('vitrine-rail'))).width, VitrineRail.collapsedWidth);
    });

    testWidgets('Up and Down move between Continuar, the Apps row and Continuar assistindo, never into the rail',
        (tester) async {
      await pump(tester, programs: [_program(1, 'app.number1'), _program(2, 'app.number2'), _program(3, 'app.number3')]);
      String? focused() => FocusManager.instance.primaryFocus?.debugLabel;
      expect(focused(), 'vitrine first plate');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(focused(), 'vitrine first card');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(focused(), 'vitrine first plate');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(focused(), 'vitrine resume');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(focused(), 'vitrine first plate');
      // From the plates further along the row too.
      for (var i = 0; i < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(focused(), isNot(startsWith('vitrine-rail')));
      expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<VitrineContinueCard>(), isNotNull);
      expect(tester.getSize(find.byKey(const ValueKey('vitrine-rail'))).width, VitrineRail.collapsedWidth);
    });

    testWidgets('Left from Continuar opens the rail on Início', (tester) async {
      await pump(tester, programs: [_program(1, 'app.number1')]);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'vitrine resume');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'vitrine-rail-home');
    });

    testWidgets('Música with nothing playing opens Spotify', (tester) async {
      await pump(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
      }
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'vitrine-rail-music');
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      verify(appsService.launchApp(mainApps.last)).called(1);
      await settleLaunch(tester);
    });

    double railWidth(WidgetTester tester) => tester.getSize(find.byKey(const ValueKey('vitrine-rail'))).width;

    // Read under a page too, which keeps the home built but offstage.
    ScrollPosition appRow(WidgetTester tester) => tester
        .state<ScrollableState>(find
            .descendant(
              of: find.byType(VitrineAppRow, skipOffstage: false),
              matching: find.byType(Scrollable, skipOffstage: false),
              skipOffstage: false,
            )
            .first)
        .position;

    /// Home pressed inside an app, in Android's order: the home stopped (paused), Home reaching it before it resumes,
    /// then the first frame it draws back.
    Future<void> homeFromAnApp(WidgetTester tester) async {
      for (final state in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      devBertiniHomeAgain.press();
      await tester.idle();
      for (final state in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump();
    }

    testWidgets('Home closes the rail and any panel at once and puts the focus on the first plate', (tester) async {
      await pump(tester, programs: [_program(1, 'app.number1')]);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'vitrine-rail-home');
      showDialog<void>(context: tester.element(find.byType(VitrineHome)), builder: (_) => const Text('a panel'));
      await tester.pumpAndSettle();
      expect(find.text('a panel'), findsOneWidget);

      devBertiniHomeAgain.press();
      await tester.pump();
      expect(find.text('a panel'), findsNothing);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'vitrine first plate');
      expect(railWidth(tester), VitrineRail.collapsedWidth);
    });

    testWidgets('Home from an app opened from the rail: the first frame back shows the rail closed', (tester) async {
      await pump(tester, programs: [_program(1, 'app.number1')]);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(railWidth(tester), greaterThan(VitrineRail.collapsedWidth));

      await homeFromAnApp(tester);
      expect(railWidth(tester), VitrineRail.collapsedWidth, reason: 'closed already, not closing');
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'vitrine first plate');
    });

    testWidgets('Home from an app opened from Todos: the first frame back has no page and the row at its start',
        (tester) async {
      await pump(tester);
      for (var i = 0; i < mainApps.length; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump(const Duration(milliseconds: 80));
      }
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(find.byType(VitrineAppsPage), findsOneWidget);
      expect(appRow(tester).pixels, greaterThan(0));

      await homeFromAnApp(tester);
      expect(find.byType(VitrineAppsPage), findsNothing, reason: 'gone already, not fading out');
      expect(appRow(tester).pixels, 0, reason: 'back at its start already, not scrolling');
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'vitrine first plate');
    });

    testWidgets('a second after it shows, the home paints an open rail once under the field, then drops it',
        (tester) async {
      await pump(tester);
      Finder warm() => find.byWidgetPredicate((widget) => widget is VitrineRail && widget.warmUp);
      expect(warm(), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      expect(warm(), findsOneWidget);
      final open = tester.getSize(find.descendant(of: warm(), matching: find.byKey(const ValueKey('vitrine-rail'))));
      expect(open.width, greaterThan(VitrineRail.collapsedWidth), reason: 'drawn open');
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'vitrine first plate', reason: 'it takes no focus');
      await tester.pump();
      expect(warm(), findsNothing);
      expect(find.byType(VitrineRail), findsOneWidget);
    });

    testWidgets('the box has no TV item', (tester) async {
      when(inputs.hasInputs).thenReturn(false);
      await pump(tester);
      expect(find.byKey(const ValueKey('vitrine-rail-item-tv')), findsNothing);
      expect(find.byKey(const ValueKey('vitrine-rail-item-music')), findsOneWidget);
    });

    testWidgets('Todos opens every app by category, five plates a line, and Back returns', (tester) async {
      final other = fakeCategory(name: 'Other', order: 1, type: CategoryType.row)
        ..applications.addAll([fakeApp(packageName: 'other.one', name: 'Other one')]);
      final empty = fakeCategory(name: 'Empty', order: 2, type: CategoryType.row);
      when(appsService.launcherSections).thenReturn([main, other, empty]);
      await pump(tester);
      // From the first plate to Todos, at the end of the row, at a held arrow's pace (one press every 80 ms, the row
      // still scrolling): no press is lost on the way.
      for (var i = 0; i < mainApps.length; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump(const Duration(milliseconds: 80));
      }
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(find.byType(VitrineAppsPage), findsOneWidget);
      final page = find.byType(VitrineAppsPage);
      expect(find.descendant(of: page, matching: find.text('Main')), findsOneWidget);
      expect(find.descendant(of: page, matching: find.text('Other')), findsOneWidget);
      expect(find.descendant(of: page, matching: find.text('Empty')), findsNothing);
      final plates = find.descendant(of: page, matching: find.byType(VitrinePlate));
      expect(plates, findsNWidgets(mainApps.length + 1));
      // Five plates on the first line, the sixth below the first.
      expect(tester.getTopLeft(plates.at(4)).dy, tester.getTopLeft(plates.at(0)).dy);
      expect(tester.getTopLeft(plates.at(5)).dx, tester.getTopLeft(plates.at(0)).dx);
      expect(tester.getTopLeft(plates.at(0)).dx, vitrineAppsPageLeft);
      expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<VitrinePlate>()?.app,
          mainApps.first);
      // The remote's Back is Android's back, which pops the page.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(VitrineAppsPage), findsNothing);
    });
  });
}
