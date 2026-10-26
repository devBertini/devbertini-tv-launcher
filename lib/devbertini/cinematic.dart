/*
 * DevBertini theme for LTvLauncher (GPL-3.0, like the rest of this project).
 *
 * Shared pieces of the Vitrine home (docs/devbertini/DESIGN-VITRINE.md): the launch fade, the Home-again
 * signal, the screen area, scrolling a focused card into view and the settings rows.
 */

import 'dart:async';

import 'package:flauncher/devbertini/vitrine/focus.dart';
import 'package:flauncher/devbertini/vitrine/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Set while an app opens: the home fades to black at once, so the wait for the app's first frame
/// reads as the app opening instead of a home stuck on the pressed card.
final ValueNotifier<bool> devBertiniLaunching = ValueNotifier(false);

/// Home pressed, from an app or with the home in front: [press] tells the Vitrine home, which goes back to its start.
class DevBertiniHomeAgain extends ChangeNotifier {
  void press() => notifyListeners();
}

/// The launcher's one [DevBertiniHomeAgain]: FLauncherChannel presses it when Android hands the home its Home intent
/// again (MainActivity.onNewIntent).
final DevBertiniHomeAgain devBertiniHomeAgain = DevBertiniHomeAgain();

/// Starts the fade to black of an app launch; it lifts when the home comes back, or after 4 s if
/// the app never opened.
void devBertiniStartLaunch() {
  devBertiniLaunching.value = true;
  Future.delayed(const Duration(seconds: 4), () => devBertiniLaunching.value = false);
}

/// One of the TV's own functions on the home screen.
class TvControl {
  final String id;
  final IconData icon;
  final String labelPt;
  final String labelEn;

  const TvControl(this.id, this.icon, this.labelPt, this.labelEn);

  static const List<TvControl> all = [
    TvControl('inputs', Icons.input_rounded, 'Entradas', 'Inputs'),
    TvControl('picture', Icons.tune_rounded, 'Imagem', 'Picture'),
    TvControl('sound', Icons.surround_sound_rounded, 'Som', 'Sound'),
    TvControl('game', Icons.sports_esports_rounded, 'Modo jogo', 'Game mode'),
    TvControl('quick', Icons.dashboard_customize_rounded, 'Painel rápido', 'Quick panel'),
    TvControl('energy', Icons.eco_rounded, 'Energia', 'Energy'),
  ];
}

/// Shrinks everything inside to [area] of the screen, centred on true black, like a console's
/// "adjust display area".
class DevBertiniScreenArea extends StatelessWidget {
  final double area;
  final Widget child;

  const DevBertiniScreenArea({super.key, required this.area, required this.child});

  @override
  Widget build(BuildContext context) {
    // One tree for every value: returning the bare child at 100% would rebuild everything under it
    // (open panels, focus) the moment the area changes.
    return ColoredBox(
      color: Colors.black,
      child: ClipRect(
        child: Transform.scale(scale: area, child: child),
      ),
    );
  }
}

/// Scrolls every list holding [context] (the row, then the page) only as far as needed to show it
/// with a peek of its neighbours, instead of centring it: centring cuts the first cards of a short
/// row in half. Completes when the lists stopped moving (at once when none had to move).
Future<void> revealInScrollables(BuildContext context, {double peek = 56}) {
  final moves = <Future<void>>[];
  final target = context.findRenderObject();
  if (target == null) return Future.value();
  var viewport = RenderAbstractViewport.maybeOf(target);
  var scrollable = Scrollable.maybeOf(context);
  var margin = peek;
  while (viewport != null && scrollable != null) {
    final position = scrollable.position;
    final alignStart = viewport.getOffsetToReveal(target, 0.0).offset - margin;
    final alignEnd = viewport.getOffsetToReveal(target, 1.0).offset + margin;
    var offset = position.pixels;
    if (offset > alignStart) {
      offset = alignStart;
    } else if (offset < alignEnd) {
      offset = alignEnd;
    }
    offset = offset.clamp(position.minScrollExtent, position.maxScrollExtent);
    if ((offset - position.pixels).abs() > 0.5) {
      // While the home is not in front (Home pressed from an app) nobody sees the move, and an animation would only
      // run once the home shows: the list jumps, so the home comes back already in place.
      final state = WidgetsBinding.instance.lifecycleState;
      if (state == null || state == AppLifecycleState.resumed) {
        moves.add(position.animateTo(offset, duration: const Duration(milliseconds: 180), curve: Curves.easeOutCubic));
      } else {
        position.jumpTo(offset);
      }
    }
    final parent = (viewport as RenderObject).parent;
    viewport = parent == null ? null : RenderAbstractViewport.maybeOf(parent);
    scrollable = Scrollable.maybeOf(scrollable.context);
    margin = 24;
  }
  return Future.wait(moves);
}

/// Moves the focus to the widget under the mouse (an air mouse), so a pointer behaves like the remote's
/// cursor.
class HoverFocus extends StatelessWidget {
  final Widget child;

  const HoverFocus({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => Focus.maybeOf(context)?.requestFocus(),
      child: child,
    );
  }
}

/// A settings row: tinted icon square, title with its current value under it, chevron. Focused it takes the
/// Vitrine focus: a plate fill with the 3 px accent ring (scale 1, the rows are close together). Colours come from the
/// Vitrine tokens, so it reads on the dark and the light panel.
class DevBertiniTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final IconData trailing;
  final bool autofocus;
  final VoidCallback onPressed;
  final KeyEventResult Function(KeyEvent event)? onKey;
  final Widget? value;

  const DevBertiniTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing = Icons.chevron_right_rounded,
    this.autofocus = false,
    required this.onPressed,
    this.onKey,
    this.value,
  });

  @override
  State<DevBertiniTile> createState() => _DevBertiniTileState();
}

class _DevBertiniTileState extends State<DevBertiniTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final t = VitrineTheme.of(context);
    return Actions(
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onPressed()),
        ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(onInvoke: (_) => widget.onPressed()),
      },
      child: Focus(
        autofocus: widget.autofocus,
        onKeyEvent: widget.onKey == null ? null : (_, event) => widget.onKey!(event),
        onFocusChange: (focused) {
          setState(() => _focused = focused);
          if (focused) Scrollable.ensureVisible(context, alignment: 0.5, duration: const Duration(milliseconds: 100));
        },
        child: HoverFocus(
          child: GestureDetector(
            onTap: widget.onPressed,
            // Room for the ring between neighbouring rows.
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: VitrineFocusFrame(
                focused: _focused,
                radius: 12,
                scale: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _focused ? (t.isDark ? t.quiet : t.plate) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  // Tight enough that the whole settings list fits the TV's height without scrolling.
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: t.accentTint,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(widget.icon, size: 17, color: t.accentInk),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(widget.title, style: vitrineText(14, weight: 500, color: t.ink)),
                              if (widget.subtitle != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 1),
                                  child: Text(
                                    widget.subtitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: vitrineText(12, color: t.ink2),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (widget.value != null)
                          DefaultTextStyle.merge(
                            style: TextStyle(color: t.ink),
                            child: IconTheme.merge(
                              data: IconThemeData(color: t.ink),
                              child: widget.value!,
                            ),
                          )
                        else
                          Icon(widget.trailing, size: 18, color: t.ink3),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The value part of a setting adjusted in place with left and right: ‹ value ›.
class DevBertiniStepperValue extends StatelessWidget {
  final String text;

  const DevBertiniStepperValue(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.chevron_left_rounded, size: 18),
        SizedBox(
          width: 54,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: vitrineText(13, weight: 600),
          ),
        ),
        const Icon(Icons.chevron_right_rounded, size: 18),
      ],
    );
  }
}
