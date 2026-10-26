/*
 * DevBertini theme for LTvLauncher (GPL-3.0, like the rest of this project).
 * Copyright (C) 2026 Claudio Bertini (devBertini)
 *
 * The studio's signature at the bottom of the Vitrine rail (docs/devbertini/DESIGN-VITRINE.md, "Signature").
 */

import 'package:flauncher/devbertini/devbertini_intro.dart';
import 'package:flauncher/devbertini/vitrine/dedication.dart';
import 'package:flauncher/devbertini/vitrine/tokens.dart';
import 'package:flutter/widgets.dart';

/// The devBertini mark with the name, centred in the width the parent gives. A build with a dedication
/// ([VitrineDedication]) puts it under the name while the rail is collapsed and after it, on one line, when [open].
/// It is discreet (the mark and the name at 80%), sits in its own layer and never takes the pointer. It does not place
/// itself: the rail puts it 22 px above its bottom.
class VitrineSignature extends StatelessWidget {
  final bool open;

  const VitrineSignature({super.key, this.open = false});

  /// The mark and the type are 10 px.
  static const double markSize = 10;

  @override
  Widget build(BuildContext context) {
    final t = VitrineTheme.of(context);
    final studio = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Opacity(
          opacity: 0.8,
          child: SizedBox.square(dimension: markSize, child: DevBertiniMark()),
        ),
        const SizedBox(width: 4),
        Text.rich(
          TextSpan(
            style: vitrineText(10, weight: 700, line: 12),
            children: [
              TextSpan(text: 'dev', style: TextStyle(color: t.accentInk.withValues(alpha: 0.8))),
              TextSpan(text: 'Bertini', style: TextStyle(color: t.ink2.withValues(alpha: 0.8))),
            ],
          ),
          maxLines: 1,
          softWrap: false,
          textScaler: TextScaler.noScaling,
        ),
      ],
    );
    final dedication = VitrineDedication.of(t);
    return RepaintBoundary(
      child: IgnorePointer(
        child: DefaultTextStyle(
          style: const TextStyle(decoration: TextDecoration.none),
          child: Center(
            heightFactor: 1,
            // Never wider than the room it is given (the rail is still opening): it only scales down then.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: dedication == null
                  ? studio
                  : open
                      ? Row(mainAxisSize: MainAxisSize.min, children: [studio, const SizedBox(width: 8), dedication])
                      : Column(mainAxisSize: MainAxisSize.min, children: [studio, const SizedBox(height: 2), dedication]),
            ),
          ),
        ),
      ),
    );
  }
}
