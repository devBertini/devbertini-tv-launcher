import 'package:flauncher/devbertini/tv_extras.dart';
import 'package:flauncher/flauncher_channel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mocks.mocks.dart';

// An Open-Meteo answer as the API sends it (its shape read from api.open-meteo.com on 22/10/2026).
const _answer = '{"latitude":48.86,"longitude":2.35,"current_units":{"temperature_2m":"°C"},'
    '"current":{"time":"2026-10-22T22:15","interval":900,"temperature_2m":23.2,"weather_code":3,"is_day":0}}';

const _paris = WeatherPlace('Paris', 48.8566, 2.3522);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('weather', () {
    test('reads temperature, code and day from Open-Meteo', () {
      final at = DateTime(2026, 10, 22, 22, 15);
      final weather = WeatherNow.parse(_answer, at)!;
      expect(weather.temperature, 23.2);
      expect(weather.code, 3);
      expect(weather.day, isFalse);
      expect(weather.at, at);
    });

    test('an answer without its current block reads as nothing', () {
      expect(WeatherNow.parse('{"error":true}', DateTime(2026)), isNull);
      expect(WeatherNow.parse('not json', DateTime(2026)), isNull);
    });

    test('codes map to their icons, by day and by night', () {
      expect(WeatherNow.iconFor(0, true), Icons.wb_sunny_outlined);
      expect(WeatherNow.iconFor(0, false), Icons.nightlight_outlined);
      expect(WeatherNow.iconFor(61, true), Icons.water_drop_outlined);
      expect(WeatherNow.iconFor(81, true), Icons.water_drop_outlined);
      expect(WeatherNow.iconFor(95, false), Icons.thunderstorm_outlined);
      expect(WeatherNow.iconFor(73, true), Icons.ac_unit_rounded);
    });

    test('fetches the place of the build, keeps the answer and hides it once it is three hours old', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      Uri? asked;
      final service = OpenMeteoService(prefs, place: _paris, fetch: (uri) async {
        asked = uri;
        return _answer;
      });
      await service.refresh();
      expect(asked!.host, 'api.open-meteo.com');
      expect(asked!.queryParameters['latitude'], '48.8566');
      expect(asked!.queryParameters['longitude'], '2.3522');
      expect(asked!.queryParameters['timezone'], 'auto');
      expect(service.now()?.temperature, 23.2);
      expect(service.now(DateTime.now().add(const Duration(hours: 3, minutes: 1))), isNull);
      service.dispose();
    });

    test('off in the settings, nothing is shown', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = OpenMeteoService(prefs, place: _paris, fetch: (_) async => _answer);
      await service.refresh();
      await service.setEnabled(false);
      expect(service.now(), isNull);
      expect(prefs.getBool(OpenMeteoService.enabledKey), isFalse);
      service.dispose();
    });

    test('a failed fetch keeps the last weather', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var body = _answer;
      final service = OpenMeteoService(prefs, place: _paris, fetch: (_) async => body);
      await service.refresh();
      body = 'oops';
      await service.refresh();
      expect(service.now()?.code, 3);
      service.dispose();
    });

    test('a build made without a place has no weather and asks nothing', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var asked = 0;
      final service = OpenMeteoService(prefs, fetch: (_) async {
        asked++;
        return _answer;
      });
      expect(service.place, isNull, reason: 'the test runs without --dart-define=WEATHER_*');
      expect(service.enabled, isFalse);
      await service.refresh();
      expect(asked, 0);
      expect(service.now(), isNull);
      service.dispose();
    });

    test('a place needs a name and two coordinates in range', () {
      expect(WeatherPlace.parse('Paris', '48.8566', '2.3522')?.city, 'Paris');
      expect(WeatherPlace.parse('', '48.8566', '2.3522'), isNull);
      expect(WeatherPlace.parse('Paris', '', '2.3522'), isNull);
      expect(WeatherPlace.parse('Paris', '48.8566', 'east'), isNull);
      expect(WeatherPlace.parse('Paris', '91', '2.3522'), isNull);
      expect(WeatherPlace.parse('Paris', '48.8566', '181'), isNull);
    });
  });

  group('night', () {
    test('night runs from 22h to 6h, across midnight', () {
      expect(NightMode.isNight(DateTime(2026, 10, 22, 21, 59)), isFalse);
      expect(NightMode.isNight(DateTime(2026, 10, 22, 22, 0)), isTrue);
      expect(NightMode.isNight(DateTime(2026, 10, 23, 0, 30)), isTrue);
      expect(NightMode.isNight(DateTime(2026, 10, 23, 5, 59)), isTrue);
      expect(NightMode.isNight(DateTime(2026, 10, 23, 6, 0)), isFalse);
    });

    test('the night mode setting is on until turned off, and dims only at night', () async {
      SharedPreferences.setMockInitialValues({});
      var now = DateTime(2026, 10, 22, 21, 59);
      final night = NightModeService(await SharedPreferences.getInstance(), clock: () => now);
      expect(night.enabled, isTrue);
      expect(night.dimmed, isFalse);
      now = DateTime(2026, 10, 22, 22, 0);
      night.check();
      expect(night.dimmed, isTrue);
      await night.setEnabled(false);
      expect(night.enabled, isFalse);
      expect(night.dimmed, isFalse);
      night.dispose();
    });

    test('the night hours count with the setting off too (Aparencia Automatico follows them)', () async {
      SharedPreferences.setMockInitialValues({NightMode.enabledKey: false});
      var now = DateTime(2026, 10, 22, 12, 0);
      final night = NightModeService(await SharedPreferences.getInstance(), clock: () => now);
      var notified = 0;
      night.addListener(() => notified++);
      expect(night.night, isFalse);
      now = DateTime(2026, 10, 22, 23, 0);
      night.check();
      expect(night.night, isTrue);
      expect(night.dimmed, isFalse);
      expect(notified, 1);
      night.dispose();
    });
  });

  group('sleep timer', () {
    test('setting minutes asks the TV for the alarm and keeps its time; zero clears it', () async {
      final channel = MockFLauncherChannel();
      final at = DateTime(2026, 10, 22, 23, 40);
      when(channel.getSleepTimer()).thenAnswer((_) async => null);
      when(channel.setSleepTimer(30)).thenAnswer((_) async => at);
      when(channel.setSleepTimer(0)).thenAnswer((_) async => null);
      final timer = SleepTimerService(channel);
      await timer.set(30);
      expect(timer.at, at);
      expect(timer.minutes, 30);
      await timer.set(0);
      expect(timer.at, isNull);
      expect(timer.minutes, 0);
      verify(channel.setSleepTimer(30)).called(1);
      timer.dispose();
    });
  });

  test('the TV setup notice lists what the TV reports undone', () async {
    final FLauncherChannel channel = MockFLauncherChannel();
    when(channel.getTvSetupProblems()).thenAnswer((_) async => ['densidade da tela']);
    final setup = TvSetupService(channel);
    await Future<void>.delayed(Duration.zero);
    expect(setup.problems, ['densidade da tela']);
    setup.dispose();
  });
}
