
import 'package:flauncher/devbertini/now_playing_island.dart';
import 'package:flauncher/providers/now_playing_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Stands in for the polling service: holds a track the test sets and records what the island asks.
class _FakeNowPlaying extends ChangeNotifier implements NowPlayingService {
  NowPlaying? _current;
  final List<String> calls = [];

  _FakeNowPlaying([this._current]);

  @override
  NowPlaying? get current => _current;

  @override
  Uint8List? get art => null;

  double? fakeProgress;

  @override
  double? get progress => fakeProgress;

  @override
  Duration? get remaining => fakeProgress == null ? null : Duration(seconds: ((1 - fakeProgress!) * 200).round());

  set current(NowPlaying? value) {
    _current = value;
    notifyListeners();
  }

  @override
  Future<void> skip({required bool next}) async => calls.add('skip(next: $next)');

  @override
  Future<void> playPause() async => calls.add('playPause');

  @override
  Future<void> openApp() async => calls.add('openApp');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _song = NowPlaying('com.music', 'Blue Hour', 'The Band', true);

Future<void> _pump(WidgetTester tester, _FakeNowPlaying service) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<NowPlayingService>.value(
      value: service,
      child: const MaterialApp(home: Scaffold(body: Align(alignment: Alignment.topCenter, child: NowPlayingIsland()))),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

/// Moves the focus onto the nearest focusable around [target], as the remote's arrows would.
Future<void> _focus(WidgetTester tester, Finder target) async {
  Focus.of(tester.element(target)).requestFocus();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('draws nothing when nothing plays', (tester) async {
    await _pump(tester, _FakeNowPlaying());

    expect(find.byType(Text), findsNothing);
    expect(find.byType(Icon), findsNothing);
    expect(find.byKey(const ValueKey('island')), findsNothing);
  });

  testWidgets('appears when something starts playing and leaves when it stops', (tester) async {
    final service = _FakeNowPlaying();
    await _pump(tester, service);

    service.current = _song;
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('island')), findsOneWidget);

    service.current = null;
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('island')), findsNothing);
    expect(find.textContaining('Blue Hour'), findsNothing);
  });

  testWidgets('the closed pill shows title and artist and no controls', (tester) async {
    await _pump(tester, _FakeNowPlaying(_song));

    expect(find.textContaining('Blue Hour'), findsOneWidget);
    expect(find.textContaining('The Band'), findsOneWidget);
    expect(find.byIcon(Icons.skip_previous_rounded), findsNothing);
    expect(find.byIcon(Icons.skip_next_rounded), findsNothing);
    expect(find.byIcon(Icons.open_in_new_rounded), findsNothing);
  });

  testWidgets('the pill leaves out the artist when there is none', (tester) async {
    await _pump(tester, _FakeNowPlaying(const NowPlaying('com.music', 'Blue Hour', '', true)));

    expect(find.textContaining('Blue Hour'), findsOneWidget);
    expect(find.textContaining('The Band'), findsNothing);
  });

  testWidgets('the progress line shows how far the track is, and the open player the time left', (tester) async {
    final service = _FakeNowPlaying()
      ..fakeProgress = 0.25
      ..current = _song;
    await _pump(tester, service);
    final line = tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox));
    expect(line.widthFactor, 0.25);
    expect(find.text('-2:30'), findsNothing);

    await _focus(tester, find.textContaining('Blue Hour'));
    expect(find.text('-2:30'), findsOneWidget);
  });

  testWidgets('no progress line when the app reports no duration', (tester) async {
    final service = _FakeNowPlaying()..current = _song;
    await _pump(tester, service);
    expect(find.byType(FractionallySizedBox), findsNothing);
  });

  group('opened', () {
    Future<_FakeNowPlaying> open(WidgetTester tester, {NowPlaying song = _song}) async {
      final service = _FakeNowPlaying(song);
      await _pump(tester, service);
      await _focus(tester, find.textContaining('Blue Hour'));
      return service;
    }

    testWidgets('reaching the pill opens the player with the four buttons', (tester) async {
      await open(tester);

      expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
      expect(find.byIcon(Icons.open_in_new_rounded), findsOneWidget);
      expect(find.text('Blue Hour'), findsOneWidget);
      expect(find.text('The Band'), findsOneWidget);
    });

    testWidgets('play/pause takes the focus first', (tester) async {
      await open(tester);

      expect(FocusManager.instance.primaryFocus?.debugLabel, 'island play');
    });

    testWidgets('shows play instead of pause when the track is paused', (tester) async {
      await open(tester, song: const NowPlaying('com.music', 'Blue Hour', 'The Band', false));

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsNothing);
    });

    testWidgets('select on the focused play/pause button toggles playback', (tester) async {
      final service = await open(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();

      expect(service.calls, ['playPause']);
    });

    testWidgets('select on previous skips back', (tester) async {
      final service = await open(tester);
      await _focus(tester, find.byIcon(Icons.skip_previous_rounded));

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();

      expect(service.calls, ['skip(next: false)']);
    });

    testWidgets('select on next skips forward', (tester) async {
      final service = await open(tester);
      await _focus(tester, find.byIcon(Icons.skip_next_rounded));

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();

      expect(service.calls, ['skip(next: true)']);
    });

    testWidgets('select on open-app opens the playing app', (tester) async {
      final service = await open(tester);
      await _focus(tester, find.byIcon(Icons.open_in_new_rounded));

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      // The launch fade to black lifts by itself after 4 s; let that timer run out.
      await tester.pump(const Duration(seconds: 5));

      expect(service.calls, ['openApp']);
    });

    testWidgets('tapping a button works like select', (tester) async {
      final service = await open(tester);

      await tester.tap(find.byIcon(Icons.skip_next_rounded));
      await tester.pump();

      expect(service.calls, ['skip(next: true)']);
    });
  });
}
