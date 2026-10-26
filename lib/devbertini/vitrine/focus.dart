/*
 * DevBertini theme for LTvLauncher (GPL-3.0, like the rest of this project).
 */

import 'package:flauncher/devbertini/vitrine/tokens.dart';
import 'package:flutter/material.dart';

/// How long the focus takes to grow and shrink.
const Duration vitrineFocusDuration = Duration(milliseconds: 120);

/// The Vitrine focus around [child] (docs/devbertini/DESIGN-VITRINE.md): a 3 px accent ring outside its rounded
/// shape, a small scale ([scale]: 1.06 for plates and cards, 1.05 for rail pills) and, on the light field only, the
/// one soft shadow. The ring and the shadow are painted around a child kept in its own layer, so a focus change
/// repaints only this element and the scale only re-composites that layer.
class VitrineFocusFrame extends StatelessWidget {
  final bool focused;
  final double radius;
  final double scale;
  final Widget child;

  const VitrineFocusFrame({
    super.key,
    required this.focused,
    required this.radius,
    this.scale = 1.06,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final t = VitrineTheme.of(context);
    final shape = BorderRadius.circular(radius);
    return AnimatedScale(
      scale: focused ? scale : 1,
      duration: vitrineFocusDuration,
      curve: Curves.easeOutCubic,
      child: DecoratedBox(
        position: DecorationPosition.background,
        decoration: BoxDecoration(borderRadius: shape, boxShadow: focused ? t.focusShadow : const []),
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: focused
              ? BoxDecoration(
                  borderRadius: shape,
                  border: Border.all(color: t.accent, width: 3, strokeAlign: BorderSide.strokeAlignOutside),
                )
              : const BoxDecoration(),
          child: RepaintBoundary(child: child),
        ),
      ),
    );
  }
}
