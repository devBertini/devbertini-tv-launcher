/*
 * DevBertini theme for LTvLauncher (GPL-3.0, like the rest of this project).
 * Copyright (C) 2026 Claudio Bertini (devBertini)
 */

import 'dart:io';
import 'dart:math' as math;

import 'package:flauncher/devbertini/brand.dart';
import 'package:flauncher/devbertini/devbertini_intro.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

/// Bump when the intro should play once more after an update.
const int devBertiniIntroBuild = 4;

/// The intro plays when the launcher starts within this many seconds of the TV booting.
const double _bootWindowSeconds = 240;

/// Seconds since the TV booted when the launcher started, read natively in main() before the first
/// frame (this TV does not let apps read /proc/uptime). Null when unknown.
double? devBertiniLaunchUptimeSeconds;

/// Which boot of the TV this is (Settings.Global.BOOT_COUNT), read in main(); null when unknown.
int? devBertiniBootCount;

/// Shows the studio intro over the launcher when the TV has just booted (and once after an update),
/// then fades it out. The launcher builds underneath meanwhile, so its rows are ready when it shows.
class DevBertiniIntroGate extends StatefulWidget {
  final Widget child;

  const DevBertiniIntroGate({super.key, required this.child});

  @override
  State<DevBertiniIntroGate> createState() => _DevBertiniIntroGateState();
}

class _DevBertiniIntroGateState extends State<DevBertiniIntroGate> with SingleTickerProviderStateMixin {
  static const double _fadeSeconds = 0.4;

  /// Steps the intro frame by frame, at most a thirtieth of a second per frame: when the UI thread
  /// stalls (the first load of a cold start), the intro waits instead of jumping to its end.
  Ticker? _ticker;
  Duration _lastTick = Duration.zero;
  double _elapsed = 0;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsService>();
    final uptime = devBertiniLaunchUptimeSeconds ?? _uptimeSeconds();
    final boot = devBertiniBootCount;
    // Once per power-on: the launcher also restarts when the TV frees memory or Home is pressed,
    // and that must not replay the intro.
    final newBoot = boot == null || boot != settings.devBertiniIntroBootSeen;
    final justBooted = uptime < _bootWindowSeconds && newBoot;
    final updated = settings.devBertiniIntroBuildSeen < devBertiniIntroBuild;
    debugPrint('DevBertiniIntro: uptime=$uptime boot=$boot justBooted=$justBooted updated=$updated theme=${settings.themes}');
    if (isCinematicTheme(settings.themes) && (justBooted || updated)) {
      settings.setDevBertiniIntroBuildSeen(devBertiniIntroBuild);
      if (boot != null) settings.setDevBertiniIntroBootSeen(boot);
      _playing = true;
      // A ticker, not an AnimationController: it keeps the full length even when the TV's
      // animations are turned off, and never skips ahead on a stall.
      _ticker = createTicker((now) {
        final step = (now - _lastTick).inMicroseconds / Duration.microsecondsPerSecond;
        _lastTick = now;
        setState(() {
          _elapsed += step.clamp(0.0, 1 / 30);
          if (_elapsed >= DevBertiniIntro.duration + _fadeSeconds) {
            _playing = false;
            _ticker?.stop();
          }
        });
      });
      _startWhenSeen(afterBoot: justBooted);
    }
  }

  /// Holds the intro on black until it can be seen whole: after the TV's boot animation (the
  /// launcher starts under it at boot) and after the launcher's own first load, which keeps the UI
  /// thread busy for a few seconds on a cold start and would let a time-based intro run out unseen.
  Future<void> _startWhenSeen({required bool afterBoot}) async {
    final deadline = DateTime.now().add(const Duration(seconds: 45));
    bool expired() => !DateTime.now().isBefore(deadline);
    if (afterBoot) {
      while (mounted && !expired() && !await _bootAnimationGone()) {
        await Future.delayed(const Duration(milliseconds: 250));
      }
    }
    while (mounted && !expired() && !context.read<AppsService>().initialized) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    if (!mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    // Time for the launcher underneath to decode its banners, which would otherwise make the
    // intro's first frames stutter.
    await Future.delayed(const Duration(milliseconds: 1200));
    debugPrint('DevBertiniIntro: starting (mounted=$mounted)');
    if (mounted) _ticker?.start();
  }

  /// TCL sets sys.tcl.bootanim.exit when its boot animation ends; init.svc.bootanim is Android's own.
  static Future<bool> _bootAnimationGone() async {
    try {
      final tcl = await Process.run('getprop', ['sys.tcl.bootanim.exit']);
      if ((tcl.stdout as String).trim() == '1') return true;
      final service = await Process.run('getprop', ['init.svc.bootanim']);
      return (service.stdout as String).trim() == 'stopped';
    } catch (_) {
      return true;
    }
  }

  static double _uptimeSeconds() {
    try {
      return double.parse(File('/proc/uptime').readAsStringSync().split(' ').first);
    } catch (_) {
      return double.infinity;
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Always a Stack with the same first child, so the launcher keeps its state when the intro
    // leaves. While the intro covers the screen the launcher is not painted at all (opacity 0 skips
    // its painting): each intro frame then costs only the intro.
    final covered = _playing && (_ticker?.isActive ?? false) && _elapsed < DevBertiniIntro.duration;
    final List<Widget> children = [
      Opacity(opacity: covered ? 0.0 : 1.0, child: RepaintBoundary(child: widget.child)),
    ];
    if (_playing && _ticker != null) {
      final elapsed = _elapsed;
      final opacity = elapsed <= DevBertiniIntro.duration
          ? 1.0
          : 1.0 - ((elapsed - DevBertiniIntro.duration) / _fadeSeconds).clamp(0.0, 1.0);
      children.add(IgnorePointer(
        child: RepaintBoundary(
          child: Opacity(
          opacity: opacity,
          child: DevBertiniIntro(
            t: math.min(elapsed, DevBertiniIntro.duration),
            // Always drawn in full: a TV may ship with its transition animations at 0, which Flutter
            // reads as "remove animations", and the intro is its drawing.
            reduceMotion: false,
          ),
          ),
        ),
      ));
    }
    return Stack(fit: StackFit.expand, children: children);
  }
}