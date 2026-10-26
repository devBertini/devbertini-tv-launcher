/*
 * DevBertini theme for LTvLauncher (GPL-3.0, like the rest of this project).
 * Copyright (C) 2026 Claudio Bertini (devBertini)
 */

import 'dart:async';

import 'package:flauncher/actions.dart';
import 'package:flauncher/devbertini/cinematic.dart';
import 'package:flauncher/devbertini/cinematic_panels.dart';
import 'package:flauncher/devbertini/now_playing_island.dart';
import 'package:flauncher/devbertini/perf_lab.dart';
import 'package:flauncher/devbertini/profiles_panel.dart';
import 'package:flauncher/devbertini/tv_extras.dart';
import 'package:flauncher/devbertini/vitrine/app_row.dart';
import 'package:flauncher/devbertini/vitrine/apps_page.dart';
import 'package:flauncher/devbertini/vitrine/clock.dart';
import 'package:flauncher/devbertini/vitrine/continue_cards.dart';
import 'package:flauncher/devbertini/vitrine/hero.dart';
import 'package:flauncher/devbertini/vitrine/rail.dart';
import 'package:flauncher/devbertini/vitrine/tokens.dart';
import 'package:flauncher/devbertini/vitrine/tv_panel.dart';
import 'package:flauncher/models/app.dart';
import 'package:flauncher/models/category.dart';
import 'package:flauncher/models/watch_next_program.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/notifications_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/tv_inputs_service.dart';
import 'package:flauncher/providers/watch_next_service.dart';
import 'package:flauncher/widgets/settings/notifications_panel.dart';
import 'package:flauncher/widgets/settings/settings_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// Where the home's parts sit (docs/devbertini/DESIGN-VITRINE.md, "Layout"), in logical px of the 960x540 screen.
const double vitrineContentLeft = 100;
const double vitrineHeroTop = 50;
const double vitrineAppsTop = 232;

/// With no Watch Next item the hero goes and the two rows move up, keeping their distance.
const double vitrineAppsTopAlone = 120;

/// From the Apps label to the Continuar assistindo label.
const double vitrineRowsGap = 154;

/// What Spotify's TV app is called, opened by the rail's Música when nothing plays.
const String spotifyPackage = 'com.spotify.tv.android';

/// The programs the home shows: Android's Watch Next newest first, without the programs and apps hidden in the
/// settings or on the home, and at most [maxItems] of them (0: every one). The first is the hero, the rest the row.
List<WatchNextProgram> vitrinePrograms({
  required List<WatchNextProgram> programs,
  required List<String> hiddenProgramIds,
  required List<String> hiddenPackages,
  required Iterable<App> applications,
  required int maxItems,
}) {
  final hiddenApps = {for (final app in applications) if (app.hidden) app.packageName};
  final shown = programs
      .where((p) =>
          !hiddenProgramIds.contains(p.id.toString()) &&
          !hiddenPackages.contains(p.packageName) &&
          !hiddenApps.contains(p.packageName))
      .toList();
  return maxItems > 0 && shown.length > maxItems ? shown.sublist(0, maxItems) : shown;
}

/// The home's Apps row: the first category with apps, the one the number keys open.
Category? vitrineMainCategory(List<LauncherSection> sections) =>
    sections.whereType<Category>().where((category) => category.applications.isNotEmpty).firstOrNull;

/// The Vitrine home: the field, the newest Watch Next item as the hero, the clock, the Apps row, Continuar
/// assistindo, the side rail, the music island and the signature. Each part keeps its own layer, so a focus moving
/// along a row repaints only the two items it leaves and reaches.
class VitrineHome extends StatefulWidget {
  const VitrineHome({super.key});

  @override
  State<VitrineHome> createState() => _VitrineHomeState();
}

class _VitrineHomeState extends State<VitrineHome> {
  final VitrineRailController _rail = VitrineRailController();
  final FocusNode _firstPlate = FocusNode(debugLabel: 'vitrine first plate');
  final FocusNode _resume = FocusNode(debugLabel: 'vitrine resume');
  final FocusNode _firstCard = FocusNode(debugLabel: 'vitrine first card');
  final GlobalKey _content = GlobalKey(debugLabel: 'vitrine content');

  /// Where Right or Back from the rail puts the focus back: the last item focused in the content.
  FocusNode? _back;

  /// The rail's warm-up: for one frame, a second after the home first shows, an open copy of the rail is painted
  /// hidden under the field ([VitrineRail.warmUp]).
  final VitrineRailController _warmRail = VitrineRailController();
  bool _warmingRail = false;
  Timer? _warmUp;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_remember);
    devBertiniHomeAgain.addListener(_backToStart);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _warmUp = Timer(const Duration(seconds: 1), () {
        if (!mounted) return;
        setState(() => _warmingRail = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _warmingRail = false);
        });
      });
    });
  }

  @override
  void dispose() {
    _warmUp?.cancel();
    devBertiniHomeAgain.removeListener(_backToStart);
    FocusManager.instance.removeListener(_remember);
    _warmRail.dispose();
    _rail.dispose();
    _firstPlate.dispose();
    _resume.dispose();
    _firstCard.dispose();
    super.dispose();
  }

  void _remember() {
    final node = FocusManager.instance.primaryFocus;
    final nodeContext = node?.context;
    final content = _content.currentContext;
    if (node == null || nodeContext == null || content == null || !nodeContext.mounted) return;
    var inside = false;
    nodeContext.visitAncestorElements((element) {
      if (element == content) {
        inside = true;
        return false;
      }
      return true;
    });
    if (inside) _back = node;
  }

  /// Home pressed, from an app or with the home in front: the rail and every page and panel over the home close at
  /// once, with no animation, and the focus goes to the first app (the row jumps back to it while the home is not in
  /// front: [revealInScrollables]). Android pauses the home around every Home, so an animation started here would
  /// only play once the home shows again, over the home it should already show.
  void _backToStart() {
    if (!mounted) return;
    _rail.closeNow();
    final navigator = Navigator.of(context);
    for (var top = _topRoute(navigator); top != null && !top.isFirst; top = _topRoute(navigator)) {
      navigator.removeRoute(top);
    }
    _firstPlate.requestFocus();
  }

  /// The route on top of [navigator]: popUntil only reads it when its test passes at once.
  static Route<dynamic>? _topRoute(NavigatorState navigator) {
    Route<dynamic>? top;
    navigator.popUntil((route) {
      top = route;
      return true;
    });
    return top;
  }

  void _closeRail() {
    final back = _back;
    (back != null && back.context != null && back.canRequestFocus ? back : _firstPlate).requestFocus();
  }

  void _openRail([VitrineDestination focus = VitrineDestination.home]) => _rail.open(focus);

  void _go(VitrineDestination destination) {
    switch (destination) {
      case VitrineDestination.home:
        _firstPlate.requestFocus();
      case VitrineDestination.apps:
        _openApps();
      case VitrineDestination.tv:
        showDialog(context: context, builder: (_) => const VitrineTvPanel());
      case VitrineDestination.music:
        _openMusic();
      case VitrineDestination.notifications:
        showDialog(context: context, builder: (_) => const NotificationsPanel());
      case VitrineDestination.network:
        showDialog(
          context: context,
          barrierColor: VitrineTheme.of(context).dim,
          builder: (_) => const CinematicNetworkPanel(),
        );
      case VitrineDestination.settings:
        showDialog(context: context, builder: (_) => const SettingsPanel());
    }
  }

  void _openApps() => Navigator.of(context).push(PageRouteBuilder(
        pageBuilder: (_, _, _) => const VitrineAppsPage(),
        transitionDuration: const Duration(milliseconds: 160),
        reverseTransitionDuration: const Duration(milliseconds: 120),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
      ));

  /// The player in the island when something plays; Spotify when nothing does and it is installed.
  void _openMusic() {
    if (focusNowPlayingIsland()) return;
    final apps = context.read<AppsService>();
    final spotify = apps.getApp(spotifyPackage);
    if (spotify == null) return;
    devBertiniStartLaunch();
    apps.launchApp(spotify);
  }

  void _openProfiles() => showDialog(
        context: context,
        barrierColor: VitrineTheme.of(context).dim,
        builder: (_) => const CinematicProfilesPanel(),
      );

  @override
  Widget build(BuildContext context) {
    final t = VitrineTheme.of(context);
    final settings = context.watch<SettingsService>();
    final apps = context.watch<AppsService>();
    final watchNext = settings.showContinueWatching ? context.watch<WatchNextService?>() : null;
    final programs = watchNext == null || !watchNext.hasPermission
        ? const <WatchNextProgram>[]
        : vitrinePrograms(
            programs: watchNext.programs,
            hiddenProgramIds: settings.hiddenWatchNextProgramIds,
            hiddenPackages: settings.hiddenWatchNextPackages,
            applications: apps.applications,
            maxItems: settings.continueWatchingMaxItems,
          );
    final hero = programs.firstOrNull;
    final rest = programs.length > 1 ? programs.sublist(1) : const <WatchNextProgram>[];
    final main = vitrineMainCategory(apps.launcherSections);
    final appsTop = hero == null ? vitrineAppsTopAlone : vitrineAppsTop;
    final night = context.select<NightModeService?, bool>((n) => n?.dimmed ?? false);
    final showTv = context.select<TvInputsService?, bool>((inputs) => inputs?.hasInputs ?? false);
    final notifications = context.select<NotificationsService?, int>(
        (service) => service == null || !service.hasPermission ? 0 : service.notifications.length);

    // The home sits on no Scaffold: the transparent Material gives its text the theme's style (without one, Flutter
    // underlines every text in yellow).
    final home = Material(
      type: MaterialType.transparency,
      child: Actions(
      actions: {
        MoveFocusToSettingsIntent: CallbackAction<MoveFocusToSettingsIntent>(
          onInvoke: (_) => _openRail(VitrineDestination.settings),
        ),
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_warmingRail) ...[
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: ExcludeSemantics(
                child: ExcludeFocus(
                  child: IgnorePointer(
                    child: VitrineRail(
                      controller: _warmRail,
                      selected: VitrineDestination.home,
                      onSelected: (_) {},
                      onProfile: () {},
                      onClose: () {},
                      showTv: showTv,
                      notificationCount: notifications,
                      warmUp: true,
                    ),
                  ),
                ),
              ),
            ),
            // Hides the copy where nothing else is painted over it (the dark field without hero art). A column, not the
            // whole screen: Skia can turn a full-screen opaque fill into a clear that drops what was drawn before it.
            Positioned(left: 0, top: 0, bottom: 0, width: 260, child: ColoredBox(color: t.field)),
          ],
          // The field, the hero's art under its fades and, in Modo noite, the art a little darker: one picture.
          VitrineBackdrop(program: hero, night: night),
          KeyedSubtree(
            key: _content,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (hero != null)
                  Positioned(
                    left: vitrineContentLeft,
                    top: vitrineHeroTop,
                    width: 300,
                    // Left from Continuar, the first capsule, opens the rail on Início, as from the rows' first items.
                    child: Focus(
                      canRequestFocus: false,
                      skipTraversal: true,
                      onKeyEvent: (_, event) {
                        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowLeft && _resume.hasPrimaryFocus) {
                          _openRail();
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: RepaintBoundary(child: VitrineHeroInfo(program: hero, resumeFocusNode: _resume)),
                    ),
                  ),
                if (main != null)
                  Positioned(
                    left: vitrineContentLeft,
                    top: appsTop,
                    right: 0,
                    child: VitrineAppRow(
                      category: main,
                      onAll: _openApps,
                      firstFocusNode: _firstPlate,
                      autofocusFirst: true,
                      onLeftFromFirst: _openRail,
                    ),
                  ),
                if (rest.isNotEmpty && perfLabShows('cards'))
                  Positioned(
                    left: vitrineContentLeft,
                    top: appsTop + vitrineRowsGap,
                    right: 0,
                    child: VitrineContinueRow(programs: rest, firstFocusNode: _firstCard, onLeftFromFirst: _openRail),
                  ),
              ],
            ),
          ),
          const Positioned(top: 27, right: 48, child: VitrineClock()),
          // What a TV update undid of the setup, quietly at the bottom of the content, until it is put back.
          Positioned(
            left: vitrineContentLeft,
            bottom: 22,
            child: Selector<TvSetupService?, List<String>>(
              selector: (_, setup) => setup?.problems ?? const [],
              builder: (_, problems, _) => problems.isEmpty
                  ? const SizedBox.shrink()
                  : Text(
                      'A TV desfez: ${problems.join(', ')}. No PC: deploy.ps1 -Setup',
                      style: vitrineText(12, weight: 500, color: t.gold),
                    ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: VitrineRail(
              controller: _rail,
              selected: VitrineDestination.home,
              onSelected: _go,
              onProfile: _openProfiles,
              onClose: _closeRail,
              showTv: showTv,
              notificationCount: notifications,
            ),
          ),
          // What plays in the background, centred at the top, as today.
          const Positioned(top: 24, left: 0, right: 0, child: Center(child: RepaintBoundary(child: NowPlayingIsland()))),
          IgnorePointer(
            child: ValueListenableBuilder<bool>(
              valueListenable: devBertiniLaunching,
              builder: (_, launching, _) => AnimatedOpacity(
                opacity: launching ? 1 : 0,
                duration: Duration(milliseconds: launching ? 140 : 0),
                child: const ColoredBox(color: Colors.black, child: SizedBox.expand()),
              ),
            ),
          ),
        ],
      ),
      ),
    );
    // The lab's `semantics` word measures the home without its semantics tree.
    return perfLabShows('semantics') ? home : ExcludeSemantics(child: home);
  }
}
