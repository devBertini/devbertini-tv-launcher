/*
 * DevBertini theme for LTvLauncher (GPL-3.0, like the rest of this project).
 * Copyright (C) 2026 Claudio Bertini (devBertini)
 */

import 'dart:async';

import 'package:flauncher/devbertini/cinematic.dart';
import 'package:flauncher/devbertini/vitrine/focus.dart';
import 'package:flauncher/devbertini/vitrine/logos.dart';
import 'package:flauncher/devbertini/vitrine/tokens.dart';
import 'package:flauncher/models/watch_next_program.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/watch_next_service.dart';
import 'package:flauncher/widgets/app_card_keys.dart';
import 'package:flauncher/widgets/watch_next_info_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// The Vitrine's "Continuar assistindo" (docs/devbertini/DESIGN-VITRINE.md): the card and the row of cards.

const double _cardWidth = 180;
const double _cardHeight = 93;
const double _cardRadius = 10;
const double _cardGap = 12;

/// The next card shows 90 px past the focused one (the fifth peeks 90 px at rest); [revealInScrollables] keeps this
/// much room, gap included, on both sides of the focused card.
const double _peek = 90 + _cardGap;

/// How long OK is held before it opens the card's options.
const Duration _holdTime = Duration(milliseconds: 500);

/// The ring and the focus scale reach past the card by about 6 px; the list's clip leaves that room.
const double _ringRoom = 8;

// The card is the same in both themes: its art and scrim are dark, its text white.
const Color _cardBase = Color(0xFF1A1D22);
const Color _white = Color(0xFFFFFFFF);
const Color _timeInk = Color(0xFFE3E6EB);
const Color _barTrack = Color(0x47FFFFFF);

/// The painted scrim: the logo reads at the top, the title and the time at the bottom.
const BoxDecoration _scrim = BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x80000000), Color(0x00000000), Color(0x8C000000), Color(0xE0000000)],
    stops: [0.0, 0.34, 0.52, 1.0],
  ),
);

/// One program of Android's Watch Next: its art, the service's logo, its title, the time left and how far it was
/// watched. OK resumes it, holding OK opens its options.
class VitrineContinueCard extends StatefulWidget {
  final WatchNextProgram program;
  final FocusNode? focusNode;

  /// Left pressed on this card, when it is the row's first.
  final VoidCallback? onLeftEdge;

  const VitrineContinueCard({super.key, required this.program, this.focusNode, this.onLeftEdge});

  @override
  State<VitrineContinueCard> createState() => _VitrineContinueCardState();
}

class _VitrineContinueCardState extends State<VitrineContinueCard> {
  bool _focused = false;
  bool _pressed = false;
  bool _held = false;
  Timer? _hold;

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
  }

  void _resume() {
    devBertiniStartLaunch();
    context.read<WatchNextService>().launch(widget.program);
  }

  void _options() {
    final apps = context.read<AppsService?>();
    final watchNext = context.read<WatchNextService?>();
    if (apps == null || watchNext == null) return;
    showDialog<void>(
      context: context,
      builder: (_) => WatchNextInfoPanel(
        program: widget.program,
        watchNextService: watchNext,
        appsService: apps,
        appIconBytes: apps.cachedIcon(widget.program.packageName),
      ),
    );
  }

  void _endPress() {
    _hold?.cancel();
    _hold = null;
    _pressed = false;
    _held = false;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      final onLeftEdge = widget.onLeftEdge;
      if (onLeftEdge == null || event is! KeyDownEvent) return KeyEventResult.ignored;
      onLeftEdge();
      return KeyEventResult.handled;
    }
    if (!AppCardKeys.validationKeys.contains(key)) return KeyEventResult.ignored;
    if (event is KeyDownEvent) {
      _endPress();
      _pressed = true;
      _hold = Timer(_holdTime, () {
        _hold = null;
        if (!mounted || !_pressed) return;
        _held = true;
        _options();
      });
    } else if (event is KeyUpEvent) {
      final resume = _pressed && !_held;
      _endPress();
      if (resume) _resume();
    }
    return KeyEventResult.handled;
  }

  void _onFocusChange(bool focused) {
    setState(() => _focused = focused);
    if (focused) {
      revealInScrollables(context, peek: _peek);
    } else {
      _endPress();
    }
  }

  @override
  Widget build(BuildContext context) {
    final program = widget.program;
    final pt = Localizations.localeOf(context).languageCode == 'pt';
    final minutes = _minutesLeft(program);
    final left = minutes == null ? null : (pt ? '$minutes min restantes' : '$minutes min left');
    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: _onKey,
      onFocusChange: _onFocusChange,
      child: HoverFocus(
        child: GestureDetector(
          onTap: _resume,
          onLongPress: _options,
          child: Semantics(
            button: true,
            focusable: true,
            focused: _focused,
            label: left == null ? program.title : '${program.title}, $left',
            excludeSemantics: true,
            child: SizedBox(
              width: _cardWidth,
              height: _cardHeight,
              child: VitrineFocusFrame(
                focused: _focused,
                radius: _cardRadius,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_cardRadius),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const ColoredBox(color: _cardBase),
                      _CardArt(program: program),
                      const DecoratedBox(decoration: _scrim),
                      Positioned(
                        right: 8,
                        top: 7,
                        child: VitrineLogo(package: program.packageName, height: 15, onBlack: true),
                      ),
                      Positioned(
                        left: 9,
                        right: 9,
                        bottom: 23,
                        child: Text(
                          program.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: vitrineText(13, weight: 600, color: _white, line: 16),
                        ),
                      ),
                      if (left != null)
                        Positioned(
                          left: 9,
                          bottom: 9,
                          child: Text(left, maxLines: 1, style: vitrineText(12, color: _timeInk, line: 14)),
                        ),
                      if (program.duration > 0)
                        Positioned(
                          left: 9,
                          right: 9,
                          bottom: 5,
                          height: 2,
                          child: _ProgressBar(fraction: _fraction(program)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Minutes left of [program], rounded up, or null when its length is unknown or nothing is left.
int? _minutesLeft(WatchNextProgram program) {
  if (program.duration <= 0) return null;
  final left = program.duration - program.playbackPosition;
  if (left <= 0) return null;
  return (left + 59999) ~/ 60000;
}

double _fraction(WatchNextProgram program) =>
    program.duration <= 0 ? 0 : (program.playbackPosition / program.duration).clamp(0.0, 1.0);

/// The card's art: the program's own when it has a web address, the app's banner when it has none or the address
/// fails; nothing (the card's base colour) when there is neither. Decoded at the card's width in device pixels with its
/// own proportions, so covering the card crops it and never scales it up.
class _CardArt extends StatelessWidget {
  final WatchNextProgram program;

  const _CardArt({required this.program});

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2;
    final width = (_cardWidth * scale).round();
    final banner = context.read<AppsService?>()?.cachedBanner(program.packageName);
    final bannerImage = banner == null || banner.isEmpty
        ? null
        : ResizeImage(MemoryImage(banner), width: width);
    final uri = program.posterArtUri;
    final ImageProvider? art = uri.startsWith('http://') || uri.startsWith('https://')
        ? ResizeImage(NetworkImage(uri), width: width)
        : bannerImage;
    if (art == null) return const SizedBox.shrink();
    return Image(
      image: art,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      errorBuilder: (context, error, stackTrace) => bannerImage == null
          ? const SizedBox.shrink()
          : Image(image: bannerImage, fit: BoxFit.cover, gaplessPlayback: true, excludeFromSemantics: true),
    );
  }
}

/// The 2 px bar: white on 28% white, filled to [fraction].
class _ProgressBar extends StatelessWidget {
  final double fraction;

  const _ProgressBar({required this.fraction});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: _barTrack, borderRadius: BorderRadius.circular(2)),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: fraction,
          heightFactor: 1,
          child: DecoratedBox(decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(2))),
        ),
      ),
    );
  }
}

/// The label and the row of cards, 118 px tall (label 17, gap 8, cards 93) and as wide as its parent. The row runs to
/// the screen's edge: the next card peeks there. With no programs it takes no space.
class VitrineContinueRow extends StatelessWidget {
  /// The Watch Next list after the hero's program.
  final List<WatchNextProgram> programs;

  /// The first card's focus node, for the routes the home makes into the row.
  final FocusNode? firstFocusNode;

  /// Left pressed on the first card.
  final VoidCallback? onLeftFromFirst;

  const VitrineContinueRow({super.key, required this.programs, this.firstFocusNode, this.onLeftFromFirst});

  @override
  Widget build(BuildContext context) {
    if (programs.isEmpty) return const SizedBox.shrink();
    final pt = Localizations.localeOf(context).languageCode == 'pt';
    final t = VitrineTheme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            pt ? 'Continuar assistindo' : 'Continue watching',
            style: vitrineText(14, weight: 600, color: t.ink, line: 17, tracking: -0.1),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: _cardHeight,
          child: RepaintBoundary(
            // Clips the cards that scroll out of the row on its left and at the screen's edge, but leaves the room the
            // focus ring and scale need around the first card.
            child: ClipRect(
              clipper: const _RowClip(),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemExtent: _cardWidth + _cardGap,
                // Items built well past the edge: a held arrow then always finds the next one, instead of losing a press
                // while the row is still scrolling to it.
                scrollCacheExtent: const ScrollCacheExtent.pixels(640),
                itemCount: programs.length,
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: false,
                itemBuilder: (context, index) => Align(
                  key: ValueKey(programs[index].id),
                  alignment: Alignment.topLeft,
                  child: VitrineContinueCard(
                    program: programs[index],
                    focusNode: index == 0 ? firstFocusNode : null,
                    onLeftEdge: index == 0 ? onLeftFromFirst : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RowClip extends CustomClipper<Rect> {
  const _RowClip();

  @override
  Rect getClip(Size size) => Rect.fromLTRB(-_ringRoom, -_ringRoom, size.width, size.height + _ringRoom);

  @override
  bool shouldReclip(_RowClip oldClipper) => false;
}
