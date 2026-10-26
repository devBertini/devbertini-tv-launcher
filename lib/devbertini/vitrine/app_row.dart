/*
 * DevBertini theme for LTvLauncher (GPL-3.0, like the rest of this project).
 * Copyright (C) 2026 Claudio Bertini (devBertini)
 */

import 'package:flauncher/devbertini/vitrine/plate.dart';
import 'package:flauncher/devbertini/vitrine/tokens.dart';
import 'package:flauncher/models/category.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:provider/provider.dart';

/// The room the focus ring and the scaled plate need around the row: 3 px ring + 6% of the plate, rounded up.
const double _ringRoom = 10;

/// The Apps row of the Vitrine home (docs/devbertini/DESIGN-VITRINE.md, "Apps"): the label, 9 px, then the plates
/// (gap 14) in a horizontal list built lazily, "Todos" last. It fills the width its parent gives (the home gives it
/// from x 100 to the screen's right edge) and sizes itself: 18 + 9 + 71 px tall. The focused plate is kept whole in
/// view with the next one peeking.
class VitrineAppRow extends StatelessWidget {
  final Category category;

  /// OK on "Todos".
  final VoidCallback onAll;

  /// The first plate takes this focus node (and "Todos" does when the category has no apps).
  final FocusNode? firstFocusNode;
  final bool autofocusFirst;

  /// Left pressed on the first plate.
  final VoidCallback? onLeftFromFirst;

  const VitrineAppRow({
    super.key,
    required this.category,
    required this.onAll,
    this.firstFocusNode,
    this.autofocusFirst = false,
    this.onLeftFromFirst,
  });

  @override
  Widget build(BuildContext context) {
    final t = VitrineTheme.of(context);
    // The row follows the order of the apps (a plate moved, an app installed or hidden) and nothing else the service
    // announces.
    context.select<AppsService, String>((_) => category.applications.map((a) => a.packageName).join(','));
    final apps = category.applications;
    final count = apps.length;
    final byPackage = {for (var i = 0; i < count; i++) apps[i].packageName: i};
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Apps',
          style: vitrineText(15, weight: 600, color: t.ink, line: 18),
        ),
        const SizedBox(height: 9),
        RepaintBoundary(
          child: ClipRect(
            clipper: const _RingRoomClipper(),
            child: SizedBox(
              height: vitrinePlateHeight,
              child: ListView.builder(
                key: ValueKey('vitrine-apps-${category.id}'),
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemExtent: vitrinePlateWidth + vitrinePlateGap,
                // Items built well past the edge: a held arrow then always finds the next one, instead of losing a press
                // while the row is still scrolling to it.
                scrollCacheExtent: const ScrollCacheExtent.pixels(640),
                itemCount: count + 1,
                // A plate keeps its state (the move mode) when the order changes.
                findChildIndexCallback: (key) {
                  if (key is ValueKey<String> && key.value.startsWith(_keyPrefix)) {
                    return byPackage[key.value.substring(_keyPrefix.length)];
                  }
                  return null;
                },
                itemBuilder: (context, index) {
                  final first = index == 0;
                  if (index == count) {
                    return Align(
                      key: const ValueKey('${_keyPrefix}all'),
                      alignment: Alignment.centerLeft,
                      child: VitrineAllPlate(
                        onPressed: onAll,
                        focusNode: first ? firstFocusNode : null,
                        autofocus: first && autofocusFirst,
                        onLeftEdge: first ? onLeftFromFirst : null,
                      ),
                    );
                  }
                  final app = apps[index];
                  return Align(
                    key: ValueKey('$_keyPrefix${app.packageName}'),
                    alignment: Alignment.centerLeft,
                    child: VitrinePlate(
                      app: app,
                      category: category,
                      focusNode: first ? firstFocusNode : null,
                      autofocus: first && autofocusFirst,
                      onLeftEdge: first ? onLeftFromFirst : null,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

const String _keyPrefix = 'plate:';

/// Lets the focus ring and the grown plate paint past the list's own edge, which would cut them, and nothing else.
class _RingRoomClipper extends CustomClipper<Rect> {
  const _RingRoomClipper();

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(-_ringRoom, -_ringRoom, size.width + _ringRoom, size.height + _ringRoom);

  @override
  bool shouldReclip(_RingRoomClipper oldClipper) => false;
}
