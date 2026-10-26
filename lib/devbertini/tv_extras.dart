/*
 * DevBertini theme for LTvLauncher (GPL-3.0, like the rest of this project).
 * Copyright (C) 2026 Claudio Bertini (devBertini)
 *
 * The TV's extras around the clock: the weather (Open-Meteo), the sleep timer, the night dim and the
 * notice of what a TV update undid. Each one works only while the home is on screen.
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flauncher/flauncher_channel.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The weather now, as Open-Meteo reports it.
class WeatherNow {
  final double temperature;
  final int code;
  final bool day;
  final DateTime at;

  const WeatherNow(this.temperature, this.code, this.day, this.at);

  /// Reads Open-Meteo's `current` block; null when the answer lacks it.
  static WeatherNow? parse(String body, DateTime at) {
    try {
      final current = (jsonDecode(body) as Map<String, dynamic>)['current'] as Map<String, dynamic>;
      return WeatherNow(
        (current['temperature_2m'] as num).toDouble(),
        (current['weather_code'] as num).toInt(),
        (current['is_day'] as num? ?? 1) == 1,
        at,
      );
    } catch (_) {
      return null;
    }
  }

  /// The icon of a WMO weather code (Open-Meteo's `weather_code`).
  static IconData iconFor(int code, bool day) => switch (code) {
        0 || 1 => day ? Icons.wb_sunny_outlined : Icons.nightlight_outlined,
        2 => day ? Icons.wb_cloudy_outlined : Icons.nights_stay_outlined,
        3 || 45 || 48 => Icons.cloud_outlined,
        >= 51 && <= 67 || >= 80 && <= 82 => Icons.water_drop_outlined,
        >= 71 && <= 77 || 85 || 86 => Icons.ac_unit_rounded,
        >= 95 => Icons.thunderstorm_outlined,
        _ => Icons.cloud_outlined,
      };
}

/// Where the weather is read for. It is set when the app is built, never in the code:
/// `--dart-define=WEATHER_CITY=<name> --dart-define=WEATHER_LATITUDE=<deg> --dart-define=WEATHER_LONGITUDE=<deg>`
/// (tools/devbertini/build_release.ps1 takes them from local.json). A build without them has no weather.
class WeatherPlace {
  final String city;
  final double latitude, longitude;

  const WeatherPlace(this.city, this.latitude, this.longitude);

  /// The place this build was made with, or null.
  static final WeatherPlace? configured = parse(
    const String.fromEnvironment('WEATHER_CITY'),
    const String.fromEnvironment('WEATHER_LATITUDE'),
    const String.fromEnvironment('WEATHER_LONGITUDE'),
  );

  /// A place from its three settings, or null when one is missing or not a coordinate.
  static WeatherPlace? parse(String city, String latitude, String longitude) {
    final lat = double.tryParse(latitude), lon = double.tryParse(longitude);
    if (city.trim().isEmpty || lat == null || lon == null || lat.abs() > 90 || lon.abs() > 180) return null;
    return WeatherPlace(city.trim(), lat, lon);
  }
}

/// The weather of the build's place ([WeatherPlace]), read from Open-Meteo (free for personal use, no account; its
/// CC-BY credit is in the settings tile) every half hour while the home is on screen. Shown only while fresh.
class OpenMeteoService extends ChangeNotifier with WidgetsBindingObserver {
  static const enabledKey = 'devbertini_weather';
  static const _cacheKey = 'devbertini_weather_last';
  static const refreshEvery = Duration(minutes: 30);
  static const freshFor = Duration(hours: 3);

  final SharedPreferences _prefs;
  final Future<String?> Function(Uri uri) _fetch;

  /// Null in a build made without a place: no weather, nothing fetched.
  final WeatherPlace? place;
  Timer? _timer;
  WeatherNow? _last;
  bool _disposed = false;

  OpenMeteoService(this._prefs, {Future<String?> Function(Uri uri)? fetch, WeatherPlace? place})
      : _fetch = fetch ?? _get,
        place = place ?? WeatherPlace.configured {
    final cached = _prefs.getString(_cacheKey);
    if (cached != null) {
      final parts = cached.split('|');
      if (parts.length == 2) _last = WeatherNow.parse(parts[1], DateTime.fromMillisecondsSinceEpoch(int.tryParse(parts[0]) ?? 0));
    }
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  bool get enabled => place != null && (_prefs.getBool(enabledKey) ?? true);

  /// The weather to show, or null when it is off, unknown or older than [freshFor].
  WeatherNow? now([DateTime? clock]) {
    final last = _last;
    if (!enabled || last == null) return null;
    return (clock ?? DateTime.now()).difference(last.at) < freshFor ? last : null;
  }

  Future<void> setEnabled(bool on) async {
    await _prefs.setBool(enabledKey, on);
    on ? _start() : _stop();
    notifyListeners();
  }

  void _start() {
    if (!enabled) return;
    final last = _last;
    if (last == null || DateTime.now().difference(last.at) >= refreshEvery) refresh();
    _timer ??= Timer.periodic(refreshEvery, (_) => refresh());
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    state == AppLifecycleState.resumed ? _start() : _stop();
  }

  Future<void> refresh() async {
    final at = place;
    if (at == null) return;
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '${at.latitude}',
      'longitude': '${at.longitude}',
      'current': 'temperature_2m,weather_code,is_day',
      'timezone': 'auto',
    });
    final body = await _fetch(uri);
    if (_disposed || body == null) return;
    final now = DateTime.now();
    final parsed = WeatherNow.parse(body, now);
    if (parsed == null) return;
    _last = parsed;
    await _prefs.setString(_cacheKey, '${now.millisecondsSinceEpoch}|$body');
    notifyListeners();
  }

  static Future<String?> _get(Uri uri) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(uri);
      final response = await request.close().timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;
      return await response.transform(utf8.decoder).join();
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    super.dispose();
  }
}

/// "Desligar em": the native alarm (SleepTimer.java) holds the truth; this mirrors it for the panel and
/// the line under the clock.
class SleepTimerService extends ChangeNotifier with WidgetsBindingObserver {
  static const steps = [0, 1, 15, 30, 60, 90, 120];

  final FLauncherChannel _channel;
  DateTime? _at;
  int _minutes = 0;
  bool _disposed = false;

  SleepTimerService(this._channel) {
    WidgetsBinding.instance.addObserver(this);
    _read();
  }

  /// When the TV goes to standby, or null.
  DateTime? get at => _at;

  /// The step chosen last (0 when off), where the panel's left and right keys step from.
  int get minutes => _at == null ? 0 : _minutes;

  Future<void> set(int minutes) async {
    _minutes = minutes;
    _at = await _channel.setSleepTimer(minutes);
    if (!_disposed) notifyListeners();
  }

  Future<void> _read() async {
    final at = await _channel.getSleepTimer();
    if (_disposed) return;
    if (at != _at) {
      _at = at;
      notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _read();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

/// From 22h to 6h the home dims a little, when the setting is on (on by default): the cards' own dim and
/// the light behind them get darker. No layer is laid over the screen: on the TV's GPU a full-screen
/// translucent layer doubled the missed frames when moving along the row.
class NightModeService extends ChangeNotifier with WidgetsBindingObserver {
  final SharedPreferences _prefs;
  final DateTime Function() _clock;
  Timer? _timer;
  bool _night;

  NightModeService(this._prefs, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now,
        _night = NightMode.isNight((clock ?? DateTime.now)()) {
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  bool get enabled => _prefs.getBool(NightMode.enabledKey) ?? true;

  /// Whether the clock is in the night hours (22h to 6h), with the setting on or off; Aparência's Automático
  /// follows it.
  bool get night => _night;

  /// Whether the home is dimmed now.
  bool get dimmed => enabled && _night;

  Future<void> setEnabled(bool on) async {
    await _prefs.setBool(NightMode.enabledKey, on);
    notifyListeners();
  }

  void check() {
    final night = NightMode.isNight(_clock());
    if (night != _night) {
      _night = night;
      notifyListeners();
    }
  }

  void _start() {
    check();
    _timer ??= Timer.periodic(const Duration(minutes: 1), (_) => check());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _start();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }
}

class NightMode {
  static const enabledKey = 'devbertini_night_mode';
  static const startHour = 22, endHour = 6;
  static const dim = 0.35;

  static bool isNight(DateTime time) => time.hour >= startHour || time.hour < endHour;
}

/// What a TV update undid of the setup (TvSetupCheck.java), read each time the home comes back.
class TvSetupService extends ChangeNotifier with WidgetsBindingObserver {
  final FLauncherChannel _channel;
  List<String> _problems = const [];
  bool _disposed = false;

  TvSetupService(this._channel) {
    WidgetsBinding.instance.addObserver(this);
    _read();
  }

  List<String> get problems => _problems;

  Future<void> _read() async {
    final found = await _channel.getTvSetupProblems();
    if (_disposed) return;
    if (found.join('|') != _problems.join('|')) {
      _problems = found;
      notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _read();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
