
import 'package:flauncher/devbertini/cinematic.dart';
import 'package:flauncher/devbertini/screensaver.dart';
import 'package:flauncher/providers/now_playing_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import '../mocks.mocks.dart';

/// Nothing plays: the saver only reads the current track.
class _NoMusic extends ChangeNotifier implements NowPlayingService {
  @override
  NowPlaying? get current => null;

  @override
  Uint8List? get art => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The key events that reach the home underneath the saver.
class _Received {
  final List<KeyEvent> events = [];
  int get downs => events.whereType<KeyDownEvent>().length;
  int get ups => events.whereType<KeyUpEvent>().length;
}

Future<_Received> _pump(WidgetTester tester, {int minutes = 5, String theme = 'devbertini'}) async {
  final settings = MockSettingsService();
  when(settings.themes).thenReturn(theme);
  when(settings.devBertiniSaverMinutes).thenReturn(minutes);
  final received = _Received();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsService>.value(value: settings),
        ChangeNotifierProvider<NowPlayingService>.value(value: _NoMusic()),
      ],
      child: MaterialApp(
        home: DevBertiniScreensaver(
          child: Focus(
            autofocus: true,
            onKeyEvent: (_, event) {
              received.events.add(event);
              return KeyEventResult.handled;
            },
            child: const Text('home'),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return received;
}

/// The large clock the saver draws, which only exists while the saver shows.
Finder get _saverClock => find.byWidgetPredicate((w) => w is Text && w.style?.fontSize == 96);

/// Takes the saver and its timers out of the tree so the test ends with none pending.
Future<void> _end(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
}

void main() {
  group('when it shows', () {
    testWidgets('after the minutes the settings give, and not before', (tester) async {
      await _pump(tester, minutes: 5);

      await tester.pump(const Duration(minutes: 4, seconds: 59));
      expect(_saverClock, findsNothing);

      await tester.pump(const Duration(seconds: 2));
      expect(_saverClock, findsOneWidget);
      await _end(tester);
    });

    testWidgets('follows the minutes set: 2 minutes shows it at 2 minutes', (tester) async {
      await _pump(tester, minutes: 2);

      await tester.pump(const Duration(minutes: 2, seconds: 1));

      expect(_saverClock, findsOneWidget);
      await _end(tester);
    });

    testWidgets('0 minutes means never', (tester) async {
      await _pump(tester, minutes: 0);

      await tester.pump(const Duration(hours: 3));

      expect(_saverClock, findsNothing);
      await _end(tester);
    });

    testWidgets('never on a theme that is not cinematic', (tester) async {
      await _pump(tester, minutes: 5, theme: 'classic');

      await tester.pump(const Duration(hours: 1));

      expect(_saverClock, findsNothing);
      await _end(tester);
    });
  });

  group('idle timer', () {
    testWidgets('any key starts the count again', (tester) async {
      await _pump(tester, minutes: 5);

      await tester.pump(const Duration(minutes: 4));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(minutes: 4));
      expect(_saverClock, findsNothing, reason: '8 minutes passed, but only 4 since the key');

      await tester.pump(const Duration(minutes: 1, seconds: 1));
      expect(_saverClock, findsOneWidget);
      await _end(tester);
    });

    testWidgets('keys pressed before the saver show still reach the home', (tester) async {
      final received = await _pump(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);

      expect(received.downs, 1);
      expect(received.ups, 1);
      await _end(tester);
    });
  });

  group('waking', () {
    testWidgets('the key that wakes the saver, and its release, do not reach the home', (tester) async {
      final received = await _pump(tester, minutes: 1);
      await tester.pump(const Duration(minutes: 1, seconds: 1));
      expect(_saverClock, findsOneWidget);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
      await tester.pump();
      expect(_saverClock, findsNothing, reason: 'the key brought the home back');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
      await tester.pump();

      expect(received.events, isEmpty);
      await _end(tester);
    });

    testWidgets('the next key after waking reaches the home again', (tester) async {
      final received = await _pump(tester, minutes: 1);
      await tester.pump(const Duration(minutes: 1, seconds: 1));
      await tester.sendKeyEvent(LogicalKeyboardKey.select); // wakes
      await tester.pump();
      received.events.clear();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);

      expect(received.downs, 1);
      expect(received.ups, 1);
      expect(received.events.first.logicalKey, LogicalKeyboardKey.arrowDown);
      await _end(tester);
    });

    testWidgets('after waking, the count starts again and the saver comes back', (tester) async {
      await _pump(tester, minutes: 1);
      await tester.pump(const Duration(minutes: 1, seconds: 1));
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      expect(_saverClock, findsNothing);

      await tester.pump(const Duration(minutes: 1, seconds: 1));

      expect(_saverClock, findsOneWidget);
      await _end(tester);
    });

    testWidgets('Home brings the home back too, and the count starts again', (tester) async {
      await _pump(tester, minutes: 1);
      await tester.pump(const Duration(minutes: 1, seconds: 1));
      expect(_saverClock, findsOneWidget);

      devBertiniHomeAgain.press();
      await tester.pump();
      expect(_saverClock, findsNothing);

      await tester.pump(const Duration(minutes: 1, seconds: 1));
      expect(_saverClock, findsOneWidget);
      await _end(tester);
    });

    testWidgets('going to the background hides the saver', (tester) async {
      await _pump(tester, minutes: 1);
      await tester.pump(const Duration(minutes: 1, seconds: 1));
      expect(_saverClock, findsOneWidget);

      // Frames are off while paused, so the screen is read once the app is back.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(_saverClock, findsNothing);
      await _end(tester);
    });
  });
}
