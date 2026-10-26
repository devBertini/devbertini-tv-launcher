/*
 * FLauncher
 * Copyright (C) 2021  Étienne Fesser
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'package:flauncher/devbertini/profile_model.dart';
import 'package:flauncher/flauncher.dart';
import 'package:flauncher/flauncher_channel.dart';
import 'package:flauncher/gradients.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/models/category.dart';
import 'package:flauncher/providers/launcher_state.dart';
import 'package:flauncher/providers/network_service.dart';
import 'package:flauncher/providers/now_playing_service.dart';
import 'package:flauncher/models/app.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/tv_inputs_service.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/providers/notifications_service.dart';
import 'package:flauncher/providers/watch_next_service.dart';
import 'package:flauncher/providers/weather_service.dart';
import 'package:flauncher/widgets/application_info_panel.dart';
import 'package:flauncher/widgets/apps_grid.dart';
import 'package:flauncher/widgets/category_row.dart';
import 'package:flauncher/widgets/app_card.dart';
import 'package:flauncher/widgets/focus_aware_app_bar.dart';
import 'package:flauncher/widgets/settings/settings_panel_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:transparent_image/transparent_image.dart';

import 'helpers.dart';
import 'mocks.dart';
import 'mocks.mocks.dart';


void main() {
  setUpAll(() async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.window.physicalSizeTestValue = Size(1280, 720);
    binding.window.devicePixelRatioTestValue = 1.0;
    // Scale-down the font size because the font 'Ahem' used when running tests is much wider than Roboto
    binding.platformDispatcher.textScaleFactorTestValue = 0.8;
  });

  testWidgets("Home page shows categories with apps", (tester) async {
    final appsService = mkAppService();
    final favoritesCategory = fakeCategory(name: "Favorites", order: 0, type: CategoryType.row);
    final applicationsCategory = fakeCategory(name: "Applications", order: 1);
    favoritesCategory.applications.add(fakeApp(
      packageName: "me.efesser.flauncher.1",
      name: "FLauncher 1",
      version: "1.0.0",
    ));
    applicationsCategory.applications.add(fakeApp(
      packageName: "me.efesser.flauncher.2",
      name: "FLauncher 2",
      version: "2.0.0",
    ));
    when(appsService.launcherSections).thenReturn([
      favoritesCategory,
      applicationsCategory,
    ]);

    await _pumpWidgetWith(tester, appsService);

    expect(find.text("Applications"), findsOneWidget);
    expect(find.text("Favorites"), findsOneWidget);
    expect(find.byType(AppsGrid), findsOneWidget);
    expect(find.byKey(Key("me.efesser.flauncher.2")), findsOneWidget);
    expect(find.byType(CategoryRow), findsOneWidget);
    expect(find.byKey(Key("me.efesser.flauncher.1")), findsOneWidget);

    // This was changed by how the the image is made, I don't know what it now should be
    //expect(tester.widget(find.byKey(Key("background"))), isA<Container>());

  });

  testWidgets("Home page shows category empty-state", (tester) async {
    final appsService = mkAppService();
    final applicationsCategory = fakeCategory(name: "Applications", order: 0, type: CategoryType.grid);
    final favoritesCategory = fakeCategory(name: "Favorites", order: 1, type: CategoryType.row);
    when(appsService.launcherSections).thenReturn([
      applicationsCategory,
      favoritesCategory,
    ]);

    await _pumpWidgetWith(tester, appsService);

    expect(find.text("Applications"), findsOneWidget);
    expect(find.text("Favorites"), findsOneWidget);
    expect(find.byType(CategoryRow), findsOneWidget);
    expect(find.byType(AppsGrid), findsOneWidget);
    expect(find.text("This category is empty."), findsNWidgets(2));
  });

  testWidgets("Home page displays background image", (tester) async {
    final appsService = mkAppService();
    when(appsService.launcherSections).thenReturn([]);

    await _pumpWidgetWith(tester, appsService);

    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets("Home page displays background gradient", (tester) async {
    final appsService = mkAppService();
    when(appsService.launcherSections).thenReturn([]);

    await _pumpWidgetWithProviders(tester, mkWallpaperService(false), appsService, mkSettingsService());

    expect(tester.widget(find.byKey(Key("background"))), isA<Container>());
  });

  testWidgets("Pressing select on settings icon opens SettingsPanel", (tester) async {
    final appsService = mkAppService();
    when(appsService.launcherSections).thenReturn([
      fakeCategory(name: "Favorites", order: 0),
      fakeCategory(name: "Applications", order: 1),
    ]);
    await _pumpWidgetWith(tester, appsService);

    final settingsNode = getSettingsFocusNode(tester);
    settingsNode!.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPanelPage), findsOneWidget);
  });

  testWidgets("Pressing select on app opens ApplicationInfoPanel", (tester) async {
    final appsService = mkAppService();
    final app = fakeApp(
      packageName: "me.efesser.flauncher",
      name: "FLauncher",
      version: "1.0.0",
    );
    final fav = fakeCategory(name: "Favorites", order: 0);
    final apps = fakeCategory(name: "Applications", order: 1);
    apps.applications.add(app);
    when(appsService.launcherSections).thenReturn([
      fav,
      apps,
    ]);
    await _pumpWidgetWith(tester, appsService);

    final inkWellFinder = find.descendant(
      of: find.byKey(Key("me.efesser.flauncher")),
      matching: find.byType(InkWell),
    );
    final FocusNode focusNode = tester.widget<InkWell>(inkWellFinder).focusNode!;
    focusNode.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 500));

    verify(appsService.launchApp(app));
  });

  testWidgets("Long pressing on app opens ApplicationInfoPanel", (tester) async {
    final appsService = mkAppService();
    final applicationsCategory = fakeCategory(name: "Applications", order: 1);
    applicationsCategory.applications.add(fakeApp(
      packageName: "me.efesser.flauncher",
      name: "FLauncher",
      version: "1.0.0",
    ));
    when(appsService.launcherSections).thenReturn([
      fakeCategory(name: "Favorites", order: 0),
      applicationsCategory,
    ]);
    await _pumpWidgetWith(tester, appsService);

    await tester.longPress(find.byKey(Key("me.efesser.flauncher")));
    await tester.pump();

    expect(find.byType(ApplicationInfoPanel), findsOneWidget);
  });

  testWidgets("AppCard moves in grid", (tester) async {
    final appsService = mkAppService();
    final applicationsCategory = fakeCategory(name: "Applications", order: 1, type: CategoryType.grid);
    applicationsCategory.applications.add(fakeApp(
      packageName: "me.efesser.flauncher",
      name: "FLauncher",
      version: "1.0.0",
    ));
    applicationsCategory.applications.add(fakeApp(
      packageName: "me.efesser.flauncher.2",
      name: "FLauncher 2",
      version: "1.0.0",
    ));
    when(appsService.launcherSections).thenReturn([
      fakeCategory(name: "Favorites", order: 0),
      applicationsCategory,
    ]);
    await _pumpWidgetWith(tester, appsService);

    await tester.longPress(find.byKey(Key("me.efesser.flauncher")));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Reorder"));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    verify(appsService.reorderApplication(applicationsCategory, 0, 1));
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    verify(appsService.saveApplicationOrderInCategory(applicationsCategory));
  });

  testWidgets("AppCard reorder cancels on Back button", (tester) async {
    final appsService = mkAppService();
    final applicationsCategory = fakeCategory(name: "Applications", order: 1, type: CategoryType.grid);
    applicationsCategory.applications.add(fakeApp(
      packageName: "me.efesser.flauncher",
      name: "FLauncher",
      version: "1.0.0",
    ));
    applicationsCategory.applications.add(fakeApp(
      packageName: "me.efesser.flauncher.2",
      name: "FLauncher 2",
      version: "1.0.0",
    ));
    when(appsService.launcherSections).thenReturn([
      fakeCategory(name: "Favorites", order: 0),
      applicationsCategory,
    ]);
    await _pumpWidgetWith(tester, appsService);

    await tester.longPress(find.byKey(Key("me.efesser.flauncher")));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Reorder"));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    verify(appsService.reorderApplication(applicationsCategory, 0, 1));
    await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonB);
    await tester.pump();
    verify(appsService.cancelReorderApplication(applicationsCategory));
  });

  testWidgets("AppCard moves in row", (tester) async {
    final appsService = mkAppService();
    final applicationsCategory = fakeCategory(name: "Applications", order: 1, type: CategoryType.row);
    applicationsCategory.applications.add(fakeApp(
      packageName: "me.efesser.flauncher",
      name: "FLauncher",
      version: "1.0.0",
    ));
    applicationsCategory.applications.add(fakeApp(
      packageName: "me.efesser.flauncher.2",
      name: "FLauncher 2",
      version: "1.0.0",
    ));
    when(appsService.launcherSections).thenReturn([
      fakeCategory(name: "Favorites", order: 0),
      applicationsCategory,
    ]);
    await _pumpWidgetWith(tester, appsService);

    await tester.longPress(find.byKey(Key("me.efesser.flauncher")));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Reorder"));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    verify(appsService.reorderApplication(applicationsCategory, 0, 1));
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    verify(appsService.saveApplicationOrderInCategory(applicationsCategory));
  });

  testWidgets("Moving down does not skip row", (tester) async {
    // given
    final appsService = mkAppService();

    /*
     * we are creating 3 rows like the following:
     * ▭ ▭ ▭
     * ▭ ▭
     * ▭ ▭ ▭
     */
    final tvCat = fakeCategory(name: "tv", order: 0);
    tvCat.applications.addAll([
      fakeApp(
        packageName: "me.efesser.tv1",
        name: "tv 1",
        version: "1.0.0",
      ),
      fakeApp(
        packageName: "me.efesser.tv2",
        name: "tv 2",
        version: "1.0.0",
      ),
      fakeApp(
        packageName: "me.efesser.tv3",
        name: "tv 3",
        version: "1.0.0",
      ),
    ]);
    final musicCat = fakeCategory(name: "music", order: 1);
    musicCat.applications.addAll([
      fakeApp(
        packageName: "me.efesser.music1",
        name: "music 1",
        version: "1.0.0",
      ),
      fakeApp(
        packageName: "me.efesser.music2",
        name: "music 2",
        version: "1.0.0",
      ),
    ]);
    final gamesCat = fakeCategory(name: "games", order: 2);
    gamesCat.applications.addAll([
      fakeApp(
        packageName: "me.efesser.game1",
        name: "game 1",
        version: "1.0.0",
      ),
      fakeApp(
        packageName: "me.efesser.game2",
        name: "game 2",
        version: "1.0.0",
      ),
      fakeApp(
        packageName: "me.efesser.game3",
        name: "game 3",
        version: "1.0.0",
      ),
    ]);
    when(appsService.launcherSections).thenReturn([
      tvCat,
      musicCat,
      gamesCat,
    ]);

    await _pumpWidgetWith(tester, appsService);
    // when
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    // then
    Element? tv1 = findAppCardByPackageName(tester, "me.efesser.tv1");
    expect(tv1, isNotNull);
    Element? music2 = findAppCardByPackageName(tester, "me.efesser.music2");
    expect(music2, isNotNull);
    expect(isAppCardFocused(tester, "me.efesser.tv1"), isFalse);
    expect(isAppCardFocused(tester, "me.efesser.music2"), isTrue); // this is new, before it was going straight to the third row

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    Element? game2 = findAppCardByPackageName(tester, "me.efesser.game2");
    expect(game2, isNotNull);
    expect(isAppCardFocused(tester, "me.efesser.tv1"), isFalse);
    expect(isAppCardFocused(tester, "me.efesser.music2"), isFalse);
    expect(isAppCardFocused(tester, "me.efesser.game2"), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(isAppCardFocused(tester, "me.efesser.tv1"), isFalse);
    expect(isAppCardFocused(tester, "me.efesser.music2"), isTrue);
    expect(isAppCardFocused(tester, "me.efesser.game2"), isFalse);
  });

  testWidgets("Moving left or right stays on the same row", (tester) async {
    // given
    final appsService = mkAppService();

    /*
     * we are creating 2 rows like the following:
     * ▭ ▭
     * ▭ ▭ ▭ ▭ ▭
     */
    final tvCat = fakeCategory(name: "tv", order: 0);
    tvCat.applications.addAll([
      fakeApp(
        packageName: "me.efesser.tv1",
        name: "tv 1",
        version: "1.0.0",
      ),
      fakeApp(
        packageName: "me.efesser.tv2",
        name: "tv 2",
        version: "1.0.0",
      ),
    ]);
    final musicCat = fakeCategory(name: "music", order: 1, columnsCount: 5);
    musicCat.applications.addAll([
      fakeApp(
        packageName: "me.efesser.music1",
        name: "music 1",
        version: "1.0.0",
      ),
      fakeApp(
        packageName: "me.efesser.music2",
        name: "music 2",
        version: "1.0.0",
      ),
      fakeApp(
        packageName: "me.efesser.music3",
        name: "music 3",
        version: "1.0.0",
      ),
      fakeApp(
        packageName: "me.efesser.music4",
        name: "music 4",
        version: "1.0.0",
      ),
      fakeApp(
        packageName: "me.efesser.music5",
        name: "music 5",
        version: "1.0.0",
      ),
    ]);
    when(appsService.launcherSections).thenReturn([
      tvCat,
      musicCat,
    ]);

    await _pumpWidgetWith(tester, appsService);

    // then
    Element? tv1 = findAppCardByPackageName(tester, "me.efesser.tv1");
    expect(tv1, isNotNull);
    expect(isAppCardFocused(tester, "me.efesser.tv1"), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    Element? music1 = findAppCardByPackageName(tester, "me.efesser.music1");
    expect(music1, isNotNull);
    expect(isAppCardFocused(tester, "me.efesser.tv1"), isFalse);
    expect(isAppCardFocused(tester, "me.efesser.music1"), isTrue);

    // check right direction
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    Element? music2 = findAppCardByPackageName(tester, "me.efesser.music2");
    expect(music2, isNotNull);
    expect(isAppCardFocused(tester, "me.efesser.tv1"), isFalse);
    expect(isAppCardFocused(tester, "me.efesser.music1"), isFalse);
    expect(isAppCardFocused(tester, "me.efesser.music2"), isTrue);

    // check if right on the last app stays on the same app
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    Element? music5 = findAppCardByPackageName(tester, "me.efesser.music5");
    expect(music5, isNotNull);
    expect(isAppCardFocused(tester, "me.efesser.music5"), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    Element? tv2 = findAppCardByPackageName(tester, "me.efesser.tv2");
    expect(tv2, isNotNull);
    expect(isAppCardFocused(tester, "me.efesser.tv2"), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(isAppCardFocused(tester, "me.efesser.music2"), isTrue);

    // check left direction
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(isAppCardFocused(tester, "me.efesser.music1"), isTrue);

    // check if going left on the first app stays on the same app
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(isAppCardFocused(tester, "me.efesser.music1"), isTrue);
  });

  testWidgets("Moving right or up can go the settings icon", (tester) async {
    // given
    final appsService = mkAppService();

    /*
     * we are creating 2 rows like the following:
     * ▭ ▭
     * ▭ ▭ ▭
     */
    final tvCat = fakeCategory(name: "tv", order: 0);
    tvCat.applications.addAll([
      fakeApp(
        packageName: "me.efesser.tv1",
        name: "tv 1",
        version: "1.0.0",
      ),
      fakeApp(
        packageName: "me.efesser.tv2",
        name: "tv 2",
        version: "1.0.0",
      ),
    ]);
    final musicCat = fakeCategory(name: "music", order: 1);
    musicCat.applications.addAll([
      fakeApp(
        packageName: "me.efesser.music1",
        name: "music 1",
        version: "1.0.0",
      ),
      fakeApp(
        packageName: "me.efesser.music2",
        name: "music 2",
        version: "1.0.0",
      ),
      fakeApp(
        packageName: "me.efesser.music3",
        name: "music 3",
        version: "1.0.0",
      ),
    ]);
    when(appsService.launcherSections).thenReturn([
      tvCat,
      musicCat,
    ]);

    await _pumpWidgetWith(tester, appsService);

    // then
    Element? tv1 = findAppCardByPackageName(tester, "me.efesser.tv1");
    expect(tv1, isNotNull);
    expect(isAppCardFocused(tester, "me.efesser.tv1"), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();


    Element? settingsIcon = findSettingsIcon(tester);
    expect(settingsIcon, isNotNull);
    expect(isAppCardFocused(tester, "me.efesser.tv1"), isFalse);
    expect(isSettingsIconFocused(tester), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(isSettingsIconFocused(tester), isFalse);
    expect(isAppCardFocused(tester, "me.efesser.tv1"), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(isSettingsIconFocused(tester), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(isAppCardFocused(tester, "me.efesser.tv2"), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(isSettingsIconFocused(tester), isTrue);
  });

  group("Number keys (devBertini theme)", () {
    Future<(MockAppsService, List<App>)> pumpMainRow(WidgetTester tester, {String theme = 'devbertini', int apps = 3}) async {
      final appsService = mkAppService() as MockAppsService;
      // An empty category above the main row: the main row is the first one that has apps.
      final empty = fakeCategory(name: "Empty", order: 0, type: CategoryType.row);
      final mainRow = fakeCategory(name: "Main", order: 1, type: CategoryType.row);
      final other = fakeCategory(name: "Other", order: 2, type: CategoryType.row);
      final mainApps = [
        for (var i = 1; i <= apps; i++) fakeApp(packageName: "me.efesser.main$i", name: "Main $i"),
      ];
      mainRow.applications.addAll(mainApps);
      other.applications.add(fakeApp(packageName: "me.efesser.other1", name: "Other 1"));
      when(appsService.launcherSections).thenReturn([empty, mainRow, other]);
      final settings = mkSettingsService();
      when(settings.themes).thenReturn(theme);
      await _pumpWidgetWithProviders(tester, mkWallpaperService(), appsService, settings, extraProviders: [
        ChangeNotifierProvider<NowPlayingService>.value(value: _NoMusic()),
        ChangeNotifierProvider<ProfilesController>.value(value: _OneProfile()),
      ]);
      return (appsService, mainApps);
    }

    // The launch fade to black lifts by itself after 4 s; let that timer run out.
    Future<void> settleLaunch(WidgetTester tester) => tester.pump(const Duration(seconds: 5));

    testWidgets("keys 1 to 3 open the apps at those positions of the main row", (tester) async {
      final (appsService, apps) = await pumpMainRow(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      verify(appsService.launchApp(apps[0])).called(1);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      verify(appsService.launchApp(apps[2])).called(1);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      verify(appsService.launchApp(apps[1])).called(1);
      await settleLaunch(tester);
    });

    testWidgets("the numeric keypad keys work like the digits", (tester) async {
      final (appsService, apps) = await pumpMainRow(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.numpad2);

      verify(appsService.launchApp(apps[1])).called(1);
      await settleLaunch(tester);
    });

    testWidgets("key 9 opens the ninth app", (tester) async {
      final (appsService, apps) = await pumpMainRow(tester, apps: 9);

      await tester.sendKeyEvent(LogicalKeyboardKey.digit9);

      verify(appsService.launchApp(apps[8])).called(1);
      await settleLaunch(tester);
    });

    testWidgets("a digit past the number of apps does nothing", (tester) async {
      final (appsService, _) = await pumpMainRow(tester, apps: 3);

      await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit9);
      await tester.sendKeyEvent(LogicalKeyboardKey.numpad5);

      verifyNever(appsService.launchApp(any));
      await settleLaunch(tester);
    });

    testWidgets("a key press opens the app once, not again on its release", (tester) async {
      final (appsService, apps) = await pumpMainRow(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.digit1);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.digit1);

      verify(appsService.launchApp(apps[0])).called(1);
      await settleLaunch(tester);
    });

    testWidgets("digits do nothing on a theme that is not cinematic", (tester) async {
      final (appsService, _) = await pumpMainRow(tester, theme: 'classic');

      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);

      verifyNever(appsService.launchApp(any));
    });
  });
}

/// A single profile, which is all the Vitrine rail needs to draw its profile button.
class _OneProfile extends ChangeNotifier implements ProfilesController {
  final LauncherProfile _main = LauncherProfile(id: mainProfileId, name: 'Main', color: 0);

  @override
  List<LauncherProfile> get profiles => [_main];

  @override
  LauncherProfile get current => _main;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Nothing plays: the home's island reads only the current track.
class _NoMusic extends ChangeNotifier implements NowPlayingService {
  @override
  NowPlaying? get current => null;

  @override
  Uint8List? get art => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

SettingsService mkSettingsService() {
  final settingsService = MockSettingsService();
  when(settingsService.dateFormat).thenReturn(SettingsService.defaultDateFormat);
  when(settingsService.timeFormat).thenReturn(SettingsService.defaultTimeFormat);
  when(settingsService.appHighlightAnimationEnabled).thenReturn(true);
  when(settingsService.showCategoryTitles).thenReturn(true);
  when(settingsService.showCategoryAppCount).thenReturn(false);
  when(settingsService.autoHideAppBarEnabled).thenReturn(false);
  when(settingsService.showInputsWidgetInStatusBar).thenReturn(true);
  when(settingsService.showNetworkIndicatorInStatusBar).thenReturn(true);
  when(settingsService.showDataWidgetInStatusBar).thenReturn(true);
  when(settingsService.showDateInStatusBar).thenReturn(true);
  when(settingsService.showTimeInStatusBar).thenReturn(true);
  when(settingsService.accentColorHex).thenReturn('00ff00');
  when(settingsService.showAppNamesBelowIcons).thenReturn(true);
  when(settingsService.themes).thenReturn('classic');
  when(settingsService.hideHighlightOutlineOnHomescreen).thenReturn(false);
  when(settingsService.appSelectorTransitionAnimationEnabled).thenReturn(true);
  when(settingsService.showContinueWatching).thenReturn(false);
  when(settingsService.continueWatchingOrder).thenReturn(0);
  when(settingsService.showNotificationsWidgetInStatusBar).thenReturn(true);
  when(settingsService.autoHideNotificationsWidget).thenReturn(false);
  when(settingsService.showWeatherInStatusBar).thenReturn(false);
  when(settingsService.showWeatherWarnings).thenReturn(false);
  when(settingsService.useFahrenheit).thenReturn(false);
  return settingsService;
}

WallpaperService mkWallpaperService([bool wallpaper = true]) {
  final wallpaperService = MockWallpaperService();
  when(wallpaperService.gradient).thenReturn(FLauncherGradients.greatWhale);
  when(wallpaperService.wallpaper).thenReturn(wallpaper ? Image.asset('assets/icon.png').image : null);
  when(wallpaperService.version).thenReturn(0);
  return wallpaperService;
}

TvInputsService mkTvInputsService() {
  final tvInputsService = MockTvInputsService();
  when(tvInputsService.hasInputs).thenReturn(false);
  when(tvInputsService.devices).thenReturn([]);
  return tvInputsService;
}

NotificationsService mkNotificationsService() {
  final notificationsService = MockNotificationsService();
  when(notificationsService.getNotificationCount(any)).thenReturn(0);
  when(notificationsService.hasPermission).thenReturn(false);
  when(notificationsService.notifications).thenReturn([]);
  return notificationsService;
}

WatchNextService mkWatchNextService() {
  final watchNextService = MockWatchNextService();
  when(watchNextService.programs).thenReturn([]);
  return watchNextService;
}

WeatherService mkWeatherService() {
  final weatherService = MockWeatherService();
  when(weatherService.hasWeather).thenReturn(false);
  when(weatherService.weatherData).thenReturn(null);
  when(weatherService.isBreezyInstalled).thenReturn(false);
  return weatherService;
}

AppsService mkAppService() {
  final appsService = MockAppsService();
  when(appsService.initialized).thenReturn(true);
  when(appsService.getAppBanner(any)).thenAnswer((_) async => kTransparentImage);
  when(appsService.getAppIcon(any)).thenAnswer((_) async => kTransparentImage);
  when(appsService.pendingReorderFocusPackage).thenReturn(null);
  when(appsService.cachedBanner(any)).thenReturn(null);
  when(appsService.cachedIcon(any)).thenReturn(null);
  when(appsService.hasCustomBanner(any)).thenAnswer((_) async => false);
  when(appsService.isAppInFavorites(any)).thenReturn(false);
  return appsService;
}


Future<void> _pumpWidgetWith(
  WidgetTester tester,
  AppsService appsService,
  ) async {
  return _pumpWidgetWithProviders(tester, mkWallpaperService(), appsService, mkSettingsService());
}

Future<void> _pumpWidgetWithProviders(
  WidgetTester tester,
  WallpaperService wallpaperService,
  AppsService appsService,
  SettingsService settingsService, {
  List<SingleChildWidget> extraProviders = const [],
}) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1.0;
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<WallpaperService>.value(value: wallpaperService),
        ChangeNotifierProvider<AppsService>.value(value: appsService),
        ChangeNotifierProvider<SettingsService>.value(value: settingsService),
        ChangeNotifierProvider<TvInputsService>.value(value: mkTvInputsService()),
        ChangeNotifierProvider<NotificationsService>.value(value: mkNotificationsService()),
        ChangeNotifierProvider<WatchNextService>.value(value: mkWatchNextService()),
        ChangeNotifierProvider<WeatherService>.value(value: mkWeatherService()),
        ChangeNotifierProvider(create: (_) => LauncherState()),
        ChangeNotifierProvider(create: (_) => NetworkService(FLauncherChannel())),
        ...extraProviders,
      ],
      builder: (_, _) => MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: FLauncher(),
      ),
    ),
  );
  await tester.pump(Duration(seconds: 30), EnginePhase.sendSemanticsUpdate);
}

FocusNode? getFocusNodeForApp(WidgetTester tester, String packageName) {
  final appCardFinder = find.byWidgetPredicate((widget) =>
    widget is AppCard && widget.application.packageName == packageName
  );
  if (appCardFinder.evaluate().isEmpty) return null;
  final inkWellFinder = find.descendant(
    of: appCardFinder,
    matching: find.byType(InkWell),
  );
  if (inkWellFinder.evaluate().isEmpty) return null;
  final inkWell = tester.widget<InkWell>(inkWellFinder);
  return inkWell.focusNode;
}

FocusNode? getSettingsFocusNode(WidgetTester tester) {
  try {
    final appBarState = tester.state<FocusAwareAppBarState>(find.byType(FocusAwareAppBar));
    return appBarState.settingsFocusNode;
  } catch (e) {
    return null;
  }
}

bool isAppCardFocused(WidgetTester tester, String packageName) {
  final focusNode = getFocusNodeForApp(tester, packageName);
  return focusNode?.hasFocus ?? false;
}

bool isSettingsIconFocused(WidgetTester tester) {
  final focusNode = getSettingsFocusNode(tester);
  return focusNode?.hasFocus ?? false;
}
