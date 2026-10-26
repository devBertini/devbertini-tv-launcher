import 'package:flauncher/devbertini/brand.dart';
import 'package:flauncher/devbertini/cinematic.dart';
import 'package:flauncher/devbertini/vitrine/tokens.dart';
import 'package:flauncher/devbertini/vitrine/tv_panel.dart';
import 'package:flauncher/models/tv_input.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/tv_inputs_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import '../mocks.mocks.dart';

void main() {
  late MockTvInputsService inputs;
  late MockAppsService apps;
  late MockSettingsService settings;

  setUp(() {
    inputs = MockTvInputsService();
    apps = MockAppsService();
    settings = MockSettingsService();
    when(settings.themes).thenReturn(devBertiniTheme);
    when(inputs.switchInput(any)).thenAnswer((_) async => true);
    when(apps.launchTvControl(any)).thenAnswer((_) async => true);
  });

  Future<void> open(WidgetTester tester, {List<TvInput> devices = const [], Brightness brightness = Brightness.dark}) async {
    when(inputs.devices).thenReturn(devices);
    await tester.binding.setSurfaceSize(const Size(960, 540));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<TvInputsService>.value(value: inputs),
        ChangeNotifierProvider<AppsService>.value(value: apps),
        ChangeNotifierProvider<SettingsService>.value(value: settings),
      ],
      child: MaterialApp(
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: VitrineTheme(
          tokens: VitrineTokens.of(CinematicPalette.devBertini, brightness),
          child: const Scaffold(body: SizedBox.expand()),
        ),
        builder: (context, child) => VitrineTheme(
          tokens: VitrineTokens.of(CinematicPalette.devBertini, brightness),
          child: child!,
        ),
      ),
    ));
    final context = tester.element(find.byType(Scaffold));
    showDialog(context: context, builder: (_) => const VitrineTvPanel());
    await tester.pumpAndSettle();
  }

  final ps5 = TvInput(id: 'hdmi2', label: 'PlayStation 5', type: TvInputType.hdmi, device: true, on: true);
  final player = TvInput(id: 'hdmi3', label: 'Blu-ray', type: TvInputType.hdmi, device: true, on: false);

  testWidgets('lists the devices with their state, then the six TV functions in order', (tester) async {
    await open(tester, devices: [ps5, player]);
    expect(find.text('TV'), findsOneWidget);
    expect(find.text('Aparelhos'), findsOneWidget);
    expect(find.text('PlayStation 5'), findsOneWidget);
    expect(find.text('Ligado'), findsOneWidget);
    expect(find.text('Em espera'), findsOneWidget);
    expect(find.text('Ajustes da TV'), findsOneWidget);
    final labels = ['Entradas', 'Imagem', 'Som', 'Modo jogo', 'Painel rápido', 'Energia'];
    final tops = [for (final label in labels) tester.getTopLeft(find.text(label)).dy];
    expect(tops, orderedEquals([...tops]..sort()));
    expect(tester.getTopLeft(find.text('Blu-ray')).dy, lessThan(tops.first));
  });

  testWidgets('the panel is 384 wide on the left of the screen, where the rail is', (tester) async {
    await open(tester);
    final panel = tester.getRect(find.byType(ListView));
    expect(panel.left, greaterThanOrEqualTo(0));
    expect(panel.right, lessThanOrEqualTo(384));
  });

  testWidgets('the first device has the focus, and OK switches the TV to it', (tester) async {
    await open(tester, devices: [ps5]);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    verify(inputs.switchInput('hdmi2')).called(1);
    // The launch fade lifts by itself after 4 s when no app comes up.
    expect(devBertiniLaunching.value, isTrue);
    await tester.pump(const Duration(seconds: 5));
    expect(devBertiniLaunching.value, isFalse);
  });

  testWidgets('without devices the first function has the focus; OK on Imagem opens the TV screen', (tester) async {
    await open(tester);
    expect(find.text('Aparelhos'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    verify(apps.launchTvControl('picture')).called(1);
    expect(find.byType(VitrineTvPanel), findsNothing);
  });

  testWidgets('the focused row takes the plate colour of the theme', (tester) async {
    for (final brightness in Brightness.values) {
      await open(tester, brightness: brightness);
      final tokens = VitrineTokens.of(CinematicPalette.devBertini, brightness);
      final focusedRow = tester
          .widgetList<Container>(find.descendant(of: find.byType(VitrinePanelRow), matching: find.byType(Container)))
          .where((c) => (c.decoration as BoxDecoration?)?.color != null)
          .toList();
      expect(focusedRow, hasLength(1));
      expect((focusedRow.single.decoration as BoxDecoration).color, tokens.plate);
      Navigator.of(tester.element(find.byType(VitrineTvPanel))).pop();
      await tester.pumpAndSettle();
    }
  });
}
