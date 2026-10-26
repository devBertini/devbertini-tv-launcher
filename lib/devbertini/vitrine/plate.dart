/*
 * DevBertini theme for LTvLauncher (GPL-3.0, like the rest of this project).
 * Copyright (C) 2026 Claudio Bertini (devBertini)
 */

import 'dart:async';

import 'package:flauncher/devbertini/cinematic.dart';
import 'package:flauncher/devbertini/vitrine/focus.dart';
import 'package:flauncher/devbertini/vitrine/logos.dart';
import 'package:flauncher/devbertini/vitrine/tokens.dart';
import 'package:flauncher/models/app.dart';
import 'package:flauncher/models/category.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/launcher_state.dart';
import 'package:flauncher/widgets/app_card_keys.dart';
import 'package:flauncher/widgets/application_info_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// The app plates of the Vitrine home (docs/devbertini/DESIGN-VITRINE.md, "Apps"): 140x71, radius 12, the plate colour
/// of the tokens with its 1 px edge, the app's logo centred.
const double vitrinePlateWidth = 140;
const double vitrinePlateHeight = 71;
const double vitrinePlateRadius = 12;

/// The gap between two plates in the row.
const double vitrinePlateGap = 14;

/// How much of the next plate shows beside the focused one: the spec's 90 px of the sixth plate at the row's edge.
const double vitrinePlatePeek = 90;

/// Height of each known brand's logo on its plate, from the spec (Netflix 25, YouTube 21, HBO Max 37, Prime Video 26,
/// Twitch 25, Spotify 26, Google Play 34). An app not listed draws its banner, else its name.
const Map<String, double> vitrinePlateLogoHeights = {
  'com.netflix.ninja': 25,
  'com.google.android.youtube.tv': 21,
  'com.wbd.stream': 37,
  'com.amazon.amazonvideo.livingroom': 26,
  'tv.twitch.android.app': 25,
  'com.spotify.tv.android': 26,
  'com.android.vending': 34,
};

/// How long OK is held before it opens an item's options.
const Duration _holdToOpen = Duration(milliseconds: 500);

/// Scrolls the lists holding [context] just enough to show the plate, with the next one peeking. The margin is the
/// gap plus the peek, because [revealInScrollables] measures from the focused plate's own edge.
void _revealPlate(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.attached || !box.hasSize) return;
  revealInScrollables(context, peek: vitrinePlateGap + vitrinePlatePeek);
}

/// What a plate is made of: its size, fill and edge, and the focus around it.
class _PlateSurface extends StatelessWidget {
  final bool focused;
  final Widget child;

  const _PlateSurface({required this.focused, required this.child});

  @override
  Widget build(BuildContext context) {
    final t = VitrineTheme.of(context);
    final shape = BorderRadius.circular(vitrinePlateRadius);
    return SizedBox(
      width: vitrinePlateWidth,
      height: vitrinePlateHeight,
      child: VitrineFocusFrame(
        focused: focused,
        radius: vitrinePlateRadius,
        child: DecoratedBox(
          decoration: BoxDecoration(color: t.plate, borderRadius: shape),
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(borderRadius: shape, border: Border.all(color: t.plateEdge)),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

/// An app's plate. OK launches it; holding OK opens its options, whose "Reordenar" puts the plate in the move mode
/// (the arrows move it along the row, OK keeps the place, Back puts it back), as the app cards do.
class VitrinePlate extends StatefulWidget {
  final App app;
  final Category category;
  final FocusNode? focusNode;
  final bool autofocus;

  /// Left pressed on this plate when it is the row's first.
  final VoidCallback? onLeftEdge;

  const VitrinePlate({
    super.key,
    required this.app,
    required this.category,
    this.focusNode,
    this.autofocus = false,
    this.onLeftEdge,
  });

  @override
  State<VitrinePlate> createState() => _VitrinePlateState();
}

class _VitrinePlateState extends State<VitrinePlate> {
  FocusNode? _ownNode;
  bool _focused = false;
  bool _moving = false;
  bool _loadingBanner = false;
  bool _bannerTried = false;
  Timer? _holdTimer;
  bool _pressing = false;
  bool _held = false;
  DateTime? _lastMove;

  FocusNode get _node => widget.focusNode ?? (_ownNode ??= FocusNode(debugLabel: 'VitrinePlate'));

  bool get _knownBrand => vitrinePlateLogoHeights.containsKey(widget.app.packageName);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreMove());
  }

  @override
  void didUpdateWidget(VitrinePlate oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The first plate of the row owns the row's focus node; a plate that moves away from the first place hands it
    // to the plate that takes its place, and takes the focus back with its own.
    if ((_focused || _moving) && oldWidget.focusNode != widget.focusNode) {
      final node = _node;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !node.hasPrimaryFocus) node.requestFocus();
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreMove());
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _ownNode?.dispose();
    super.dispose();
  }

  /// A move that rebuilt the plate (its row came from a new list) keeps going where it left off.
  void _restoreMove() {
    if (!mounted) return;
    final apps = context.read<AppsService>();
    if (apps.pendingReorderFocusPackage != widget.app.packageName ||
        apps.pendingReorderFocusCategoryId != widget.category.id) {
      return;
    }
    apps.clearPendingReorderFocusPackage();
    if (!_node.hasFocus) _node.requestFocus();
    if (!_moving) setState(() => _moving = true);
  }

  void _launch() {
    devBertiniStartLaunch();
    context.read<AppsService>().launchApp(widget.app);
  }

  Future<void> _options() async {
    final apps = context.read<AppsService>();
    final icon = apps.cachedIcon(widget.app.packageName);
    final result = await showDialog<ApplicationInfoPanelResult>(
      context: context,
      builder: (_) => ApplicationInfoPanel(
        category: widget.category,
        application: widget.app,
        applicationIcon: icon == null || icon.isEmpty ? null : MemoryImage(icon),
      ),
    );
    if (!mounted || result != ApplicationInfoPanelResult.reorderApp) return;
    // The OK that chose "Reordenar" is still being released: its key up finds no key down on the plate and is
    // ignored, so it cannot drop the plate at once.
    setState(() => _moving = true);
    _node.requestFocus();
  }

  void _move(int delta) {
    final apps = context.read<AppsService>();
    final list = widget.category.applications;
    final from = list.indexOf(widget.app), to = from + delta;
    if (from < 0 || to < 0 || to >= list.length) return;
    apps.setPendingReorderFocus(widget.app.packageName, widget.category.id, to);
    apps.reorderApplication(widget.category, from, to);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _revealPlate(context);
    });
  }

  void _endMove({required bool keep}) {
    final apps = context.read<AppsService>();
    setState(() => _moving = false);
    if (keep) {
      apps.saveApplicationOrderInCategory(widget.category);
    } else {
      apps.cancelReorderApplication(widget.category);
      context.read<LauncherState?>()?.suppressBackNavigation();
    }
  }

  void _stopPress() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _pressing = false;
    _held = false;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    if (_moving) return _onMovingKey(event, key);
    if (key == LogicalKeyboardKey.arrowLeft && widget.onLeftEdge != null) {
      if (event is KeyDownEvent) widget.onLeftEdge!();
      return KeyEventResult.handled;
    }
    if (AppCardKeys.menuKeys.contains(key)) {
      if (event is KeyDownEvent) _options();
      return KeyEventResult.handled;
    }
    if (!AppCardKeys.validationKeys.contains(key)) return KeyEventResult.ignored;
    if (event is KeyDownEvent) {
      _stopPress();
      _pressing = true;
      _holdTimer = Timer(_holdToOpen, () {
        _holdTimer = null;
        if (!mounted || !_pressing) return;
        _held = true;
        _options();
      });
    } else if (event is KeyUpEvent) {
      final launch = _pressing && !_held;
      _stopPress();
      if (launch) _launch();
    }
    return KeyEventResult.handled;
  }

  KeyEventResult _onMovingKey(KeyEvent event, LogicalKeyboardKey key) {
    if (AppCardKeys.isArrowKey(key)) {
      if (event is KeyUpEvent) return KeyEventResult.handled;
      if (event is KeyRepeatEvent) {
        // A held arrow moves the plate at a pace the row can follow.
        final now = DateTime.now(), last = _lastMove;
        if (last != null && now.difference(last) < const Duration(milliseconds: 50)) return KeyEventResult.handled;
        _lastMove = now;
      }
      if (key == LogicalKeyboardKey.arrowLeft) _move(-1);
      if (key == LogicalKeyboardKey.arrowRight) _move(1);
      return KeyEventResult.handled;
    }
    if (AppCardKeys.validationKeys.contains(key)) {
      if (event is KeyDownEvent) {
        _pressing = true;
      } else if (event is KeyUpEvent) {
        final keep = _pressing;
        _pressing = false;
        if (keep) _endMove(keep: true);
      }
      return KeyEventResult.handled;
    }
    if (AppCardKeys.cancelKeys.contains(key)) {
      if (event is KeyDownEvent) _endMove(keep: false);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _onFocusChange(bool focused) {
    if (!focused) _stopPress();
    if (focused == _focused) return;
    setState(() => _focused = focused);
    if (focused) _revealPlate(context);
  }

  /// The banner of an app whose logo the PC did not put on the device (any app that is not one of the seven brands):
  /// read once when it is not in memory, then drawn from the service's memory.
  void _ensureBanner(AppsService apps) {
    if (_knownBrand || _loadingBanner || _bannerTried) return;
    _loadingBanner = true;
    _bannerTried = true;
    apps.getAppBanner(widget.app.packageName).then<void>((_) {}, onError: (_) {}).whenComplete(() {
      _loadingBanner = false;
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = VitrineTheme.of(context);
    final apps = context.read<AppsService>();
    final banner = context.select<AppsService, Uint8List?>((s) => s.cachedBanner(widget.app.packageName));
    final hasBanner = banner != null && banner.isNotEmpty;
    // Art that goes away later (a custom banner removed) is asked for again.
    if (hasBanner) _bannerTried = false;
    if (!hasBanner && !_knownBrand && !_loadingBanner && !_bannerTried) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ensureBanner(apps);
      });
    }
    final scale = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2;
    final Widget name = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(
        widget.app.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: vitrineText(14, weight: 600, color: t.ink),
      ),
    );
    final Widget art = !hasBanner
        ? name
        : ClipRRect(
            borderRadius: BorderRadius.circular(vitrinePlateRadius - 1),
            child: Image(
              image: ResizeImage(MemoryImage(banner), width: (vitrinePlateWidth * scale).round()),
              width: vitrinePlateWidth,
              height: vitrinePlateHeight,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
              excludeFromSemantics: true,
            ),
          );
    final logoHeight = vitrinePlateLogoHeights[widget.app.packageName];
    final Widget content = logoHeight == null
        ? art
        : VitrineLogo(package: widget.app.packageName, height: logoHeight, fallback: art);
    final pt = Localizations.localeOf(context).languageCode == 'pt';
    return Focus(
      focusNode: _node,
      autofocus: widget.autofocus,
      onKeyEvent: _onKey,
      onFocusChange: _onFocusChange,
      child: HoverFocus(
        child: GestureDetector(
          onTap: _launch,
          onLongPress: _options,
          child: Semantics(
            button: true,
            label: _moving ? '${widget.app.name}, ${pt ? 'movendo' : 'moving'}' : widget.app.name,
            child: ExcludeSemantics(
              child: _PlateSurface(
                focused: _focused,
                child: _moving
                    ? Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(child: Center(child: content)),
                          Positioned(left: 4, child: Icon(Icons.chevron_left_rounded, size: 20, color: t.ink2)),
                          Positioned(right: 4, child: Icon(Icons.chevron_right_rounded, size: 20, color: t.ink2)),
                        ],
                      )
                    : content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The plate at the end of the row that opens every app: the apps icon (22 px) and "Todos" (16 px), OK calls
/// [onPressed].
class VitrineAllPlate extends StatelessWidget {
  final VoidCallback onPressed;
  final FocusNode? focusNode;
  final bool autofocus;

  /// Left pressed on this plate when it is the row's first (a category with no apps).
  final VoidCallback? onLeftEdge;

  const VitrineAllPlate({super.key, required this.onPressed, this.focusNode, this.autofocus = false, this.onLeftEdge});

  @override
  Widget build(BuildContext context) => _AllPlateBody(
        onPressed: onPressed,
        focusNode: focusNode,
        autofocus: autofocus,
        onLeftEdge: onLeftEdge,
      );
}

class _AllPlateBody extends StatefulWidget {
  final VoidCallback onPressed;
  final FocusNode? focusNode;
  final bool autofocus;
  final VoidCallback? onLeftEdge;

  const _AllPlateBody({required this.onPressed, this.focusNode, required this.autofocus, this.onLeftEdge});

  @override
  State<_AllPlateBody> createState() => _AllPlateBodyState();
}

class _AllPlateBodyState extends State<_AllPlateBody> {
  bool _focused = false;
  bool _pressing = false;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft && widget.onLeftEdge != null) {
      if (event is KeyDownEvent) widget.onLeftEdge!();
      return KeyEventResult.handled;
    }
    if (!AppCardKeys.validationKeys.contains(key)) return KeyEventResult.ignored;
    if (event is KeyDownEvent) {
      _pressing = true;
    } else if (event is KeyUpEvent) {
      final fire = _pressing;
      _pressing = false;
      if (fire) widget.onPressed();
    }
    return KeyEventResult.handled;
  }

  void _onFocusChange(bool focused) {
    if (!focused) _pressing = false;
    if (focused == _focused) return;
    setState(() => _focused = focused);
    if (focused) _revealPlate(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = VitrineTheme.of(context);
    final pt = Localizations.localeOf(context).languageCode == 'pt';
    final label = pt ? 'Todos' : 'All';
    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: _onKey,
      onFocusChange: _onFocusChange,
      child: HoverFocus(
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Semantics(
            button: true,
            label: pt ? 'Todos os apps' : 'All apps',
            child: ExcludeSemantics(
              child: _PlateSurface(
                focused: _focused,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.apps_rounded, size: 22, color: t.ink2),
                    const SizedBox(width: 6),
                    Text(label, style: vitrineText(16, weight: 600, color: t.ink2)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
