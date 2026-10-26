import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/settings/flauncher_about_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../mocks.mocks.dart';

const _channel = MethodChannel('me.efesser.flauncher/method');

Future<List<String>> _pump(WidgetTester tester, Locale locale) async {
  final settings = MockSettingsService();
  when(settings.accentColorHex).thenReturn("7C4DFF");
  final opened = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
    if (call.method == "openUrl") opened.add(call.arguments as String);
    return true;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null));
  await tester.pumpWidget(
    ChangeNotifierProvider<SettingsService>.value(
      value: settings,
      child: MaterialApp(
        locale: locale,
        // The TV's type, so a label that does not fit its button fails here as it would on the screen.
        theme: ThemeData(fontFamily: 'Onest'),
        supportedLocales: const [Locale('en'), Locale('pt')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: LTvLauncherAboutDialog(
            packageInfo: PackageInfo(appName: "LTvLauncher", packageName: "p", version: "1.2.3", buildNumber: "4"),
          ),
        ),
      ),
    ),
  );
  return opened;
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pump();
}

void main() {
  setUpAll(() async {
    await (FontLoader('Onest')..addFont(rootBundle.load('assets/fonts/Onest/Onest-Variable.ttf'))).load();
  });

  testWidgets("in Portuguese: the fork, its author, the project it is built on and the author's links", (tester) async {
    final opened = await _pump(tester, const Locale('pt'));
    expect(find.text("devBertini TV Launcher"), findsOneWidget);
    expect(find.text("v1.2.3 (4)"), findsOneWidget);
    expect(find.text("Por Claudio Bertini (devBertini)"), findsOneWidget);
    expect(find.text("Baseado no LTvLauncher, da LeanBitLab, e no FLauncher"), findsOneWidget);
    expect(find.text("Projeto original: LeanBitLab"), findsOneWidget);
    expect(find.text("Fechar"), findsOneWidget);

    await _tap(tester, "Código-fonte no GitHub");
    await _tap(tester, "GitHub (devBertini)");
    await _tap(tester, "LinkedIn (Claudio Bertini)");
    await _tap(tester, "LTvLauncher no GitHub");
    expect(opened, [
      "https://github.com/devBertini/devbertini-tv-launcher",
      "https://github.com/devBertini",
      "https://www.linkedin.com/in/claudio-bertini/",
      "https://github.com/leanbitlab-org/LtvLauncher",
    ]);
  });

  testWidgets("in English: the same credits", (tester) async {
    await _pump(tester, const Locale('en'));
    expect(find.text("By Claudio Bertini (devBertini)"), findsOneWidget);
    expect(find.text("Based on LTvLauncher by LeanBitLab and on FLauncher"), findsOneWidget);
    expect(find.text("Source code on GitHub"), findsOneWidget);
    expect(find.text("Original project: LeanBitLab"), findsOneWidget);
    expect(find.text("Close"), findsOneWidget);
  });

  testWidgets("the author's repository has the focus when the dialog opens", (tester) async {
    await _pump(tester, const Locale('pt'));
    await tester.pumpAndSettle();
    final focused = FocusManager.instance.primaryFocus!.context!;
    expect(find.descendant(of: find.byWidget(focused.widget), matching: find.text("Código-fonte no GitHub")),
        findsOneWidget);
  });
}
