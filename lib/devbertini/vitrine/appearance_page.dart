/*
 * DevBertini theme for LTvLauncher (GPL-3.0, like the rest of this project).
 *
 * Configurações > Tela inicial > Aparência: the theme (Claro, Escuro, Automático) and the accent colour (the five
 * palettes), as the approved mockup draws them (docs/devbertini/DESIGN-VITRINE.md; the mockup's .panel, .themes,
 * .theme-opt, .mini, .accents rules). Every colour comes from the Vitrine tokens; the minis are painted shapes.
 */

import 'dart:math' as math;

import 'package:flauncher/devbertini/brand.dart';
import 'package:flauncher/devbertini/cinematic.dart';
import 'package:flauncher/devbertini/vitrine/focus.dart';
import 'package:flauncher/devbertini/vitrine/tokens.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The Aparência page of the settings panel. It sizes itself to the panel it sits in (the mockup's 384 px panel gives
/// it 308 px of content); the panel supplies the padding around it.
class VitrineAppearancePage extends StatelessWidget {
  const VitrineAppearancePage({super.key});

  static bool _pt(BuildContext context) => Localizations.maybeLocaleOf(context)?.languageCode == 'pt';

  @override
  Widget build(BuildContext context) {
    final t = VitrineTheme.of(context);
    final pt = _pt(context);
    final appearance = context.select<SettingsService, String>((settings) => settings.appearance);
    final themes = context.select<SettingsService, String>((settings) => settings.themes);
    final settings = context.read<SettingsService>();
    // A value this build does not know is drawn dark, as vitrineBrightness does.
    final chosen = appearance == appearanceLight || appearance == appearanceAuto ? appearance : appearanceDark;

    final lightTokens = VitrineTokens.of(t.palette, Brightness.light);
    final darkTokens = VitrineTokens.of(t.palette, Brightness.dark);

    Widget card(String value, String name) => Expanded(
      child: _Pressable(
        label: name,
        selected: chosen == value,
        autofocus: chosen == value,
        onPressed: () => settings.setAppearance(value),
        builder: (context, focused) => _ThemeCard(
          name: name,
          mini: _Mini(variant: value, light: lightTokens, dark: darkTokens),
          selected: chosen == value,
          focused: focused,
        ),
      ),
    );

    return Material(
      type: MaterialType.transparency,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 16, 32, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Crumb(pt ? 'Configurações' : 'Settings', pt ? 'Tela inicial' : 'Home screen'),
            const SizedBox(height: 4),
            Text(
              pt ? 'Aparência' : 'Appearance',
              style: vitrineText(26, weight: 500, color: t.ink, line: 32, tracking: -0.5),
            ),
            const SizedBox(height: 20),
            Text(pt ? 'Tema' : 'Theme', style: vitrineText(15, weight: 600, color: t.ink, line: 18)),
            const SizedBox(height: 10),
            Row(
              spacing: 10,
              children: [
                card(appearanceLight, pt ? 'Claro' : 'Light'),
                card(appearanceDark, pt ? 'Escuro' : 'Dark'),
                card(appearanceAuto, pt ? 'Automático' : 'Automatic'),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              pt
                  ? 'Automático fica escuro das 22h às 6h, no mesmo horário do Modo noite.'
                  : 'Automatic turns dark from 10 pm to 6 am, the same hours as Night mode.',
              style: vitrineText(13, color: t.ink2, line: 18),
            ),
            const SizedBox(height: 20),
            Text(pt ? 'Cor de destaque' : 'Accent color', style: vitrineText(15, weight: 600, color: t.ink, line: 18)),
            const SizedBox(height: 8),
            for (final palette in CinematicPalette.all) ...[
              if (palette != CinematicPalette.all.first) const SizedBox(height: 4),
              _Pressable(
                label: palette.name,
                selected: themes == palette.id,
                onPressed: () => settings.setThemes(palette.id),
                builder: (context, focused) =>
                    _AccentRow(palette: palette, selected: themes == palette.id, focused: focused),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// What a card or a row sits on when it is selected or focused: the quiet fill on black, the white plate on light.
Color _fill(VitrineTokens t) => t.isDark ? t.quiet : t.plate;

/// The page's small "Configurações > Tela inicial" line.
class _Crumb extends StatelessWidget {
  final String parent;
  final String child;

  const _Crumb(this.parent, this.child);

  @override
  Widget build(BuildContext context) {
    final t = VitrineTheme.of(context);
    final style = vitrineText(13, color: t.ink2, line: 18);
    return Row(
      children: [
        Text(parent, style: style),
        // The mockup's .chev: a 6 px square showing its top and right edges, turned 45 degrees.
        Padding(
          padding: const EdgeInsets.fromLTRB(7, 0, 8, 0),
          child: Transform.rotate(
            angle: math.pi / 4,
            child: SizedBox.square(
              dimension: 6,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: t.ink3, width: 1.5),
                    right: BorderSide(color: t.ink3, width: 1.5),
                  ),
                ),
              ),
            ),
          ),
        ),
        Text(child, style: style),
      ],
    );
  }
}

/// A focusable choice: OK (or a tap) calls [onPressed]; [builder] draws it from its own focus state, so a focus move
/// rebuilds only the choice that gains it and the one that loses it.
class _Pressable extends StatefulWidget {
  final String label;
  final bool selected;
  final bool autofocus;
  final VoidCallback onPressed;
  final Widget Function(BuildContext context, bool focused) builder;

  const _Pressable({
    required this.label,
    required this.selected,
    this.autofocus = false,
    required this.onPressed,
    required this.builder,
  });

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      excludeSemantics: true,
      onTap: widget.onPressed,
      child: Actions(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onPressed()),
          ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(onInvoke: (_) => widget.onPressed()),
        },
        child: Focus(
          autofocus: widget.autofocus,
          onFocusChange: (focused) {
            setState(() => _focused = focused);
            if (focused) Scrollable.ensureVisible(context, alignment: 0.5, duration: const Duration(milliseconds: 100));
          },
          child: HoverFocus(
            child: GestureDetector(onTap: widget.onPressed, child: widget.builder(context, _focused)),
          ),
        ),
      ),
    );
  }
}

/// One theme card: the mini home, then the name (and a check on the chosen one).
class _ThemeCard extends StatelessWidget {
  final String name;
  final Widget mini;
  final bool selected;
  final bool focused;

  const _ThemeCard({required this.name, required this.mini, required this.selected, required this.focused});

  @override
  Widget build(BuildContext context) {
    final t = VitrineTheme.of(context);
    return VitrineFocusFrame(
      focused: focused,
      radius: 12,
      scale: 1.06,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? t.accentTint : _fill(t),
          borderRadius: BorderRadius.circular(12),
          border: selected ? null : Border.all(color: t.plateEdge),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 52, width: double.infinity, child: mini),
              SizedBox(
                height: 30,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: vitrineText(13, weight: 600, color: selected ? t.accentInk : t.ink),
                        ),
                      ),
                      if (selected) Icon(Icons.check_rounded, size: 16, color: t.accentInk),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One accent row: the palette's swatch for the theme in force, its name and a check on the chosen one.
class _AccentRow extends StatelessWidget {
  final CinematicPalette palette;
  final bool selected;
  final bool focused;

  const _AccentRow({required this.palette, required this.selected, required this.focused});

  @override
  Widget build(BuildContext context) {
    final t = VitrineTheme.of(context);
    return VitrineFocusFrame(
      focused: focused,
      radius: 10,
      scale: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected || focused ? _fill(t) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          // The selected row keeps a 1 px edge on the light field; on black the fill alone sets it apart.
          border: selected && !t.isDark ? Border.all(color: t.plateEdge) : null,
        ),
        child: SizedBox(
          height: 34,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: t.isDark ? palette.blackTone : palette.lightTone,
                  ),
                  child: const SizedBox.square(dimension: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    palette.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: vitrineText(14, weight: selected ? 600 : 500, color: t.ink),
                  ),
                ),
                if (selected) Icon(Icons.check_rounded, size: 18, color: t.accentInk),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The small picture of a theme: a home drawn with a few shapes (the mockup's .mini). It shows [variant] whatever the
/// theme in force is, so it takes the light and the dark tokens of the palette; the greys of the rail, the art and the
/// dark plates are illustration colours, not interface ones.
class _Mini extends StatelessWidget {
  final String variant;
  final VitrineTokens light;
  final VitrineTokens dark;

  const _Mini({required this.variant, required this.light, required this.dark});

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _MiniPainter(variant, light, dark));
}

class _MiniPainter extends CustomPainter {
  final String variant;
  final VitrineTokens light;
  final VitrineTokens dark;

  const _MiniPainter(this.variant, this.light, this.dark);

  static const Color _railOnLight = Color(0xFF9AA3AF);
  static const Color _railOnDark = Color(0xFF4A505A);
  static const Color _artOnLight = Color(0xFF6B6A63);
  static const Color _artOnDark = Color(0xFF5D5C55);
  static const Color _plateOnDark = Color(0xFF20232A);

  @override
  void paint(Canvas canvas, Size size) {
    final isDark = variant == appearanceDark;
    final isAuto = variant == appearanceAuto;
    final w = size.width;
    final h = size.height;
    final frame = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(7));
    canvas.save();
    canvas.clipRRect(frame);

    canvas.drawRect(Offset.zero & size, Paint()..color = isDark ? dark.field : light.field);
    if (isDark) {
      canvas.drawRRect(
        frame.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = dark.plateEdge,
      );
    }
    if (isAuto) {
      // The mockup's linear-gradient(135deg, transparent 50%, black 50%): everything past the anti-diagonal through
      // the centre, which is the half-plane x + y > (w + h) / 2.
      final s = (w + h) / 2;
      final half = Path()
        ..moveTo(s + 1000, -1000)
        ..lineTo(s - 1000, 1000)
        ..lineTo(s + 2000, 4000)
        ..lineTo(s + 4000, 2000)
        ..close();
      canvas.drawPath(half, Paint()..color = dark.field);
    }

    // The rail: 12x36 at (5, 8), radius 3, a 2 px line every 7 px.
    final rail = RRect.fromRectAndRadius(const Rect.fromLTWH(5, 8, 12, 36), const Radius.circular(3));
    canvas.save();
    canvas.clipRRect(rail);
    final railPaint = Paint()..color = isDark ? _railOnDark : _railOnLight;
    for (double y = 0; y < 36; y += 7) {
      canvas.drawRect(Rect.fromLTWH(5, 8 + y, 12, math.min(2, 36 - y)), railPaint);
    }
    canvas.restore();

    // The artwork: 46x28 at the top right, fading in from the left to its colour at 70%, at 85% opacity.
    final art = isDark || isAuto ? _artOnDark : _artOnLight;
    final artRect = Rect.fromLTWH(w - 46, 0, 46, 28);
    canvas.drawRect(
      artRect,
      Paint()
        ..shader = LinearGradient(
          colors: [art.withValues(alpha: 0), art.withValues(alpha: 0.85), art.withValues(alpha: 0.85)],
          stops: const [0, 0.7, 1],
        ).createShader(artRect),
    );

    // Four plates: from x 22 to 5 px short of the right edge, 8 px tall, 7 px above the bottom, 3 px apart.
    const gap = 3.0;
    final plateW = (w - 22 - 5 - gap * 3) / 4;
    for (var i = 0; i < 4; i++) {
      final onDark = isDark || (isAuto && i >= 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(22 + i * (plateW + gap), h - 7 - 8, plateW, 8), const Radius.circular(2)),
        Paint()..color = onDark ? _plateOnDark : light.plate,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MiniPainter old) => old.variant != variant || old.light != light || old.dark != dark;
}
