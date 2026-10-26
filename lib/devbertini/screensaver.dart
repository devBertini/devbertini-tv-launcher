/*
 * DevBertini theme for LTvLauncher (GPL-3.0, like the rest of this project).
 * Copyright (C) 2026 Claudio Bertini (devBertini)
 *
 * The screensaver of the home: after some minutes without a key, the screen goes true black with
 * only a large thin clock, which moves to another place once a minute (the Mini LED panel then
 * lights a few zones only). Any key brings the home back and does nothing else; Home brings it back at its start.
 */

import 'dart:async';
import 'dart:math' as math;

import 'package:flauncher/devbertini/brand.dart';
import 'package:flauncher/devbertini/cinematic.dart';
import 'package:flauncher/providers/now_playing_service.dart';
import 'package:flauncher/devbertini/tv_extras.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Shows the saver over [child] when the home has been idle for the minutes set in the settings.
class DevBertiniScreensaver extends StatefulWidget {
  final Widget child;

  const DevBertiniScreensaver({super.key, required this.child});

  @override
  State<DevBertiniScreensaver> createState() => _DevBertiniScreensaverState();
}

class _DevBertiniScreensaverState extends State<DevBertiniScreensaver> with WidgetsBindingObserver {
  Timer? _idle;
  bool _showing = false;
  bool _resumed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Early handlers run before the focus tree, so a handled key never reaches the focused app card.
    FocusManager.instance.addEarlyKeyEventHandler(_onKey);
    // Home never reaches the focus tree as a key (Android turns it into an intent): it wakes the home here.
    devBertiniHomeAgain.addListener(_onHome);
    WidgetsBinding.instance.addPostFrameCallback((_) => _arm());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FocusManager.instance.removeEarlyKeyEventHandler(_onKey);
    devBertiniHomeAgain.removeListener(_onHome);
    _idle?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    if (_resumed) {
      _arm();
    } else {
      // Another app in front: no countdown, and the home comes back as it was left.
      _idle?.cancel();
      _hide();
    }
  }

  /// Starts the countdown again from the time set.
  void _arm() {
    _idle?.cancel();
    if (!mounted || !_resumed) return;
    final settings = context.read<SettingsService>();
    final minutes = settings.devBertiniSaverMinutes;
    if (minutes <= 0 || !isCinematicTheme(settings.themes)) return;
    _idle = Timer(Duration(minutes: minutes), () {
      if (mounted && _resumed) {
        setState(() => _showing = true);
      }
    });
  }

  void _hide() {
    if (!_showing) return;
    if (mounted) setState(() => _showing = false);
  }

  void _onHome() {
    _hide();
    _arm();
  }

  /// The key that woke the home: its release is swallowed too, so OK cannot open an app on waking.
  LogicalKeyboardKey? _wakeKey;

  KeyEventResult _onKey(KeyEvent event) {
    if (_showing) {
      // The key that wakes the home is spent on waking it.
      _wakeKey = event.logicalKey;
      _hide();
      _arm();
      return KeyEventResult.handled;
    }
    if (_wakeKey != null && event.logicalKey == _wakeKey && event is! KeyDownEvent) {
      if (event is KeyUpEvent) _wakeKey = null;
      return KeyEventResult.handled;
    }
    _wakeKey = null;
    _arm();
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    // Re-armed when the minutes change in the settings.
    context.select<SettingsService, int>((settings) => settings.devBertiniSaverMinutes);
    return Stack(
      fit: StackFit.expand,
      children: [
        // While the saver shows, the home is not painted at all.
        Opacity(opacity: _showing ? 0.0 : 1.0, child: widget.child),
        if (_showing) const _SaverClock(),
      ],
    );
  }
}

/// The large thin clock on black, at a new place each minute.
class _SaverClock extends StatefulWidget {
  const _SaverClock();

  @override
  State<_SaverClock> createState() => _SaverClockState();
}

class _SaverClockState extends State<_SaverClock> {
  final math.Random _random = math.Random();
  Timer? _timer;
  DateTime _now = DateTime.now();
  Alignment _place = Alignment.center;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  void _schedule() {
    final now = DateTime.now();
    _timer = Timer(Duration(seconds: 60 - now.second, milliseconds: -now.millisecond), () {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
        _place = Alignment(_random.nextDouble() * 1.4 - 0.7, _random.nextDouble() * 1.2 - 0.6);
      });
      _schedule();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final minute = DateFormat('H:mm', locale).format(_now);
    final now = context.select<NowPlayingService, NowPlaying?>((service) => service.current);
    final art = context.select<NowPlayingService, Uint8List?>((service) => service.art);
    final weather = context.watch<OpenMeteoService?>()?.now(_now);
    return ColoredBox(
      color: Colors.black,
      child: DefaultTextStyle(
        style: const TextStyle(decoration: TextDecoration.none),
        // One quiet change a minute: the clock fades out and back in at its new place.
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 1200),
          child: Align(
            key: ValueKey(minute),
            alignment: _place,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  minute,
                  style: const TextStyle(fontSize: 96, fontWeight: FontWeight.w200, color: Color(0xD9F5F0E8), height: 1.0),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      toBeginningOfSentenceCase(DateFormat.MMMMEEEEd(locale).format(_now)) ?? '',
                      style: const TextStyle(fontSize: 16, color: Color(0x80F5F0E8), letterSpacing: 0.2),
                    ),
                    if (weather != null) ...[
                      const SizedBox(width: 14),
                      Icon(WeatherNow.iconFor(weather.code, weather.day), size: 17, color: const Color(0x80F5F0E8)),
                      const SizedBox(width: 5),
                      Text('${weather.temperature.round()}°',
                          style: const TextStyle(fontSize: 16, color: Color(0x80F5F0E8), letterSpacing: 0.2)),
                    ],
                  ],
                ),
                // With music playing, its cover and track sit quietly under the date.
                if (now != null) ...[
                  const SizedBox(height: 26),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox.square(
                          dimension: 36,
                          child: art == null
                              ? const ColoredBox(
                                  color: Color(0xFF151515),
                                  child: Icon(Icons.music_note_rounded, size: 20, color: Color(0x66FFFFFF)),
                                )
                              : Image.memory(art, fit: BoxFit.cover, gaplessPlayback: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(now.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xB3F5F0E8))),
                            if (now.artist.isNotEmpty)
                              Text(now.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12.5, color: Color(0x73F5F0E8))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
