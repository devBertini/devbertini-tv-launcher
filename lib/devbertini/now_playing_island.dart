/*
 * DevBertini theme for LTvLauncher (GPL-3.0, like the rest of this project).
 * Copyright (C) 2026 Claudio Bertini (devBertini)
 *
 * What plays in the background, as an island at the top centre of the home: a black pill with the
 * cover, the track and a small level meter, dropping in when music starts and leaving when it ends.
 * Reached with the remote it opens into a player: back, pause or play, forward, and open the app.
 */

import 'dart:async';
import 'dart:math' as math;

import 'package:flauncher/devbertini/brand.dart';
import 'package:flauncher/devbertini/cinematic.dart';
import 'package:flauncher/providers/now_playing_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class NowPlayingIsland extends StatelessWidget {
  const NowPlayingIsland({super.key});

  @override
  Widget build(BuildContext context) {
    final now = context.select<NowPlayingService, NowPlaying?>((service) => service.current);
    // Drops in from the top edge when something starts playing, and goes back up when it stops.
    // The island sits outside the home's Scaffold: the transparent Material gives it the theme's
    // text style (outside any, Flutter draws text in monospace with a yellow underline).
    return Material(
      type: MaterialType.transparency,
      child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 380),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, -0.8), end: Offset.zero).animate(animation),
          child: child,
        ),
      ),
      child: now == null ? const SizedBox.shrink(key: ValueKey('none')) : _Island(key: const ValueKey('island'), now: now),
      ),
    );
  }
}

/// Moves the focus into the island (the rail's Música), which opens it on its play button. False when nothing plays,
/// so there is no island to open.
bool focusNowPlayingIsland() {
  final island = _IslandState._shown;
  if (island == null || !island.mounted) return false;
  island._summary.requestFocus();
  return true;
}

class _Island extends StatefulWidget {
  final NowPlaying now;

  const _Island({super.key, required this.now});

  @override
  State<_Island> createState() => _IslandState();
}

class _IslandState extends State<_Island> {
  /// The island on screen, for [focusNowPlayingIsland]; the home shows one at most.
  static _IslandState? _shown;

  final FocusNode _summary = FocusNode(debugLabel: 'island');
  final FocusNode _play = FocusNode(debugLabel: 'island play');
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _shown = this;
  }

  @override
  void dispose() {
    if (_shown == this) _shown = null;
    _summary.dispose();
    _play.dispose();
    super.dispose();
  }

  void _onFocusInside(bool hasFocus) {
    if (hasFocus == _open) return;
    setState(() => _open = hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<NowPlayingService>();
    final art = context.select<NowPlayingService, dynamic>((s) => s.art);
    final now = widget.now;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: _onFocusInside,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        height: _open ? 76 : 40,
        padding: EdgeInsets.symmetric(horizontal: _open ? 14 : 7),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(_open ? 30 : 20),
          border: Border.all(color: const Color(0x2EFFFFFF)),
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _open
                ? _Player(key: const ValueKey('open'), now: now, art: art, playNode: _play, service: service)
                : _Summary(key: const ValueKey('closed'), now: now, art: art, node: _summary, onFocus: () {
                    // Reaching the island opens it on the play button.
                    setState(() => _open = true);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _play.requestFocus();
                    });
                  }),
          ),
        ),
      ),
    );
  }
}

/// The closed island: cover, track, artist and the level meter.
class _Summary extends StatelessWidget {
  final NowPlaying now;
  final dynamic art;
  final FocusNode node;
  final VoidCallback onFocus;

  const _Summary({super.key, required this.now, required this.art, required this.node, required this.onFocus});

  @override
  Widget build(BuildContext context) {
    final palette = CinematicThemeScope.of(context);
    return Focus(
      focusNode: node,
      onFocusChange: (focused) {
        if (focused) onFocus();
      },
      child: HoverFocus(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Cover(art: art, size: 26, radius: 13),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 230),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: now.title, style: const TextStyle(color: DevBertiniColors.ink, fontWeight: FontWeight.w600)),
                      if (now.artist.isNotEmpty) TextSpan(text: '  ${now.artist}', style: const TextStyle(color: Color(0x99FFFFFF))),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  TrackProgress(playing: now.playing, color: palette.caption),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _Levels(playing: now.playing, color: palette.caption),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

/// The open island: cover, track and artist, then the controls and the app.
class _Player extends StatelessWidget {
  final NowPlaying now;
  final dynamic art;
  final FocusNode playNode;
  final NowPlayingService service;

  const _Player({super.key, required this.now, required this.art, required this.playNode, required this.service});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Cover(art: art, size: 50, radius: 12),
        const SizedBox(width: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(now.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: DevBertiniColors.ink)),
              if (now.artist.isNotEmpty)
                Text(now.artist,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Color(0x99FFFFFF))),
              const SizedBox(height: 6),
              TrackProgress(playing: now.playing, color: CinematicThemeScope.of(context).caption, showRemaining: true),
            ],
          ),
        ),
        const SizedBox(width: 18),
        _IslandButton(icon: Icons.skip_previous_rounded, onPressed: () => service.skip(next: false)),
        const SizedBox(width: 6),
        _IslandButton(
          icon: now.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          size: 48,
          prominent: true,
          focusNode: playNode,
          onPressed: service.playPause,
        ),
        const SizedBox(width: 6),
        _IslandButton(icon: Icons.skip_next_rounded, onPressed: () => service.skip(next: true)),
        const SizedBox(width: 14),
        Container(width: 1, height: 30, color: const Color(0x26FFFFFF)),
        const SizedBox(width: 14),
        _IslandButton(
          icon: Icons.open_in_new_rounded,
          onPressed: () {
            devBertiniStartLaunch();
            service.openApp();
          },
        ),
      ],
    );
  }
}

class _IslandButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final bool prominent;
  final FocusNode? focusNode;

  const _IslandButton({required this.icon, required this.onPressed, this.size = 40, this.prominent = false, this.focusNode});

  @override
  State<_IslandButton> createState() => _IslandButtonState();
}

class _IslandButtonState extends State<_IslandButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final palette = CinematicThemeScope.of(context);
    return Actions(
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onPressed()),
        ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(onInvoke: (_) => widget.onPressed()),
      },
      child: Focus(
        focusNode: widget.focusNode,
        onFocusChange: (focused) => setState(() => _focused = focused),
        child: HoverFocus(
          child: GestureDetector(
            onTap: widget.onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _focused
                    ? palette.focusFill
                    : (widget.prominent ? const Color(0x1FFFFFFF) : Colors.transparent),
              ),
              child: Icon(widget.icon, size: widget.size * 0.56, color: _focused ? palette.focusInk : DevBertiniColors.ink),
            ),
          ),
        ),
      ),
    );
  }
}

/// The track's cover, or a note on a dark disc when the app publishes none.
class _Cover extends StatelessWidget {
  final dynamic art;
  final double size;
  final double radius;

  const _Cover({required this.art, required this.size, required this.radius});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox.square(
        dimension: size,
        child: art == null
            ? ColoredBox(
                color: const Color(0xFF1A1A1A),
                child: Icon(Icons.music_note_rounded, size: size * 0.55, color: const Color(0x99FFFFFF)),
              )
            : Image.memory(art, fit: BoxFit.cover, gaplessPlayback: true, filterQuality: FilterQuality.medium),
      ),
    );
  }
}

/// Three small bars that rise and fall while music plays, still when it is paused.
class _Levels extends StatefulWidget {
  final bool playing;
  final Color color;

  const _Levels({required this.playing, required this.color});

  @override
  State<_Levels> createState() => _LevelsState();
}

class _LevelsState extends State<_Levels> with SingleTickerProviderStateMixin {
  late final AnimationController _beat =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() {
    super.initState();
    if (widget.playing) _beat.repeat();
  }

  @override
  void didUpdateWidget(_Levels old) {
    super.didUpdateWidget(old);
    if (widget.playing && !_beat.isAnimating) _beat.repeat();
    if (!widget.playing && _beat.isAnimating) _beat.stop();
  }

  @override
  void dispose() {
    _beat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _beat,
      builder: (context, _) => SizedBox(
        width: 16,
        height: 14,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final phase in const [0.0, 0.33, 0.66])
              Container(
                width: 3,
                height: widget.playing ? 4 + 10 * (0.5 + 0.5 * math.sin((_beat.value + phase) * 2 * math.pi)) : 4,
                decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(1.5)),
              ),
          ],
        ),
      ),
    );
  }
}

/// How far the track is: a thin line, and the time left when [showRemaining]. It ticks once a second,
/// and only while the track plays.
class TrackProgress extends StatefulWidget {
  final bool playing;
  final Color color;
  final bool showRemaining;

  const TrackProgress({super.key, required this.playing, required this.color, this.showRemaining = false});

  /// "-2:31" for what is left.
  static String remainingLabel(Duration left) {
    final seconds = left.inSeconds;
    return '-${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  State<TrackProgress> createState() => _TrackProgressState();
}

class _TrackProgressState extends State<TrackProgress> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void didUpdateWidget(TrackProgress old) {
    super.didUpdateWidget(old);
    if (old.playing != widget.playing) _arm();
  }

  void _arm() {
    _tick?.cancel();
    _tick = widget.playing ? Timer.periodic(const Duration(seconds: 1), (_) => setState(() {})) : null;
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<NowPlayingService>();
    final progress = service.progress;
    if (progress == null) return const SizedBox.shrink();
    final line = SizedBox(
      height: 2,
      child: ColoredBox(
        color: const Color(0x26FFFFFF),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(widthFactor: progress, heightFactor: 1, child: ColoredBox(color: widget.color)),
        ),
      ),
    );
    if (!widget.showRemaining) return SizedBox(width: 120, child: line);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 150, child: line),
        const SizedBox(width: 8),
        Text(TrackProgress.remainingLabel(service.remaining ?? Duration.zero),
            style: const TextStyle(fontSize: 11, color: Color(0x99FFFFFF), fontFeatures: [FontFeature.tabularFigures()])),
      ],
    );
  }
}
