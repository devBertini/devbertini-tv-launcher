/*
 * DevBertini theme for LTvLauncher (GPL-3.0, like the rest of this project).
 *
 * The Vitrine home's side rail (docs/devbertini/DESIGN-VITRINE.md, "Rail, collapsed" and "Rail, expanded"): the
 * profile's avatar and seven round items, centred vertically. Collapsed it is icons only and paints no background;
 * while the avatar or an item has the focus it opens over the content as an opaque panel with the labels.
 */

import 'dart:math' as math;

import 'package:flauncher/devbertini/cinematic.dart' show HoverFocus;
import 'package:flauncher/devbertini/perf_lab.dart';
import 'package:flauncher/devbertini/profile_model.dart';
import 'package:flauncher/devbertini/vitrine/focus.dart';
import 'package:flauncher/devbertini/vitrine/signature.dart';
import 'package:flauncher/devbertini/vitrine/tokens.dart';
import 'package:flauncher/widgets/app_card_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// Where a rail item goes.
enum VitrineDestination { home, apps, tv, music, notifications, network, settings }

/// Opens the rail from outside: the session calls [open] when Left is pressed on the first item of a row. The rail
/// itself opens and closes with the focus; [isOpen] says whether it has it.
class VitrineRailController extends ChangeNotifier {
  bool _open = false;
  _VitrineRailState? _rail;
  VitrineDestination? _pending;

  /// Whether the avatar or an item of the rail has the focus (the rail is open or opening).
  bool get isOpen => _open;

  /// Moves the focus into the rail, onto [focus] (Início unless said otherwise); the rail opens with it.
  void open([VitrineDestination focus = VitrineDestination.home]) {
    final rail = _rail;
    if (rail == null) {
      _pending = focus;
      return;
    }
    rail._focusDestination(focus);
  }

  /// Draws the rail collapsed from the next frame on, with no closing animation (Home: the home shows its start at
  /// once). The focus is the caller's to move out of the rail.
  void closeNow() => _rail?._animation.value = 0;

  void _attach(_VitrineRailState rail) {
    _rail = rail;
    final pending = _pending;
    if (pending != null) {
      _pending = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_rail == rail && rail.mounted) rail._focusDestination(pending);
      });
    }
  }

  void _detach(_VitrineRailState rail) {
    if (_rail != rail) return;
    _rail = null;
    // The rail is leaving the tree: nobody is left to hear it, so this stays silent.
    _open = false;
  }

  void _setOpen(bool open) {
    if (_open == open) return;
    _open = open;
    notifyListeners();
  }
}

/// The side rail. It is as tall as its parent and 94 px wide collapsed, and widens over the content to the width its
/// labels need while it has the focus. Each part of it sits in the rail's own layer; a focus change rebuilds only the
/// item that gains and the one that loses it.
class VitrineRail extends StatefulWidget {
  final VitrineRailController controller;

  /// Drawn as the selected pill (Início on the home).
  final VitrineDestination selected;

  /// OK on an item.
  final ValueChanged<VitrineDestination> onSelected;

  /// OK on the avatar.
  final VoidCallback onProfile;

  /// Right or Back inside the rail: the session puts the focus back where it was.
  final VoidCallback onClose;

  /// False on the box, which has no TV inputs: the TV item is not there.
  final bool showTv;

  /// Drawn open from the start and never focused: the home paints such a copy once, hidden under the field, so the
  /// real rail's first opening finds its shaders compiled and its labels' glyphs ready (on the TCL that first opening
  /// otherwise took about 30 ms on the raster thread).
  final bool warmUp;

  /// The count on Notificações; 0 shows no badge.
  final int notificationCount;

  const VitrineRail({
    super.key,
    required this.controller,
    required this.selected,
    required this.onSelected,
    required this.onProfile,
    required this.onClose,
    this.showTv = true,
    this.notificationCount = 0,
    this.warmUp = false,
  });

  /// The collapsed rail's width and the space its pills keep from the screen's edge (and, open, from the panel's).
  static const double collapsedWidth = 94;
  static const double sideSpace = 30;

  /// A pill collapsed: its width and height, the gap between pills, the icon and the space around it.
  static const double pillWidth = 34;
  static const double pillHeight = 28;
  static const double pillGap = 3;
  static const double iconSize = 15;
  static const double pillPadding = 9.5;
  static const double labelGap = 10;

  /// The avatar: its size, its place when collapsed and the gap before the name when open.
  static const double avatarSize = 26;
  static const double avatarLeft = 34;
  static const double avatarTop = 30;
  static const double nameGap = 8;

  /// How long the rail takes to open and to close.
  static const Duration duration = Duration(milliseconds: 160);

  @override
  State<VitrineRail> createState() => _VitrineRailState();
}

class _Item {
  final VitrineDestination destination;
  final IconData icon;
  final String pt;
  final String en;

  const _Item(this.destination, this.icon, this.pt, this.en);
}

const List<_Item> _items = [
  _Item(VitrineDestination.home, Icons.home_outlined, 'Início', 'Home'),
  _Item(VitrineDestination.apps, Icons.apps_rounded, 'Apps', 'Apps'),
  _Item(VitrineDestination.tv, Icons.tv_outlined, 'TV', 'TV'),
  _Item(VitrineDestination.music, Icons.music_note_rounded, 'Música', 'Music'),
  _Item(VitrineDestination.notifications, Icons.notifications_outlined, 'Notificações', 'Notifications'),
  _Item(VitrineDestination.network, Icons.wifi_rounded, 'Rede', 'Network'),
  _Item(VitrineDestination.settings, Icons.settings_outlined, 'Configurações', 'Settings'),
];

/// Measures text once per string and style, so the rail's width never costs a layout per frame.
class _TextMeter {
  final Map<String, double> _widths = {};

  double width(String text, TextStyle style) => _widths.putIfAbsent('${style.fontSize}|${style.fontWeight}|$text', () {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: TextDirection.ltr,
          textScaler: TextScaler.noScaling,
          maxLines: 1,
        )..layout();
        final width = painter.width;
        painter.dispose();
        return width;
      });
}

class _VitrineRailState extends State<VitrineRail> with SingleTickerProviderStateMixin {
  late final AnimationController _animation =
      AnimationController(vsync: this, duration: VitrineRail.duration);
  late final Animation<double> _progress = CurvedAnimation(parent: _animation, curve: Curves.easeOutCubic);
  // The rail walks its own items (Up, Down) and is entered only through [VitrineRailController.open]: out of the
  // traversal, so Up and Down on the home's rows never land on a rail item that happens to sit beside them.
  final FocusNode _avatarNode = FocusNode(debugLabel: 'vitrine-rail-avatar', skipTraversal: true);
  final Map<VitrineDestination, FocusNode> _nodes = {
    for (final item in _items)
      item.destination: FocusNode(debugLabel: 'vitrine-rail-${item.destination.name}', skipTraversal: true),
  };
  final _TextMeter _meter = _TextMeter();

  @override
  void initState() {
    super.initState();
    if (widget.warmUp) _animation.value = 1;
    widget.controller._attach(this);
  }

  @override
  void didUpdateWidget(VitrineRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller._detach(this);
      widget.controller._attach(this);
      widget.controller._setOpen(_avatarNode.hasFocus || _nodes.values.any((node) => node.hasFocus));
    }
  }

  @override
  void dispose() {
    widget.controller._detach(this);
    _animation.dispose();
    _avatarNode.dispose();
    for (final node in _nodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  List<_Item> get _visible => [
        for (final item in _items)
          if (widget.showTv || item.destination != VitrineDestination.tv) item,
      ];

  /// The focus order: the avatar, then the items from top to bottom.
  List<FocusNode> get _order => [_avatarNode, for (final item in _visible) _nodes[item.destination]!];

  void _focusDestination(VitrineDestination destination) {
    final shown = destination != VitrineDestination.tv || widget.showTv;
    _nodes[shown ? destination : VitrineDestination.home]!.requestFocus();
  }

  /// The rail opens while it holds the focus and closes when the focus leaves it.
  void _onFocusChange(bool hasFocus) {
    widget.controller._setOpen(hasFocus);
    if (hasFocus) {
      _animation.forward();
    } else {
      _animation.reverse();
    }
  }

  void _move(FocusNode from, int delta) {
    final order = _order;
    final index = order.indexOf(from) + delta;
    if (index >= 0 && index < order.length) order[index].requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final pt = Localizations.maybeLocaleOf(context)?.languageCode == 'pt';
    final visible = _visible;
    final labelStyle = vitrineText(12, weight: 600);
    var widest = 0.0;
    for (final item in visible) {
      widest = math.max(widest, _meter.width(pt ? item.pt : item.en, labelStyle));
    }
    // Every pill is as wide as the widest row needs, in whole logical px; the panel keeps the pills' 30 px on both sides.
    final openPill = VitrineRail.pillPadding * 2 + VitrineRail.iconSize + VitrineRail.labelGap + widest.ceilToDouble();
    final openWidth = openPill + VitrineRail.sideSpace * 2;
    final selected = widget.selected;

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: _onFocusChange,
      child: RepaintBoundary(
        // Its own text style: nothing the home's Material sets (letter spacing, line height) changes the measured labels.
        child: DefaultTextStyle(
          style: const TextStyle(decoration: TextDecoration.none),
          child: AnimatedBuilder(
            animation: _progress,
            builder: (context, _) {
              final v = _progress.value;
              final t = VitrineTheme.of(context);
              final width = _lerp(VitrineRail.collapsedWidth, openWidth, v);
              final pill = _lerp(VitrineRail.pillWidth, openPill, v);
              return Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  key: const ValueKey('vitrine-rail'),
                  width: width,
                  height: double.infinity,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Keyed: the panel comes and goes, and the items below it must keep their state (their focus).
                      if (v > 0 && perfLabShows('rail-panel'))
                        Positioned(
                          key: const ValueKey('vitrine-rail-panel-slot'),
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: _lerp(0, openWidth, v),
                          child: DecoratedBox(
                            key: const ValueKey('vitrine-rail-panel'),
                            decoration: BoxDecoration(
                              color: t.panel,
                              border: Border(right: BorderSide(color: t.panelEdge)),
                              boxShadow: t.panelShadow,
                            ),
                          ),
                        ),
                      Positioned(
                        key: const ValueKey('vitrine-rail-items-slot'),
                        left: VitrineRail.sideSpace,
                        top: 0,
                        bottom: 0,
                        width: pill,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (var i = 0; i < visible.length; i++) ...[
                                if (i > 0) const SizedBox(height: VitrineRail.pillGap),
                                _RailItem(
                                  item: visible[i],
                                  label: pt ? visible[i].pt : visible[i].en,
                                  node: _nodes[visible[i].destination]!,
                                  selected: visible[i].destination == selected,
                                  width: pill,
                                  open: v,
                                  count: visible[i].destination == VitrineDestination.notifications
                                      ? widget.notificationCount
                                      : 0,
                                  onActivate: () => widget.onSelected(visible[i].destination),
                                  onMove: (delta) => _move(_nodes[visible[i].destination]!, delta),
                                  onClose: widget.onClose,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (perfLabShows('rail-profile'))
                        _Profile(
                          key: const ValueKey('vitrine-rail-profile-slot'),
                            node: _avatarNode,
                            meter: _meter,
                            pt: pt,
                            open: v,
                            openWidth: openWidth,
                            nameRoom: openPill - VitrineRail.avatarSize - VitrineRail.nameGap,
                            onActivate: widget.onProfile,
                            onMove: (delta) => _move(_avatarNode, delta),
                            onClose: widget.onClose,
                        ),
                      if (perfLabShows('rail-signature'))
                        Positioned(
                          key: const ValueKey('vitrine-rail-signature-slot'),
                          left: 0,
                          right: 0,
                          bottom: 22,
                          child: VitrineSignature(open: v > 0.5),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// A focus target of the rail, with the keys the remote gives it: Up and Down walk the rail, Left does nothing, Right
/// and Back close it, OK (any of the app's validation keys, on its release) activates. It keeps its own focus state,
/// so a focus change rebuilds this item alone.
class _RailFocusable extends StatefulWidget {
  final FocusNode node;
  final VoidCallback onActivate;
  final ValueChanged<int> onMove;
  final VoidCallback onClose;
  final Widget Function(BuildContext context, bool focused) builder;

  const _RailFocusable({
    required this.node,
    required this.onActivate,
    required this.onMove,
    required this.onClose,
    required this.builder,
  });

  @override
  State<_RailFocusable> createState() => _RailFocusableState();
}

class _RailFocusableState extends State<_RailFocusable> {
  bool _focused = false;
  bool _down = false;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowDown) {
      if (event is! KeyUpEvent) widget.onMove(key == LogicalKeyboardKey.arrowUp ? -1 : 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) return KeyEventResult.handled;
    if (key == LogicalKeyboardKey.arrowRight || AppCardKeys.cancelKeys.contains(key)) {
      if (event is KeyDownEvent) widget.onClose();
      return KeyEventResult.handled;
    }
    if (AppCardKeys.validationKeys.contains(key)) {
      if (event is KeyDownEvent) {
        _down = true;
      } else if (event is KeyUpEvent) {
        if (_down) widget.onActivate();
        _down = false;
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.node,
      onKeyEvent: _onKey,
      onFocusChange: (focused) {
        _down = false;
        setState(() => _focused = focused);
      },
      child: HoverFocus(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onActivate,
          child: widget.builder(context, _focused),
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final _Item item;
  final String label;
  final FocusNode node;
  final bool selected;

  /// The pill's width now, and how open the rail is (0 to 1).
  final double width;
  final double open;
  final int count;
  final VoidCallback onActivate;
  final ValueChanged<int> onMove;
  final VoidCallback onClose;

  const _RailItem({
    required this.item,
    required this.label,
    required this.node,
    required this.selected,
    required this.width,
    required this.open,
    required this.count,
    required this.onActivate,
    required this.onMove,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return _RailFocusable(
      node: node,
      onActivate: onActivate,
      onMove: onMove,
      onClose: onClose,
      builder: (context, focused) {
        final t = VitrineTheme.of(context);
        final lit = focused || selected;
        final iconColor = focused ? t.ink : (selected ? t.accent : t.ink3);
        final labelStyle = vitrineText(12, weight: lit ? 600 : 450, color: lit ? t.ink : t.ink2);
        final pill = SizedBox(
          key: ValueKey('vitrine-rail-item-${item.destination.name}'),
          width: width,
          height: VitrineRail.pillHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: lit ? t.plate : null,
              borderRadius: BorderRadius.circular(VitrineRail.pillHeight / 2),
              // A selected pill keeps its 1 px edge; the focus ring replaces it.
              border: selected && !focused ? Border.all(color: t.plateEdge) : null,
            ),
            child: Stack(
              children: [
                Positioned(
                  left: VitrineRail.pillPadding,
                  top: (VitrineRail.pillHeight - VitrineRail.iconSize) / 2,
                  child: Icon(item.icon, size: VitrineRail.iconSize, color: iconColor),
                ),
                if (perfLabShows('rail-labels'))
                  Positioned(
                    left: VitrineRail.pillPadding + VitrineRail.iconSize + VitrineRail.labelGap,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Text(label,
                          style: labelStyle, maxLines: 1, softWrap: false, textScaler: TextScaler.noScaling),
                    ),
                  ),
              ],
            ),
          ),
        );
        return Semantics(
          label: count > 0 ? '$label, $count' : label,
          button: true,
          selected: selected,
          excludeSemantics: true,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (perfLabShows('rail-frames'))
                VitrineFocusFrame(focused: focused, radius: VitrineRail.pillHeight / 2, scale: 1.05, child: pill)
              else
                pill,
              if (count > 0)
                Positioned(
                  left: VitrineRail.pillPadding + VitrineRail.iconSize / 2,
                  top: -5,
                  child: _Badge(count: count, ring: Color.lerp(t.badgeRing, t.panel, open)!),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The count on Notificações: 15 px high, at least 15 wide, with a 2 px ring in the colour under it.
class _Badge extends StatelessWidget {
  final int count;
  final Color ring;

  const _Badge({required this.count, required this.ring});

  @override
  Widget build(BuildContext context) {
    final t = VitrineTheme.of(context);
    return Container(
      key: const ValueKey('vitrine-rail-badge'),
      constraints: const BoxConstraints(minWidth: 15, minHeight: 15, maxHeight: 15),
      padding: const EdgeInsets.symmetric(horizontal: 3),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.badge,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ring, width: 2, strokeAlign: BorderSide.strokeAlignOutside),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: vitrineText(11, weight: 700, color: t.onBadge),
        maxLines: 1,
        softWrap: false,
        textScaler: TextScaler.noScaling,
      ),
    );
  }
}

/// The avatar of the profile in use (a neutral graphite 'B' when there is none) and, open, its name: the two sit
/// centred together in the panel.
class _Profile extends StatelessWidget {
  final FocusNode node;
  final _TextMeter meter;
  final bool pt;
  final double open;
  final double openWidth;

  /// The width the name may take, so a long name never widens the panel.
  final double nameRoom;
  final VoidCallback onActivate;
  final ValueChanged<int> onMove;
  final VoidCallback onClose;

  const _Profile({
    super.key,
    required this.node,
    required this.meter,
    required this.pt,
    required this.open,
    required this.openWidth,
    required this.nameRoom,
    required this.onActivate,
    required this.onMove,
    required this.onClose,
  });

  static const Color _neutral = Color(0xFF4A525E);

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfilesController?>()?.current;
    final name = profile?.name ?? 'Bertini';
    final initial = profile?.initial ?? 'B';
    final colour = profile?.colour ?? _neutral;
    final style = vitrineText(12, weight: 600);
    final nameWidth = math.min(meter.width(name, style).ceilToDouble(), nameRoom);
    final group = VitrineRail.avatarSize + VitrineRail.nameGap + nameWidth;
    final left = _lerp(VitrineRail.avatarLeft, (openWidth - group) / 2, open);
    return Positioned(
      left: left,
      top: VitrineRail.avatarTop,
      // Its own width: the name may reach past the collapsed rail while it fades in, and never overflows.
      width: open > 0 ? group : VitrineRail.avatarSize,
      height: VitrineRail.avatarSize,
      child: _RailFocusable(
        node: node,
        onActivate: onActivate,
        onMove: onMove,
        onClose: onClose,
        builder: (context, focused) {
          final t = VitrineTheme.of(context);
          return Semantics(
            label: pt ? 'Perfil $name' : 'Profile $name',
            button: true,
            excludeSemantics: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                VitrineFocusFrame(
                  focused: focused,
                  radius: VitrineRail.avatarSize / 2,
                  scale: 1.05,
                  child: Container(
                    key: const ValueKey('vitrine-rail-avatar'),
                    width: VitrineRail.avatarSize,
                    height: VitrineRail.avatarSize,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
                    child: Text(
                      initial,
                      style: vitrineText(12, weight: 600, color: const Color(0xFFFFFFFF)),
                      textScaler: TextScaler.noScaling,
                    ),
                  ),
                ),
                if (open > 0) ...[
                  const SizedBox(width: VitrineRail.nameGap),
                  SizedBox(
                    width: nameWidth,
                    child: Text(
                      name,
                      key: const ValueKey('vitrine-rail-name'),
                      style: style.copyWith(color: t.ink.withValues(alpha: open)),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      textScaler: TextScaler.noScaling,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
