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


import 'package:flauncher/actions.dart';
import 'package:flauncher/custom_traversal_policy.dart';
import 'package:flauncher/devbertini/brand.dart';
import 'package:flauncher/devbertini/cinematic.dart';
import 'package:flauncher/devbertini/vitrine/home.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/launcher_state.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/widgets/apps_grid.dart';
import 'package:flauncher/widgets/category_row.dart';
import 'package:flauncher/widgets/launcher_alternative_view.dart';
import 'package:flauncher/widgets/focus_aware_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flauncher/widgets/continue_watching_row.dart';
import 'package:flauncher/providers/watch_next_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/l10n/app_localizations.dart';

import 'models/category.dart';

class FLauncher extends StatefulWidget {
  const FLauncher({super.key});

  @override
  State<FLauncher> createState() => _FLauncherState();
}

class _FLauncherState extends State<FLauncher> with WidgetsBindingObserver {
  final GlobalKey<FocusAwareAppBarState> _appBarKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back on the home after an app: lift the launch fade.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) devBertiniLaunching.value = false;
  }

  @override
  Widget build(BuildContext context) {
    final bool cinematic = context.select<SettingsService, bool>((s) => isCinematicTheme(s.themes));

    return Actions(
    actions: <Type, Action<Intent>>{
      MoveFocusToSettingsIntent: CallbackAction<MoveFocusToSettingsIntent>(
        onInvoke: (_) => _appBarKey.currentState?.focusSettings(),
      ),
    },
    child: Focus(
      // DevBertini: the remote's number keys open the main row's apps, 1 the first one and so on.
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (_, event) => cinematic ? _onNumberKey(event) : KeyEventResult.ignored,
      child: FocusTraversalGroup(
      policy: RowByRowTraversalPolicy(),
      // DevBertini: the cinematic themes are the Vitrine home (docs/devbertini/DESIGN-VITRINE.md).
      child: cinematic ? _launcherVisible(const VitrineHome()) : Stack(
        children: [
          RepaintBoundary(
            child: Consumer<WallpaperService>(
              builder: (_, wallpaperService, _) => _wallpaper(context, wallpaperService)
            ),
          ),
          _launcherVisible(
            Scaffold(
              backgroundColor: Colors.transparent,
              appBar: FocusAwareAppBar(key: _appBarKey),
              body: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Consumer<AppsService>(
                  builder: (context, appsService, _) {
                    if (appsService.initialized) {
                      Widget rowsWith(bool hasContinuingPrograms) =>
                            Selector<SettingsService, ({bool show, int order})>(
                              selector: (_, settings) => (
                                show: settings.showContinueWatching,
                                order: settings.continueWatchingOrder,
                              ),
                              builder: (context, cwSettings, _) => SingleChildScrollView(
                                physics: const ClampingScrollPhysics(),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _sections(
                                      appsService.launcherSections,
                                      continueWatchingActive: cwSettings.show && hasContinuingPrograms,
                                      continueWatchingOrder: cwSettings.order,
                                    ),
                                  ],
                                ),
                              ),
                            );
                      // The continue-watching service (a content observer and a query every few
                      // minutes) is only started when its row is turned on.
                      return Selector<SettingsService, bool>(
                        selector: (_, settings) => settings.showContinueWatching,
                        builder: (context, continueWatchingShown, _) => continueWatchingShown
                            ? Selector<WatchNextService, bool>(
                                selector: (_, watchNext) => watchNext.programs.isNotEmpty,
                                builder: (context, hasContinuingPrograms, _) => rowsWith(hasContinuingPrograms),
                              )
                            : rowsWith(false),
                      );
                    }
                    else {
                      return _emptyState(context);
                    }
                  }
                )
              )
            ),
          ),
        ]
      )
    ),
    ),
  );
  }

  /// [child], or the alternative view while the launcher is set to hide its home.
  Widget _launcherVisible(Widget child) => Consumer<LauncherState>(
        builder: (_, state, child) => Visibility(
          replacement: const Center(child: AlternativeLauncherView()),
          visible: state.launcherVisible,
          child: child!,
        ),
        child: child,
      );

  static const List<LogicalKeyboardKey> _numberKeys = [
    LogicalKeyboardKey.digit1, LogicalKeyboardKey.digit2, LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4, LogicalKeyboardKey.digit5, LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7, LogicalKeyboardKey.digit8, LogicalKeyboardKey.digit9,
  ];
  static const List<LogicalKeyboardKey> _numpadKeys = [
    LogicalKeyboardKey.numpad1, LogicalKeyboardKey.numpad2, LogicalKeyboardKey.numpad3,
    LogicalKeyboardKey.numpad4, LogicalKeyboardKey.numpad5, LogicalKeyboardKey.numpad6,
    LogicalKeyboardKey.numpad7, LogicalKeyboardKey.numpad8, LogicalKeyboardKey.numpad9,
  ];

  /// 1 to 9 open the main row's apps in their order; numbers past the row's end do nothing.
  KeyEventResult _onNumberKey(KeyEvent event) {
    var index = _numberKeys.indexOf(event.logicalKey);
    if (index < 0) index = _numpadKeys.indexOf(event.logicalKey);
    if (index < 0) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.handled;
    final appsService = context.read<AppsService>();
    final mainRow = appsService.launcherSections.whereType<Category>().where((c) => c.applications.isNotEmpty).firstOrNull;
    if (mainRow == null || index >= mainRow.applications.length) return KeyEventResult.handled;
    devBertiniStartLaunch();
    appsService.launchApp(mainRow.applications[index]);
    return KeyEventResult.handled;
  }

  Widget _sections(
    List<LauncherSection> sections, {
    bool continueWatchingActive = false,
    int continueWatchingOrder = 0,
  }) {
    List<Widget> children = [];
    bool firstCategoryFound = false;
    bool cwInserted = false;

    int sectionIdx = 0;
    for (var section in sections) {
      if (continueWatchingActive && !cwInserted && sectionIdx == continueWatchingOrder) {
        final bool isFirstSection = !firstCategoryFound;
        children.add(ContinueWatchingRow(isFirstSection: isFirstSection));
        cwInserted = true;
        firstCategoryFound = true;
      }

      final Key sectionKey = Key(section.id.toString());

      if (section is LauncherSpacer) {
        children.add(SizedBox(key: sectionKey, height: section.height.toDouble()));
        sectionIdx++;
        continue;
      }

      Category category = section as Category;
      Widget categoryWidget;

      // Pass isFirstSection only to the first category found
      bool isFirstSection = !firstCategoryFound;
      if (isFirstSection) firstCategoryFound = true;

      switch (category.type) {
        case CategoryType.row:
          categoryWidget = CategoryRow(
              key: sectionKey,
              category: category,
              applications: category.applications,
              isFirstSection: isFirstSection
          );
          break;
        case CategoryType.grid:
          categoryWidget = AppsGrid(
              key: sectionKey,
              category: category,
              applications: category.applications,
              isFirstSection: isFirstSection
          );
          break;
      }

      children.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: categoryWidget
      ));
      sectionIdx++;
    }

    if (continueWatchingActive && !cwInserted) {
      final bool isFirstSection = !firstCategoryFound;
      children.add(ContinueWatchingRow(isFirstSection: isFirstSection));
      cwInserted = true;
      firstCategoryFound = true;
    }

    return Column(children: children);
  }

  Widget _wallpaper(BuildContext context, WallpaperService wallpaperService) {
    Widget background;
    if (wallpaperService.wallpaper != null) {
      final physicalSize = MediaQuery.sizeOf(context);
      background = Image(
        image: wallpaperService.wallpaper!,
        key: Key("background_${wallpaperService.version}"),
        fit: BoxFit.cover,
        height: physicalSize.height,
        width: physicalSize.width
      );
    }
    else {
      background = Container(key: const Key("background"), decoration: BoxDecoration(gradient: wallpaperService.gradient.gradient));
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        background,
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.35),
                Colors.black.withValues(alpha: 0.15),
                Colors.black.withValues(alpha: 0.45),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyState(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(localizations.loading, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}
