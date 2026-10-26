import 'package:flauncher/actions.dart';
import 'package:flauncher/devbertini/brand.dart';
import 'package:flauncher/devbertini/vitrine/tokens.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SidePanelDialog extends StatelessWidget {
  final Widget child;
  final double width;
  final bool isRightSide;

  const SidePanelDialog({super.key, 
    required this.child,
    this.width = 250,
    this.isRightSide = false,
  });

  @override
  Widget build(BuildContext context) {
    if (context.select<SettingsService, bool>((settings) => isCinematicTheme(settings.themes))) {
      // Vitrine: a full-height panel in the panel colour of the theme in force, with a 1 px edge on its inner side and,
      // on the light field, its soft shadow (cast towards the content).
      final t = VitrineTheme.of(context);
      return Align(
        alignment: isRightSide ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: width,
          height: double.infinity,
          decoration: BoxDecoration(
            color: t.panel,
            boxShadow: [
              for (final shadow in t.panelShadow)
                BoxShadow(
                  color: shadow.color,
                  blurRadius: shadow.blurRadius,
                  offset: isRightSide ? Offset(-shadow.offset.dx, shadow.offset.dy) : shadow.offset,
                ),
            ],
          ),
          // The 1 px edge on the inner side is painted over the panel, so it takes none of the content's width.
          foregroundDecoration: BoxDecoration(
            border: Border(
              left: isRightSide ? BorderSide(color: t.panelEdge) : BorderSide.none,
              right: isRightSide ? BorderSide.none : BorderSide(color: t.panelEdge),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          child: Material(
            type: MaterialType.transparency,
            child: Actions(
              actions: {BackIntent: BackAction(context)},
              child: child,
            ),
          ),
        ),
      );
    }

    final borderRadius = BorderRadius.horizontal(
      right: isRightSide ? Radius.zero : const Radius.circular(24),
      left: isRightSide ? const Radius.circular(24) : Radius.zero,
    );

    return Align(
      alignment: isRightSide ? Alignment.centerRight : Alignment.centerLeft,
      child: Material(
        color: const Color(0xFF0F0F0F),
        elevation: 24,
        shadowColor: Colors.black,
        borderRadius: borderRadius,
        child: Container(
          width: width,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Actions(
            actions: { BackIntent: BackAction(context) },
            child: child,
          ),
        ),
      ),
    );
  }
}
