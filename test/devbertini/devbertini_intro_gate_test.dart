import 'package:flauncher/devbertini/devbertini_intro.dart';
import 'package:flauncher/devbertini/devbertini_intro_gate.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import '../mocks.mocks.dart';

/// Settings that remember what the gate records, like the real ones do between launches.
class _Memory {
  int bootSeen;
  int buildSeen;
  final String theme;

  _Memory({this.bootSeen = -1, this.theme = 'devbertini'}) : buildSeen = devBertiniIntroBuild;

  late final MockSettingsService settings = () {
    final s = MockSettingsService();
    when(s.themes).thenReturn(theme);
    when(s.devBertiniIntroBootSeen).thenAnswer((_) => bootSeen);
    when(s.devBertiniIntroBuildSeen).thenAnswer((_) => buildSeen);
    when(s.setDevBertiniIntroBootSeen(any)).thenAnswer((inv) async => bootSeen = inv.positionalArguments.first as int);
    when(s.setDevBertiniIntroBuildSeen(any)).thenAnswer((inv) async => buildSeen = inv.positionalArguments.first as int);
    return s;
  }();
}

/// Starts the launcher as a fresh process would: the gate is mounted once, with the globals main() reads.
Future<void> _launch(WidgetTester tester, _Memory memory, {required int? boot, double uptime = 30}) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  devBertiniBootCount = boot;
  devBertiniLaunchUptimeSeconds = uptime;
  final apps = MockAppsService();
  when(apps.initialized).thenReturn(true);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsService>.value(value: memory.settings),
        ChangeNotifierProvider<AppsService>.value(value: apps),
      ],
      child: const MaterialApp(home: DevBertiniIntroGate(child: Text('home'))),
    ),
  );
  await tester.pump();
}

/// Ends the launch: the gate leaves the tree, so its waits stop and no timer stays pending.
Future<void> _quit(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  tearDown(() {
    devBertiniBootCount = null;
    devBertiniLaunchUptimeSeconds = null;
  });

  testWidgets('plays when the boot count differs from the one recorded, and records it', (tester) async {
    final memory = _Memory(bootSeen: 6);

    await _launch(tester, memory, boot: 7);

    expect(find.byType(DevBertiniIntro), findsOneWidget);
    verify(memory.settings.setDevBertiniIntroBootSeen(7)).called(1);
    expect(memory.bootSeen, 7);
    await _quit(tester);
  });

  testWidgets('plays on the first launch ever, when no boot is recorded', (tester) async {
    final memory = _Memory(bootSeen: -1);

    await _launch(tester, memory, boot: 12);

    expect(find.byType(DevBertiniIntro), findsOneWidget);
    expect(memory.bootSeen, 12);
    await _quit(tester);
  });

  testWidgets('does not play when the boot count is the one recorded', (tester) async {
    final memory = _Memory(bootSeen: 7);

    await _launch(tester, memory, boot: 7);

    expect(find.byType(DevBertiniIntro), findsNothing);
    expect(find.text('home'), findsOneWidget);
    verifyNever(memory.settings.setDevBertiniIntroBootSeen(any));
    await _quit(tester);
  });

  testWidgets('does not play again for the same boot after the launcher restarts', (tester) async {
    final memory = _Memory(bootSeen: 6);
    await _launch(tester, memory, boot: 7);
    expect(find.byType(DevBertiniIntro), findsOneWidget);
    await _quit(tester);

    // The launcher restarts in the same power-on (memory freed, Home pressed): same boot count.
    await _launch(tester, memory, boot: 7);

    expect(find.byType(DevBertiniIntro), findsNothing);
    await _quit(tester);
  });

  testWidgets('plays again after the next power-on', (tester) async {
    final memory = _Memory(bootSeen: 7);

    await _launch(tester, memory, boot: 8);

    expect(find.byType(DevBertiniIntro), findsOneWidget);
    expect(memory.bootSeen, 8);
    await _quit(tester);
  });

  testWidgets('does not play on a new boot count when the launcher starts long after the TV booted', (tester) async {
    final memory = _Memory(bootSeen: 6);

    await _launch(tester, memory, boot: 7, uptime: 3600);

    expect(find.byType(DevBertiniIntro), findsNothing);
    await _quit(tester);
  });

  testWidgets('does not play on a theme that is not cinematic', (tester) async {
    final memory = _Memory(bootSeen: 6, theme: 'classic');

    await _launch(tester, memory, boot: 7);

    expect(find.byType(DevBertiniIntro), findsNothing);
    verifyNever(memory.settings.setDevBertiniIntroBootSeen(any));
    await _quit(tester);
  });
}
