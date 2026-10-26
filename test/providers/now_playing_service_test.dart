import 'dart:typed_data';

import 'package:flauncher/providers/now_playing_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../mocks.mocks.dart';

Map<dynamic, dynamic> _track(String title, {String package = 'com.music', String artist = 'Band', bool playing = true}) =>
    {'package': package, 'title': title, 'artist': artist, 'playing': playing};

void main() {
  late MockFLauncherChannel channel;
  Map<dynamic, dynamic>? playingNow;

  setUp(() {
    channel = MockFLauncherChannel();
    playingNow = _track('Song A');
    when(channel.getNowPlaying()).thenAnswer((_) async => playingNow);
    when(channel.getNowPlayingArt(any)).thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));
    when(channel.mediaPlayPause(any)).thenAnswer((_) async => true);
    when(channel.mediaSkip(any, next: anyNamed('next'))).thenAnswer((_) async => true);
    when(channel.launchApp(any)).thenAnswer((_) async {});
  });

  NowPlayingService? started;

  Future<NowPlayingService> start(WidgetTester tester) async {
    final service = NowPlayingService(channel);
    started = service;
    await tester.pump(Duration.zero);
    return service;
  }

  // The service's periodic timer must be cancelled before the test body ends, or the binding
  // reports a pending timer; so each test disposes what it started.
  void serviceTest(String name, Future<void> Function(WidgetTester tester) body) {
    testWidgets(name, (tester) async {
      started = null;
      try {
        await body(tester);
      } finally {
        started?.dispose();
      }
    });
  }

  group('polling', () {
    serviceTest('reads what plays at once and exposes the track', (tester) async {
      final service = await start(tester);

      expect(service.current, const NowPlaying('com.music', 'Song A', 'Band', true));
      verify(channel.getNowPlaying()).called(1);
    });

    serviceTest('keeps polling while resumed', (tester) async {
      await start(tester);
      clearInteractions(channel);

      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 4));

      verify(channel.getNowPlaying()).called(2);
    });

    serviceTest('stops polling when the app is paused and again when it is hidden', (tester) async {
      await start(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      clearInteractions(channel);
      await tester.pump(const Duration(seconds: 30));
      verifyNever(channel.getNowPlaying());

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(Duration.zero);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      clearInteractions(channel);
      await tester.pump(const Duration(seconds: 30));
      verifyNever(channel.getNowPlaying());
    });

    serviceTest('starts polling again when the app resumes, reading at once', (tester) async {
      await start(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 10));
      clearInteractions(channel);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(Duration.zero);
      verify(channel.getNowPlaying()).called(1);

      await tester.pump(const Duration(seconds: 4));
      verify(channel.getNowPlaying()).called(1);
    });

    serviceTest('current becomes null when nothing plays and listeners are told', (tester) async {
      final service = await start(tester);
      var notified = 0;
      service.addListener(() => notified++);

      playingNow = null;
      await tester.pump(const Duration(seconds: 4));

      expect(service.current, isNull);
      expect(notified, 1);
    });

    serviceTest('does not notify when the same state is read again', (tester) async {
      final service = await start(tester);
      var notified = 0;
      service.addListener(() => notified++);

      await tester.pump(const Duration(seconds: 4));

      expect(notified, 0);
    });

    serviceTest('missing fields read as empty values', (tester) async {
      playingNow = {'package': 'com.video'};
      final service = await start(tester);

      expect(service.current, const NowPlaying('com.video', '', '', false));
    });

    testWidgets('dispose stops the timer', (tester) async {
      final service = await start(tester);
      started = null;
      service.dispose();
      clearInteractions(channel);

      await tester.pump(const Duration(seconds: 30));

      verifyNever(channel.getNowPlaying());
    });
  });

  group('cover art', () {
    serviceTest('is read for the track playing', (tester) async {
      final service = await start(tester);

      verify(channel.getNowPlayingArt('com.music')).called(1);
      expect(service.art, Uint8List.fromList([1, 2, 3]));
    });

    serviceTest('is not asked again while the track stays the same', (tester) async {
      await start(tester);
      clearInteractions(channel);

      // Same track, but paused: the state changed, the track did not.
      playingNow = _track('Song A', playing: false);
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 4));

      verifyNever(channel.getNowPlayingArt(any));
    });

    serviceTest('is asked again when the title changes', (tester) async {
      final service = await start(tester);
      clearInteractions(channel);
      when(channel.getNowPlayingArt(any)).thenAnswer((_) async => Uint8List.fromList([9]));

      playingNow = _track('Song B');
      await tester.pump(const Duration(seconds: 4));

      verify(channel.getNowPlayingArt('com.music')).called(1);
      expect(service.art, Uint8List.fromList([9]));
    });

    serviceTest('is asked again when another app plays the same title', (tester) async {
      await start(tester);
      clearInteractions(channel);

      playingNow = _track('Song A', package: 'com.other');
      await tester.pump(const Duration(seconds: 4));

      verify(channel.getNowPlayingArt('com.other')).called(1);
    });

    serviceTest('is cleared when playback ends', (tester) async {
      final service = await start(tester);
      expect(service.art, isNotNull);

      playingNow = null;
      await tester.pump(const Duration(seconds: 4));

      expect(service.art, isNull);
    });
  });

  group('controls', () {
    serviceTest('playPause reaches the channel with the playing app and reads back', (tester) async {
      final service = await start(tester);
      clearInteractions(channel);

      final done = service.playPause();
      await tester.pump(const Duration(milliseconds: 300));
      await done;

      verify(channel.mediaPlayPause('com.music')).called(1);
      verify(channel.getNowPlaying()).called(1);
    });

    serviceTest('skip(next: true) and skip(next: false) reach the matching call', (tester) async {
      final service = await start(tester);
      clearInteractions(channel);

      final forward = service.skip(next: true);
      await tester.pump(const Duration(milliseconds: 500));
      await forward;
      verify(channel.mediaSkip('com.music', next: true)).called(1);
      verifyNever(channel.mediaSkip(any, next: false));

      final back = service.skip(next: false);
      await tester.pump(const Duration(milliseconds: 500));
      await back;
      verify(channel.mediaSkip('com.music', next: false)).called(1);
    });

    serviceTest('openApp launches the playing app', (tester) async {
      final service = await start(tester);

      await service.openApp();

      verify(channel.launchApp('com.music')).called(1);
    });

    serviceTest('controls do nothing when nothing plays', (tester) async {
      playingNow = null;
      final service = await start(tester);

      await service.playPause();
      await service.skip(next: true);
      await service.openApp();

      verifyNever(channel.mediaPlayPause(any));
      verifyNever(channel.mediaSkip(any, next: anyNamed('next')));
      verifyNever(channel.launchApp(any));
    });
  });
}
