import 'dart:io';

import 'package:flauncher/devbertini/brand.dart';
import 'package:flauncher/devbertini/vitrine/focus.dart';
import 'package:flauncher/devbertini/vitrine/logos.dart';
import 'package:flauncher/devbertini/vitrine/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// A 1x1 white PNG (made with zlib and its CRCs), enough for the logos to be read and drawn.
final List<int> _png = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00,
  0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0D, 0x49,
  0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xFF, 0xFF, 0xFF, 0x7F, 0x00, 0x09, 0xFB, 0x03, 0xFD, 0x2A, 0x86, 0xE3,
  0x8A, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('logos', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('vitrine_logos_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('reads both variants by package, names with dots and underscores included', () async {
      File('${dir.path}/logo_black_com.wbd.stream.png').writeAsBytesSync(_png);
      File('${dir.path}/logo_light_com.wbd.stream.png').writeAsBytesSync([..._png, 0]);
      File('${dir.path}/logo_light_com.example.my_app.png').writeAsBytesSync(_png);
      File('${dir.path}/hd_com.wbd.stream.png').writeAsBytesSync(_png);
      File('${dir.path}/logo_black_empty.app.png').writeAsBytesSync(const []);
      final logos = VitrineLogos(directory: () async => dir);
      var heard = 0;
      logos.addListener(() => heard++);
      await logos.load();
      expect(logos.loaded, isTrue);
      expect(heard, 1);
      expect(logos.bytes('com.wbd.stream', onBlack: true)!.length, _png.length);
      expect(logos.bytes('com.wbd.stream', onBlack: false)!.length, _png.length + 1);
      expect(logos.bytes('com.example.my_app', onBlack: false), isNotNull);
      expect(logos.bytes('empty.app', onBlack: true), isNull);
    });

    test('a brand with one variant gives it on both surfaces; an unknown one gives nothing', () async {
      File('${dir.path}/logo_light_com.netflix.ninja.png').writeAsBytesSync(_png);
      final logos = VitrineLogos(directory: () async => dir);
      await logos.load();
      expect(logos.bytes('com.netflix.ninja', onBlack: true), isNotNull);
      expect(logos.bytes('com.netflix.ninja', onBlack: false), isNotNull);
      expect(logos.bytes('com.unknown', onBlack: true), isNull);
    });

    test('no folder: loaded, with every logo falling back', () async {
      final logos = VitrineLogos(directory: () async => null);
      await logos.load();
      expect(logos.loaded, isTrue);
      expect(logos.bytes('com.netflix.ninja', onBlack: true), isNull);
    });

    testWidgets('the logo widget draws the variant of the surface, or its fallback', (tester) async {
      File('${dir.path}/logo_black_tv.twitch.android.app.png').writeAsBytesSync(_png);
      final logos = VitrineLogos(directory: () async => dir);
      await tester.runAsync(logos.load);
      Widget host(Widget child, {VitrineTokens? tokens}) => ChangeNotifierProvider<VitrineLogos>.value(
            value: logos,
            child: VitrineTheme(
              tokens: tokens ?? VitrineTokens.dark(CinematicPalette.devBertini),
              child: Directionality(textDirection: TextDirection.ltr, child: Center(child: child)),
            ),
          );
      await tester.pumpWidget(host(const VitrineLogo(package: 'tv.twitch.android.app', height: 25)));
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.height, 25);
      expect(find.byType(Image), findsOneWidget);
      await tester.pumpWidget(host(const VitrineLogo(package: 'com.unknown', height: 25, fallback: Text('Unknown'))));
      expect(find.byType(Image), findsNothing);
      expect(find.text('Unknown'), findsOneWidget);
    });

    testWidgets('without the logos service the fallback shows', (tester) async {
      await tester.pumpWidget(const Directionality(
        textDirection: TextDirection.ltr,
        child: VitrineLogo(package: 'com.netflix.ninja', height: 25, fallback: Text('Netflix')),
      ));
      expect(find.text('Netflix'), findsOneWidget);
    });
  });

  group('focus', () {
    Widget frame(bool focused, VitrineTokens tokens) => VitrineTheme(
          tokens: tokens,
          child: Center(
            child: VitrineFocusFrame(
              focused: focused,
              radius: 12,
              child: const SizedBox(width: 140, height: 71),
            ),
          ),
        );

    DecoratedBox ring(WidgetTester tester) => tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .firstWhere((box) => box.position == DecorationPosition.foreground);

    testWidgets('focused: the accent ring outside, the scale, no shadow on black', (tester) async {
      final dark = VitrineTokens.dark(CinematicPalette.devBertini);
      await tester.pumpWidget(frame(true, dark));
      await tester.pumpAndSettle();
      final border = (ring(tester).decoration as BoxDecoration).border as Border;
      expect(border.top.color, dark.accent);
      expect(border.top.width, 3);
      expect(border.top.strokeAlign, BorderSide.strokeAlignOutside);
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1.06);
      final shadowBox = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .firstWhere((box) => box.position == DecorationPosition.background);
      expect((shadowBox.decoration as BoxDecoration).boxShadow, isEmpty);
    });

    testWidgets('focused on the light field: the one soft shadow', (tester) async {
      final light = VitrineTokens.light(CinematicPalette.devBertini);
      await tester.pumpWidget(frame(true, light));
      final shadowBox = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .firstWhere((box) => box.position == DecorationPosition.background);
      expect((shadowBox.decoration as BoxDecoration).boxShadow, light.focusShadow);
    });

    testWidgets('at rest: no ring, no scale', (tester) async {
      await tester.pumpWidget(frame(false, VitrineTokens.dark(CinematicPalette.devBertini)));
      expect((ring(tester).decoration as BoxDecoration).border, isNull);
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    });
  });
}
