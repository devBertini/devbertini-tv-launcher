/*
 * DevBertini theme for LTvLauncher (GPL-3.0, like the rest of this project).
 * Copyright (C) 2026 Claudio Bertini (devBertini)
 */

import 'dart:async';

import 'package:flauncher/devbertini/tv_extras.dart';
import 'package:flauncher/devbertini/vitrine/tokens.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// The clock block at the top right of the Vitrine home (docs/devbertini/DESIGN-VITRINE.md, "Clock block"), right
/// aligned: one 12 px line with the weather icon and temperature (when there is weather) and the date, the time at
/// 25 px w300 and, while the sleep timer is set, "Desliga às HH:MM". The session places its right edge at x 912 and
/// its top at 27.
///
/// It rebuilds once a minute, on the minute, and nothing else ticks. It sits in its own layer, so those repaints
/// never touch the rest of the home. Each service is read with `select`, so one that is missing (tests, the box)
/// leaves out its part; the time format is the Settings one, "H:mm" without it.
class VitrineClock extends StatelessWidget {
  /// What time it is; the real clock when null. Tests give their own.
  @visibleForTesting
  final DateTime Function()? now;

  const VitrineClock({super.key, this.now});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(child: _MinuteTicker(now: now ?? DateTime.now));
  }
}

/// Rebuilds [_ClockBody] at the start of every minute, and again when the home comes back to the front (a timer does
/// not run while the TV sleeps, so the minute shown could be old until the next tick).
class _MinuteTicker extends StatefulWidget {
  final DateTime Function() now;

  const _MinuteTicker({required this.now});

  @override
  State<_MinuteTicker> createState() => _MinuteTickerState();
}

class _MinuteTickerState extends State<_MinuteTicker> with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    final now = widget.now();
    _timer = Timer(Duration(seconds: 60 - now.second, milliseconds: -now.millisecond), () {
      if (!mounted) return;
      setState(() {});
      _schedule();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    setState(() {});
    _schedule();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _ClockBody(now: widget.now());
}

class _ClockBody extends StatelessWidget {
  final DateTime now;

  const _ClockBody({required this.now});

  @override
  Widget build(BuildContext context) {
    final t = VitrineTheme.of(context);
    final locale = Localizations.localeOf(context);
    final pt = locale.languageCode == 'pt';
    final weather = context.select<OpenMeteoService?, WeatherNow?>((s) => s?.now(now));
    final sleepAt = context.select<SleepTimerService?, DateTime?>((s) => s?.at);
    final timeFormat =
        context.select<SettingsService?, String?>((s) => s?.timeFormat) ?? SettingsService.defaultTimeFormat;
    final line = vitrineText(12, color: t.ink2, line: 15);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (weather != null) ...[
              Icon(WeatherNow.iconFor(weather.code, weather.day), size: 16, color: t.ink2),
              const SizedBox(width: 5),
              Text('${weather.temperature.round()}°', style: vitrineText(12, weight: 600, color: t.ink, line: 15)),
              const SizedBox(width: 8),
            ],
            Text(DateFormat('EEEE, d MMM', locale.toString()).format(now), style: line),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Text(
            DateFormat(timeFormat, locale.toString()).format(now),
            style: vitrineText(25, weight: 300, color: t.ink, line: 27, tracking: 0.3),
          ),
        ),
        if (sleepAt != null)
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              '${pt ? 'Desliga às' : 'Turns off at'} ${DateFormat('HH:mm', locale.toString()).format(sleepAt)}',
              style: line,
            ),
          ),
      ],
    );
  }
}
