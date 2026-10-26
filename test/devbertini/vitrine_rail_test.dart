import 'package:flauncher/devbertini/brand.dart';
import 'package:flauncher/devbertini/devbertini_intro.dart';
import 'package:flauncher/devbertini/profile_model.dart';
import 'package:flauncher/devbertini/vitrine/focus.dart';
import 'package:flauncher/devbertini/vitrine/rail.dart';
import 'package:flauncher/devbertini/vitrine/signature.dart';
import 'package:flauncher/devbertini/vitrine/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Profiles extends ProfilesController {
  final LauncherProfile _current;

  _Profiles(this._current);

  @override
  LauncherProfile get current => _current;

  @override
  List<LauncherProfile> get profiles => [_current];

  @override
  Future<LauncherProfile> create(String name) => throw UnimplementedError();

  @override
  Future<void> rename(LauncherProfile profile, String name) => throw UnimplementedError();

  @override
  Future<void> nextColour(LauncherProfile profile) => throw UnimplementedError();

  @override
  Future<void> delete(LauncherProfile profile) => throw UnimplementedError();

  @override
  Future<void> switchTo(LauncherProfile profile) => throw UnimplementedError();
}

VitrineTokens _dark() => VitrineTokens.dark(CinematicPalette.devBertini);
VitrineTokens _light() => VitrineTokens.light(CinematicPalette.devBertini);

Finder _item(VitrineDestination d) => find.byKey(ValueKey('vitrine-rail-item-${d.name}'));
final Finder _avatar = find.byKey(const ValueKey('vitrine-rail-avatar'));
final Finder _panel = find.byKey(const ValueKey('vitrine-rail-panel'));
final Finder _badge = find.byKey(const ValueKey('vitrine-rail-badge'));
final Finder _rail = find.byKey(const ValueKey('vitrine-rail'));

String? _focused() => FocusManager.instance.primaryFocus?.debugLabel;

/// What a test sees of the rail it pumped.
class _Harness {
  final VitrineRailController controller = VitrineRailController();
  final FocusNode outside = FocusNode(debugLabel: 'outside');
  final List<VitrineDestination> selected = [];
  int profile = 0;
  int close = 0;
}

/// Pumps the rail on the TV's 960x540 canvas (device pixel ratio 2), at the origin, beside a focus node that stands for
/// the rest of the home.
Future<_Harness> _pump(
  WidgetTester tester, {
  VitrineTokens? tokens,
  VitrineDestination selected = VitrineDestination.home,
  bool showTv = true,
  int count = 0,
  String language = 'pt',
  LauncherProfile? profile,
}) async {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = const Size(1920, 1080);
  addTearDown(tester.view.reset);
  // A fresh tree: a rail left open by an earlier pump of the same test must not carry its state over.
  await tester.pumpWidget(const SizedBox());
  final h = _Harness();
  addTearDown(h.outside.dispose);
  addTearDown(h.controller.dispose);
  Widget home = Stack(
    children: [
      Focus(focusNode: h.outside, child: const SizedBox.expand()),
      Positioned(
        left: 0,
        top: 0,
        bottom: 0,
        child: VitrineRail(
          controller: h.controller,
          selected: selected,
          onSelected: h.selected.add,
          onProfile: () => h.profile++,
          onClose: () => h.close++,
          showTv: showTv,
          notificationCount: count,
        ),
      ),
    ],
  );
  if (profile != null) {
    // Provided as the app provides it (the non-null type); the rail reads it as optional.
    home = ChangeNotifierProvider<ProfilesController>.value(value: _Profiles(profile), child: home);
  }
  await tester.pumpWidget(
    VitrineTheme(
      tokens: tokens ?? _dark(),
      child: MaterialApp(
        locale: Locale(language),
        supportedLocales: const [Locale('pt'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(backgroundColor: Colors.black, body: home),
      ),
    ),
  );
  return h;
}

Future<void> _openOn(WidgetTester tester, _Harness h, [VitrineDestination d = VitrineDestination.home]) async {
  h.controller.open(d);
  await tester.pumpAndSettle();
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
}

/// The rail's key order, top to bottom.
List<String> _order({bool tv = true}) => [
      'vitrine-rail-avatar',
      'vitrine-rail-home',
      'vitrine-rail-apps',
      if (tv) 'vitrine-rail-tv',
      'vitrine-rail-music',
      'vitrine-rail-notifications',
      'vitrine-rail-network',
      'vitrine-rail-settings',
    ];

void main() {
  setUpAll(() async {
    // The pills' width depends on real text: load Onest, which the rail draws in.
    final loader = FontLoader('Onest')..addFont(rootBundle.load('assets/fonts/Onest/Onest-Variable.ttf'));
    await loader.load();
  });

  group('collapsed', () {
    testWidgets('94 wide, pills at x 30..64 on the axis x 47, 34x28, 3 apart, centred vertically', (tester) async {
      await _pump(tester);
      expect(tester.getSize(_rail), const Size(94, 540));
      expect(_panel, findsNothing);
      final order = VitrineDestination.values;
      for (var i = 0; i < order.length; i++) {
        final r = tester.getRect(_item(order[i]));
        expect(r.size, const Size(34, 28), reason: order[i].name);
        expect(r.left, 30);
        expect(r.right, 64);
        expect(r.center.dx, 47);
        // Seven pills of 28 and six gaps of 3 make 214, centred on 540: y 163..377.
        expect(r.top, 163 + i * 31, reason: order[i].name);
      }
      expect(tester.getBottomLeft(_item(VitrineDestination.settings)).dy, 377);
      // Each icon sits on the axis too.
      final icon = find.descendant(of: _item(VitrineDestination.apps), matching: find.byType(Icon));
      expect(tester.getCenter(icon).dx, 47);
      expect(tester.getSize(icon), const Size(15, 15));
    });

    testWidgets('the avatar is 26 px at x 34, y 30, with no name and no label showing', (tester) async {
      await _pump(tester);
      expect(tester.getRect(_avatar), const Rect.fromLTWH(34, 30, 26, 26));
      expect(find.byKey(const ValueKey('vitrine-rail-name')), findsNothing);
      expect(tester.widget<Container>(_avatar).decoration, const BoxDecoration(color: Color(0xFF4A525E), shape: BoxShape.circle));
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('without the TV the six items are centred as a group', (tester) async {
      await _pump(tester, showTv: false);
      expect(_item(VitrineDestination.tv), findsNothing);
      final top = tester.getTopLeft(_item(VitrineDestination.home)).dy;
      final bottom = tester.getBottomLeft(_item(VitrineDestination.settings)).dy;
      expect(bottom - top, 6 * 28 + 5 * 3);
      expect((top + bottom) / 2, 270);
      // Música follows Apps directly.
      expect(tester.getTopLeft(_item(VitrineDestination.music)).dy, tester.getBottomLeft(_item(VitrineDestination.apps)).dy + 3);
    });

    testWidgets('the selected pill is the plate with its edge and the accent icon, in both themes', (tester) async {
      for (final tokens in [_dark(), _light()]) {
        await _pump(tester, tokens: tokens, selected: VitrineDestination.apps);
        BoxDecoration pill(VitrineDestination d) => tester
            .widget<DecoratedBox>(find.descendant(of: _item(d), matching: find.byType(DecoratedBox)).first)
            .decoration as BoxDecoration;
        Color? icon(VitrineDestination d) =>
            tester.widget<Icon>(find.descendant(of: _item(d), matching: find.byType(Icon))).color;
        final selected = pill(VitrineDestination.apps);
        expect(selected.color, tokens.plate, reason: tokens.brightness.name);
        expect((selected.border as Border).top.color, tokens.plateEdge);
        expect(selected.borderRadius, BorderRadius.circular(14));
        expect(icon(VitrineDestination.apps), tokens.accent);
        // At rest an item has no fill and the quiet ink.
        expect(pill(VitrineDestination.home).color, isNull);
        expect(icon(VitrineDestination.home), tokens.ink3);
      }
      expect(_dark().plate, const Color(0xFF000000));
      expect(_light().plate, const Color(0xFFFFFFFF));
    });
  });

  group('focus', () {
    testWidgets('the focused pill grows 1.05 with the ring and the ink icon; the others stay', (tester) async {
      final h = await _pump(tester);
      await _openOn(tester, h, VitrineDestination.apps);
      // getRect would give the unscaled size: the corners carry the transform.
      Size drawn(VitrineDestination d) {
        final corner = tester.getBottomRight(_item(d)) - tester.getTopLeft(_item(d));
        return Size(corner.dx, corner.dy);
      }

      final rest = drawn(VitrineDestination.home);
      final focused = drawn(VitrineDestination.apps);
      expect(rest, Size(rest.width, 28));
      expect(focused.width, closeTo(rest.width * 1.05, 0.01));
      expect(focused.height, closeTo(28 * 1.05, 0.01));
      final icon = tester.widget<Icon>(find.descendant(of: _item(VitrineDestination.apps), matching: find.byType(Icon)));
      expect(icon.color, _dark().ink);
      // The 3 px ring is painted around the pill by the shared frame, on the item that has the focus only.
      VitrineFocusFrame frame(VitrineDestination d) =>
          tester.widget<VitrineFocusFrame>(find.ancestor(of: _item(d), matching: find.byType(VitrineFocusFrame)));
      expect(frame(VitrineDestination.apps).focused, isTrue);
      expect(frame(VitrineDestination.apps).radius, 14);
      expect(frame(VitrineDestination.apps).scale, 1.05);
      expect(frame(VitrineDestination.music).focused, isFalse);
      expect(frame(VitrineDestination.home).focused, isFalse);
    });

    testWidgets('Up and Down walk the avatar and the items; the ends stay put; Left does nothing', (tester) async {
      final h = await _pump(tester);
      await _openOn(tester, h, VitrineDestination.home);
      final order = _order();
      expect(_focused(), 'vitrine-rail-home');
      await _key(tester, LogicalKeyboardKey.arrowUp);
      expect(_focused(), 'vitrine-rail-avatar');
      await _key(tester, LogicalKeyboardKey.arrowUp);
      expect(_focused(), 'vitrine-rail-avatar');
      for (var i = 1; i < order.length; i++) {
        await _key(tester, LogicalKeyboardKey.arrowDown);
        expect(_focused(), order[i]);
      }
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(_focused(), 'vitrine-rail-settings');
      await _key(tester, LogicalKeyboardKey.arrowLeft);
      expect(_focused(), 'vitrine-rail-settings');
      expect(h.close, 0);
      expect(h.controller.isOpen, isTrue);
    });

    testWidgets('without the TV the walk skips it', (tester) async {
      final h = await _pump(tester, showTv: false);
      await _openOn(tester, h, VitrineDestination.apps);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(_focused(), 'vitrine-rail-music');
      await _key(tester, LogicalKeyboardKey.arrowUp);
      await _key(tester, LogicalKeyboardKey.arrowUp);
      expect(_focused(), 'vitrine-rail-home');
    });

    testWidgets('controller.open focuses the item it names; the TV falls back to Início on the box', (tester) async {
      var h = await _pump(tester);
      expect(h.controller.isOpen, isFalse);
      await _openOn(tester, h, VitrineDestination.music);
      expect(_focused(), 'vitrine-rail-music');
      expect(h.controller.isOpen, isTrue);
      h.controller.open();
      await tester.pumpAndSettle();
      expect(_focused(), 'vitrine-rail-home');

      h = await _pump(tester, showTv: false);
      await _openOn(tester, h, VitrineDestination.tv);
      expect(_focused(), 'vitrine-rail-home');
    });

    testWidgets('a focus change rebuilds only the item that gains it and the one that loses it', (tester) async {
      final h = await _pump(tester);
      await _openOn(tester, h, VitrineDestination.home);
      final rebuilt = <String>[];
      debugOnRebuildDirtyWidget = (element, builtOnce) => rebuilt.add(element.widget.runtimeType.toString());
      addTearDown(() => debugOnRebuildDirtyWidget = null);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      debugOnRebuildDirtyWidget = null;
      expect(_focused(), 'vitrine-rail-apps');
      expect(rebuilt.where((name) => name == '_RailFocusable'), hasLength(2));
      for (final name in ['VitrineRail', 'AnimatedBuilder', '_RailItem', '_Profile']) {
        expect(rebuilt, isNot(contains(name)), reason: name);
      }
    });

    testWidgets('the rail has its own layer and uses no blur or filter', (tester) async {
      await _pump(tester);
      expect(find.descendant(of: find.byType(VitrineRail), matching: find.byType(RepaintBoundary)), findsWidgets);
      for (final type in [BackdropFilter, ImageFiltered, ShaderMask]) {
        expect(find.descendant(of: find.byType(VitrineRail), matching: find.byType(type)), findsNothing, reason: '$type');
      }
    });
  });

  group('open', () {
    testWidgets('the panel and the labels appear while the rail has the focus and go when the focus leaves', (tester) async {
      final h = await _pump(tester);
      expect(find.text('Configurações'), findsOneWidget); // laid out in its pill, clipped away while collapsed
      await _openOn(tester, h);
      expect(_panel, findsOneWidget);
      expect(h.controller.isOpen, isTrue);
      h.outside.requestFocus();
      await tester.pumpAndSettle();
      expect(h.controller.isOpen, isFalse);
      expect(_panel, findsNothing);
      expect(tester.getSize(_rail).width, 94);
      expect(tester.getSize(_item(VitrineDestination.apps)).width, 34);
    });

    testWidgets('the pills are as wide as the widest label needs, 30 px each side, the panel ends 30 px after them', (tester) async {
      final h = await _pump(tester);
      await _openOn(tester, h);
      final panel = tester.getRect(_panel);
      expect(panel.left, 0);
      expect(panel.height, 540);
      final apps = tester.getRect(_item(VitrineDestination.apps)); // not focused: unscaled
      expect(apps.left, 30);
      expect(panel.right - apps.right, 30);
      // The widest label (Configurações) plus the icon, the 10 px gap and 9.5 px each side, in whole px.
      final widest = tester.getSize(find.text('Configurações')).width;
      expect(apps.width, greaterThanOrEqualTo(9.5 + 15 + 10 + widest + 9.5));
      expect(apps.width, lessThan(9.5 + 15 + 10 + widest + 9.5 + 3));
      expect(apps.width % 1, 0);
      // The mockup measured 127 for the pt-BR labels in Onest.
      expect(apps.width, 127);
      expect(panel.width, 187);
      for (final d in VitrineDestination.values) {
        if (d == VitrineDestination.home) continue; // focused, scaled
        expect(tester.getSize(_item(d)).width, apps.width, reason: d.name);
        expect(tester.getTopLeft(_item(d)).dx, 30, reason: d.name);
      }
      expect(tester.getSize(_rail).width, panel.width);
    });

    testWidgets('the English labels give a pill of their own width', (tester) async {
      final h = await _pump(tester, language: 'en');
      await _openOn(tester, h);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      final apps = tester.getRect(_item(VitrineDestination.apps));
      final widest = tester.getSize(find.text('Notifications')).width;
      expect(apps.width, greaterThanOrEqualTo(9.5 + 15 + 10 + widest + 9.5));
      // The pill is measured at w600, the label at rest is w450: a little narrower.
      expect(apps.width, lessThan(9.5 + 15 + 10 + widest + 9.5 + 3));
      expect(tester.getRect(_panel).right - apps.right, 30);
      // Another language, another width: it is measured, never a fixed 127.
      expect(apps.width, isNot(127));
    });

    testWidgets('the icons never move while the rail opens', (tester) async {
      final h = await _pump(tester);
      Offset icon() => tester.getCenter(find.descendant(of: _item(VitrineDestination.network), matching: find.byType(Icon)));
      final before = icon();
      h.controller.open(VitrineDestination.home);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(icon(), before);
      await tester.pumpAndSettle();
      expect(icon(), before);
      expect(before.dx, 47);
    });

    testWidgets('the width animates over 160 ms', (tester) async {
      final h = await _pump(tester);
      h.controller.open();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final mid = tester.getSize(_rail).width;
      expect(mid, greaterThan(94));
      await tester.pump(const Duration(milliseconds: 60));
      final later = tester.getSize(_rail).width;
      expect(later, greaterThan(mid));
      await tester.pump(const Duration(milliseconds: 60));
      final end = tester.getSize(_rail).width;
      expect(end, greaterThanOrEqualTo(later));
      await tester.pump(const Duration(milliseconds: 20));
      expect(tester.getSize(_rail).width, tester.getSize(_panel).width);
      // Nothing is left animating once it is open.
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('the avatar and the name sit centred together in the panel', (tester) async {
      final h = await _pump(tester);
      await _openOn(tester, h, VitrineDestination.apps);
      final panel = tester.getRect(_panel);
      final avatar = tester.getRect(_avatar);
      final name = tester.getRect(find.byKey(const ValueKey('vitrine-rail-name')));
      expect(name.left - avatar.right, 8);
      expect((avatar.left + name.right) / 2, closeTo(panel.center.dx, 0.01));
      expect(avatar.top, 30);
      expect(find.text('Bertini'), findsOneWidget);
    });

    testWidgets('the panel takes the panel colour and its edge, in both themes', (tester) async {
      for (final tokens in [_dark(), _light()]) {
        final h = await _pump(tester, tokens: tokens);
        await _openOn(tester, h);
        final box = tester.widget<DecoratedBox>(_panel).decoration as BoxDecoration;
        expect(box.color, tokens.panel, reason: tokens.brightness.name);
        expect((box.border as Border).right.color, tokens.panelEdge);
        expect((box.border as Border).right.width, 1);
        expect(box.boxShadow, tokens.panelShadow);
      }
      expect(_dark().panel, const Color(0xFF000000));
      expect(_light().panel, isNot(const Color(0xFF000000)));
    });

    testWidgets('labels: selected and focused read ink at w600, the rest ink-2', (tester) async {
      final h = await _pump(tester, tokens: _light());
      await _openOn(tester, h, VitrineDestination.music);
      TextStyle? style(String text) => tester.widget<Text>(find.text(text)).style;
      final t = _light();
      expect(style('Início')!.color, t.ink); // selected
      expect(style('Início')!.fontWeight, FontWeight.w600);
      expect(style('Música')!.color, t.ink); // focused
      expect(style('Música')!.fontWeight, FontWeight.w600);
      expect(style('Apps')!.color, t.ink2);
      expect(style('Apps')!.fontSize, 12);
    });
  });

  group('remote', () {
    testWidgets('OK on each item calls onSelected with its destination', (tester) async {
      final h = await _pump(tester);
      for (final d in VitrineDestination.values) {
        await _openOn(tester, h, d);
        await _key(tester, LogicalKeyboardKey.select);
      }
      expect(h.selected, VitrineDestination.values);
      expect(h.profile, 0);
    });

    testWidgets('every OK key of the app activates; holding OK activates once, on release', (tester) async {
      final h = await _pump(tester);
      await _openOn(tester, h, VitrineDestination.network);
      for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.gameButtonA, LogicalKeyboardKey.numpadEnter]) {
        await _key(tester, key);
      }
      expect(h.selected, hasLength(3));
      h.selected.clear();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
      expect(h.selected, isEmpty);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
      expect(h.selected, [VitrineDestination.network]);
    });

    testWidgets('OK on the avatar calls onProfile', (tester) async {
      final h = await _pump(tester);
      await _openOn(tester, h);
      await _key(tester, LogicalKeyboardKey.arrowUp);
      await _key(tester, LogicalKeyboardKey.select);
      expect(h.profile, 1);
      expect(h.selected, isEmpty);
    });

    testWidgets('Right and Back call onClose from an item and from the avatar; Left does not', (tester) async {
      final h = await _pump(tester);
      await _openOn(tester, h, VitrineDestination.apps);
      var expected = 0;
      for (final key in [
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.escape,
        LogicalKeyboardKey.gameButtonB,
      ]) {
        await _key(tester, key);
        expect(h.close, ++expected, reason: key.debugName);
      }
      await _key(tester, LogicalKeyboardKey.arrowLeft);
      expect(h.close, expected);
      h.controller.open();
      await tester.pumpAndSettle();
      await _key(tester, LogicalKeyboardKey.arrowUp);
      await _key(tester, LogicalKeyboardKey.arrowRight);
      expect(h.close, expected + 1);
    });

    testWidgets('a tap activates the item and the avatar', (tester) async {
      final h = await _pump(tester);
      await tester.tap(_item(VitrineDestination.settings));
      await tester.pump();
      await tester.tap(_avatar);
      await tester.pump();
      expect(h.selected, [VitrineDestination.settings]);
      expect(h.profile, 1);
    });
  });

  group('badge', () {
    testWidgets('no count, no badge', (tester) async {
      await _pump(tester);
      expect(_badge, findsNothing);
    });

    testWidgets('the count sits on the icon: 15 px, left 7.5 px into the icon, 5 px above the pill, open or closed', (tester) async {
      final h = await _pump(tester, count: 3);
      final pill = tester.getRect(_item(VitrineDestination.notifications));
      var badge = tester.getRect(_badge);
      expect(badge.size, const Size(15, 15));
      expect(badge.left, pill.left + 17);
      expect(badge.top, pill.top - 5);
      expect(find.text('3'), findsOneWidget);
      await _openOn(tester, h, VitrineDestination.apps);
      badge = tester.getRect(_badge);
      expect(badge.left, tester.getRect(_item(VitrineDestination.notifications)).left + 17);
      expect(badge.top, tester.getRect(_item(VitrineDestination.notifications)).top - 5);
    });

    testWidgets('its fill is the badge colour and its 2 px ring the colour under it, in both themes', (tester) async {
      for (final tokens in [_dark(), _light()]) {
        final h = await _pump(tester, tokens: tokens, count: 3);
        BoxDecoration box() => tester.widget<Container>(_badge).decoration as BoxDecoration;
        expect(box().color, tokens.badge, reason: tokens.brightness.name);
        expect((box().border as Border).top.color, tokens.badgeRing);
        expect((box().border as Border).top.width, 2);
        expect(tester.widget<Text>(find.text('3')).style!.fontSize, 11);
        await _openOn(tester, h, VitrineDestination.apps);
        // Open, the ring takes the panel's colour.
        expect((box().border as Border).top.color, tokens.panel, reason: tokens.brightness.name);
      }
    });

    testWidgets('a long count widens the badge and stops at 99+; the label says the count', (tester) async {
      await _pump(tester, count: 120);
      expect(find.text('99+'), findsOneWidget);
      expect(tester.getSize(_badge).width, greaterThan(15));
      expect(tester.getSize(_badge).height, 15);
      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Notificações, 120'), findsOneWidget);
      handle.dispose();
    });
  });

  group('profile', () {
    testWidgets('the avatar is the profile in use: its colour, initial and name', (tester) async {
      final h = await _pump(tester, profile: LauncherProfile(id: 'p', name: 'ana', color: 0xFF10B981));
      expect(find.text('A'), findsOneWidget);
      expect((tester.widget<Container>(_avatar).decoration as BoxDecoration).color, const Color(0xFF10B981));
      await _openOn(tester, h);
      expect(find.text('ana'), findsOneWidget);
      expect(find.text('Bertini'), findsNothing);
      expect(tester.getRect(_avatar).top, 30);
    });

    testWidgets('a long name never widens the panel', (tester) async {
      final h = await _pump(tester, profile: LauncherProfile(id: 'p', name: 'Maria Eduarda da Silva Sauro', color: 0xFF10B981));
      await _openOn(tester, h);
      expect(tester.getSize(_panel).width, closeTo(187, 1));
      final name = tester.getRect(find.byKey(const ValueKey('vitrine-rail-name')));
      expect(name.right, lessThanOrEqualTo(tester.getRect(_item(VitrineDestination.apps)).right));
    });
  });

  group('every item is named for accessibility', () {
    testWidgets('pt-BR and English', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);
      for (final label in ['Início', 'Apps', 'TV', 'Música', 'Notificações', 'Rede', 'Configurações', 'Perfil Bertini']) {
        expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      }
      await _pump(tester, language: 'en');
      for (final label in ['Home', 'Apps', 'TV', 'Music', 'Notifications', 'Network', 'Settings', 'Profile Bertini']) {
        expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      }
      handle.dispose();
    });
  });

  group('the rail with the signature', () {
    testWidgets('one line, 22 px above the bottom, centred on x 47 collapsed and in the panel open', (tester) async {
      final h = await _pump(tester);
      Rect mark() => tester.getRect(find.byType(DevBertiniMark));
      double nameRight() => tester.getRect(find.textContaining('Bertini', findRichText: true).last).right;
      expect(tester.getBottomLeft(find.byType(VitrineSignature)).dy, 540 - 22);
      expect(mark().size, const Size(10, 10));
      expect((mark().left + nameRight()) / 2, closeTo(47, 0.01));

      await _openOn(tester, h);
      final panel = tester.getRect(_panel);
      expect((mark().left + nameRight()) / 2, closeTo(panel.center.dx, 0.01));
      expect(tester.getBottomLeft(find.byType(VitrineSignature)).dy, 540 - 22);
    });
  });

  group('signature', () {
    Future<void> pumpSignature(WidgetTester tester, VitrineTokens tokens, {double width = 94}) {
      return tester.pumpWidget(
        VitrineTheme(
          tokens: tokens,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: width, child: const VitrineSignature()),
            ),
          ),
        ),
      );
    }

    testWidgets('the name is dev in accent-ink and Bertini in ink-2 at 80%, and nothing follows it, in both themes',
        (tester) async {
      for (final tokens in [_dark(), _light()]) {
        await pumpSignature(tester, tokens);
        final text = (tester.widget<RichText>(find.textContaining('Bertini', findRichText: true).first)).text as TextSpan;
        final spans = text.children!.single as TextSpan; // Text.rich wraps the span it is given
        final dev = spans.children![0] as TextSpan;
        final bertini = spans.children![1] as TextSpan;
        expect(dev.text, 'dev');
        expect(dev.style!.color, tokens.accentInk.withValues(alpha: 0.8), reason: tokens.brightness.name);
        expect(bertini.style!.color, tokens.ink2.withValues(alpha: 0.8));
        expect(spans.style!.fontSize, 10);
        expect(spans.style!.fontWeight, FontWeight.w700);
        expect(find.descendant(of: find.byType(VitrineSignature), matching: find.byType(CustomPaint)), findsOneWidget,
            reason: 'the mark only');
        expect(find.descendant(of: find.byType(VitrineSignature), matching: find.byType(Text)), findsOneWidget,
            reason: 'the name only');
      }
    });

    testWidgets('it takes no pointer and sits in its own layer', (tester) async {
      await pumpSignature(tester, _dark(), width: 187);
      expect(find.descendant(of: find.byType(VitrineSignature), matching: find.byType(IgnorePointer)), findsOneWidget);
      expect(find.descendant(of: find.byType(VitrineSignature), matching: find.byType(RepaintBoundary)), findsWidgets);
      expect(tester.getSize(find.byType(VitrineSignature)).width, 187);
    });
  });
}
