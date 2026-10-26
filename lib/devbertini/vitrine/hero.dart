/*
 * DevBertini theme for LTvLauncher (GPL-3.0, like the rest of this project).
 */

import 'dart:ui' as ui;

import 'package:flauncher/devbertini/cinematic.dart';
import 'package:flauncher/devbertini/tv_extras.dart';
import 'package:flauncher/devbertini/vitrine/field.dart';
import 'package:flauncher/devbertini/vitrine/focus.dart';
import 'package:flauncher/devbertini/vitrine/logos.dart';
import 'package:flauncher/devbertini/vitrine/tokens.dart';
import 'package:flauncher/models/watch_next_program.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/watch_next_service.dart';
import 'package:flauncher/widgets/app_card_keys.dart';
import 'package:flauncher/widgets/watch_next_info_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// Where the hero's art sits on the 960x540 screen (docs/devbertini/DESIGN-VITRINE.md, "Hero art"): it bleeds off the
/// top and the right edge.
const double _artLeft = 236, _artTop = -30, _artWidth = 790, _artHeight = 444;

/// The painted overlay's box: the screen's width, down to y 416.
const double _fadeWidth = 960, _fadeHeight = 416;

/// Whether [uri] is a web address the art can be read from (Android's own content:// addresses are not).
bool _isWeb(String uri) => uri.startsWith('http://') || uri.startsWith('https://');

/// The three gradients of the mockup's `.hero-fade`, painted in the field's colour with the alphas of the theme:
/// the art dissolves towards the left (solid to x 380, clear at 600), towards the right edge so the clock reads
/// (0.94 at the edge, clear 290 px in) and downwards (clear at y 221, solid at 361). Each is painted only over the
/// rectangle where it is not clear.
class _HeroFadePainter extends CustomPainter {
  final Color down;
  final Color side;
  final bool dark;

  const _HeroFadePainter(this.down, this.side, this.dark);

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    // Right: 0.94 at the edge, the theme's alpha at 150 px, 0.5 at 215 px, clear at 290 px.
    final right = Rect.fromLTRB(size.width - 290, 0, size.width, h);
    canvas.drawRect(
      right,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
          colors: [
            side.withValues(alpha: 0.94),
            side.withValues(alpha: dark ? 0.88 : 0.9),
            side.withValues(alpha: 0.5),
            side.withValues(alpha: 0),
          ],
          stops: const [0, 150 / 290, 215 / 290, 1],
        ).createShader(right),
    );
    // Left: solid to 380, then the theme's alpha at 430, 0.35 at 520, clear at 600.
    final left = Rect.fromLTRB(0, 0, 600, h);
    canvas.drawRect(
      left,
      Paint()
        ..shader = LinearGradient(
          colors: [
            side,
            side.withValues(alpha: dark ? 0.85 : 0.86),
            side.withValues(alpha: 0.35),
            side.withValues(alpha: 0),
          ],
          stops: const [380 / 600, 430 / 600, 520 / 600, 1],
        ).createShader(left),
    );
    // Down: clear at 221, the theme's alpha at 306, solid at 361 and on to the bottom of the box.
    final below = Rect.fromLTRB(0, 221, size.width, h);
    canvas.drawRect(
      below,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [down.withValues(alpha: 0), down.withValues(alpha: dark ? 0.78 : 0.75), down],
          stops: [0, (306 - 221) / (h - 221), (361 - 221) / (h - 221)],
        ).createShader(below),
    );
  }

  @override
  bool shouldRepaint(_HeroFadePainter old) => old.down != down || old.side != side || old.dark != dark;
}

/// The home's backdrop: the field, the art of the newest Watch Next program under its three fades and, in Modo noite,
/// the art a little darker, painted together into one picture of the screen whenever one of them changes, and drawn
/// every frame as that single image. Painted live, the art, the gradients over it and the field took the TCL's
/// Mali-G52 about 15 ms of GPU every frame, so moving along a row missed a third of its frames
/// (docs/devbertini/PERFORMANCE.md).
///
/// The art is the program's own picture when its app gives a web address for it, else the app's HD card art on the
/// device; a web picture that fails falls back to the card art. Decoded at its drawn size, it covers the 790x444 box at
/// x 236, y -30 (docs/devbertini/DESIGN-VITRINE.md, "Hero art": it bleeds off the top and the right edge) under the
/// three fades, and a new art is loaded before it cross-fades in once (300 ms), while a new theme or Modo noite swaps
/// the picture at once. Without a [program], or with no art, only the field shows, painted live: on the
/// dark field that is nothing at all, since the launcher's surface is black under everything. Fills the screen and
/// takes no input.
class VitrineBackdrop extends StatelessWidget {
  final WatchNextProgram? program;

  /// Modo noite: the art a little darker.
  final bool night;

  const VitrineBackdrop({super.key, required this.program, this.night = false});

  @override
  Widget build(BuildContext context) {
    final p = program;
    final banner = p == null
        ? null
        : context.select<AppsService?, Uint8List?>((apps) => apps?.cachedBanner(p.packageName));
    final scale = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2;
    final width = (_artWidth * scale).round();
    final hasBanner = banner != null && banner.isNotEmpty;
    final ImageProvider? fallback = hasBanner ? ResizeImage(MemoryImage(banner), width: width) : null;
    final String? key;
    final ImageProvider? image;
    if (p != null && _isWeb(p.posterArtUri)) {
      key = p.posterArtUri;
      image = ResizeImage(NetworkImage(p.posterArtUri), width: width);
    } else if (p != null && fallback != null) {
      key = 'banner:${p.packageName}';
      image = fallback;
    } else {
      key = null;
      image = null;
    }
    return IgnorePointer(
      child: RepaintBoundary(
        child: _Backdrop(artKey: key, image: image, fallback: fallback, night: night),
      ),
    );
  }
}

class _Backdrop extends StatefulWidget {
  final String? artKey;
  final ImageProvider? image;
  final ImageProvider? fallback;
  final bool night;

  const _Backdrop({required this.artKey, required this.image, required this.fallback, required this.night});

  @override
  State<_Backdrop> createState() => _BackdropState();
}

class _BackdropState extends State<_Backdrop> {
  /// The decoded art (this state's own handle) and how many arts have come in, which keys the cross-fade.
  ui.Image? _art;
  int _arts = 0;

  /// The art being read: its key, its stream and the listener on it.
  String? _loadingKey;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  /// The last picture of the screen and what it was painted from; the picture's widget owns and disposes it.
  ui.Image? _baked;
  Object? _bakedFrom;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadingKey == null && _art == null) _load();
  }

  @override
  void didUpdateWidget(_Backdrop old) {
    super.didUpdateWidget(old);
    if (widget.artKey != old.artKey) _load();
  }

  @override
  void dispose() {
    _stopListening();
    _art?.dispose();
    super.dispose();
  }

  /// Reads the art of [widget], or clears it when there is none.
  void _load() {
    final image = widget.image;
    if (image == null) {
      _stopListening();
      _loadingKey = null;
      if (_art != null) _setArt(null);
      return;
    }
    _listen(image, widget.artKey!);
  }

  void _listen(ImageProvider provider, String key) {
    _stopListening();
    _loadingKey = key;
    final stream = provider.resolve(createLocalImageConfiguration(context));
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!mounted || _loadingKey != key) {
          info.dispose();
          return;
        }
        setState(() => _setArt(info.image));
        _stopListening();
      },
      onError: (_, _) {
        if (!mounted || _loadingKey != key) return;
        final fallback = widget.fallback;
        if (fallback != null && provider != fallback) {
          _listen(fallback, key);
        } else {
          _stopListening();
          // No art after all: the field alone, as for a program without one.
          if (_art != null) setState(() => _setArt(null));
        }
      },
    );
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  /// A new art (or none): the next build paints a new picture of the screen, cross-faded in.
  void _setArt(ui.Image? art) {
    _art?.dispose();
    _art = art;
    _arts++;
    _baked = null;
    _bakedFrom = null;
  }

  void _stopListening() {
    final stream = _stream, listener = _listener;
    _stream = null;
    _listener = null;
    if (stream != null && listener != null) stream.removeListener(listener);
  }

  /// The picture of the whole screen: the field, the art in its box under the three fades and the night's darkening.
  ui.Image _bake(ui.Image art, VitrineTokens t, bool night, Size size, double scale) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(scale);
    paintVitrineField(canvas, t, size);
    const box = Rect.fromLTWH(_artLeft, _artTop, _artWidth, _artHeight);
    paintImage(canvas: canvas, rect: box, image: art, fit: BoxFit.cover, filterQuality: FilterQuality.medium);
    _HeroFadePainter(t.heroFadeDown, t.heroFadeSide, t.isDark).paint(canvas, const Size(_fadeWidth, _fadeHeight));
    if (night) canvas.drawRect(box, Paint()..color = Colors.black.withValues(alpha: NightMode.dim));
    final picture = recorder.endRecording();
    final image = picture.toImageSync((size.width * scale).round(), (size.height * scale).round());
    picture.dispose();
    return image;
  }

  @override
  Widget build(BuildContext context) {
    final t = VitrineTheme.of(context);
    final art = _art;
    final Widget shown;
    if (art == null) {
      shown = t.isDark
          ? const SizedBox.expand(key: ValueKey('field'))
          : const VitrineField(key: ValueKey('field'));
    } else {
      final size = MediaQuery.sizeOf(context);
      final scale = MediaQuery.devicePixelRatioOf(context);
      final from = (art, t, widget.night, size, scale);
      if (_baked == null || _bakedFrom != from) {
        _baked = _bake(art, t, widget.night, size, scale);
        _bakedFrom = from;
      }
      shown = _BakedPicture(key: ValueKey(_arts), image: _baked!);
    }
    return AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: shown);
  }
}

/// Draws [image] over the whole screen and disposes it when it leaves (after its cross-fade) or is replaced.
class _BakedPicture extends StatefulWidget {
  final ui.Image image;

  const _BakedPicture({super.key, required this.image});

  @override
  State<_BakedPicture> createState() => _BakedPictureState();
}

class _BakedPictureState extends State<_BakedPicture> {
  @override
  void didUpdateWidget(_BakedPicture old) {
    super.didUpdateWidget(old);
    if (old.image != widget.image) old.image.dispose();
  }

  @override
  void dispose() {
    widget.image.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SizedBox.expand(child: RawImage(image: widget.image, fit: BoxFit.fill, filterQuality: FilterQuality.low));
}

/// The hero's text block at the top left of the home (docs/devbertini/DESIGN-VITRINE.md, "Hero"): 300 wide, as tall as
/// its lines need (149 px with a two line synopsis). The session places it at x 100, y 50.
///
/// The provider's logo, the title (one line, up to 400 px before an ellipsis, where the art is still mostly faded
/// behind it), the 72x3 bar with "NN min restantes"
/// (minutes rounded up; both left out when the program has no duration), the synopsis (two lines at most) and two
/// capsules: "Continuar" resumes the program, "Detalhes" opens its panel. [resumeFocusNode] is the "Continuar"
/// capsule's focus node, for the home to put the focus there.
class VitrineHeroInfo extends StatelessWidget {
  final WatchNextProgram program;
  final FocusNode? resumeFocusNode;

  const VitrineHeroInfo({super.key, required this.program, this.resumeFocusNode});

  /// The synopsis to show: the program's description, or null when it is blank or only repeats the title (Twitch's
  /// streams give their title as the description).
  static String? synopsisOf(WatchNextProgram program) {
    final description = program.description.trim();
    if (description.isEmpty || description.toLowerCase() == program.title.trim().toLowerCase()) return null;
    return description;
  }

  /// Whole minutes left, rounded up, or null when the program has no duration.
  static int? minutesLeft(WatchNextProgram program) {
    if (program.duration <= 0) return null;
    final left = program.duration - program.playbackPosition;
    return left <= 0 ? 0 : (left / Duration.millisecondsPerMinute).ceil();
  }

  void _resume(BuildContext context) {
    devBertiniStartLaunch();
    context.read<WatchNextService>().launch(program);
  }

  void _details(BuildContext context) {
    final apps = context.read<AppsService>();
    showDialog<void>(
      context: context,
      builder: (_) => WatchNextInfoPanel(
        program: program,
        watchNextService: context.read<WatchNextService>(),
        appsService: apps,
        appIconBytes: apps.cachedIcon(program.packageName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = VitrineTheme.of(context);
    final pt = Localizations.maybeLocaleOf(context)?.languageCode == 'pt';
    final minutes = minutesLeft(program);
    final synopsis = synopsisOf(program);
    final appName = context.select<AppsService?, String?>((apps) => apps?.getApp(program.packageName)?.name);
    final ink2 = vitrineText(12, color: t.ink2, line: 16);
    return RepaintBoundary(
      child: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 19,
              child: Align(
                alignment: Alignment.centerLeft,
                child: VitrineLogo(
                  package: program.packageName,
                  height: 19,
                  fallback: appName == null || appName.isEmpty
                      ? null
                      : Text(appName, style: vitrineText(15, weight: 600, color: t.ink2, line: 19)),
                ),
              ),
            ),
            const SizedBox(height: 5),
            SizedBox(
              height: 32,
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                minWidth: 0,
                maxWidth: 400,
                child: Text(
                  program.title,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: vitrineText(28, color: t.ink, line: 32, tracking: -0.6),
                ),
              ),
            ),
            if (minutes != null) ...[
              const SizedBox(height: 5),
              Row(
                children: [
                  _Bar(fraction: (program.playbackPosition / program.duration).clamp(0.0, 1.0)),
                  const SizedBox(width: 8),
                  Text(
                    pt ? '$minutes min restantes' : '$minutes min left',
                    style: vitrineText(12, weight: 500, color: t.ink2, line: 15),
                  ),
                ],
              ),
            ],
            if (synopsis != null) ...[
              const SizedBox(height: 5),
              SizedBox(
                width: 285,
                child: Text(synopsis, maxLines: 2, overflow: TextOverflow.ellipsis, style: ink2),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                _Capsule(
                  primary: true,
                  icon: Icons.play_arrow_outlined,
                  label: pt ? 'Continuar' : 'Continue',
                  semanticLabel: pt ? 'Continuar ${program.title}' : 'Continue ${program.title}',
                  focusNode: resumeFocusNode,
                  onPressed: () => _resume(context),
                ),
                const SizedBox(width: 7),
                _Capsule(
                  primary: false,
                  icon: Icons.info_outline,
                  label: pt ? 'Detalhes' : 'Details',
                  semanticLabel: pt ? 'Detalhes de ${program.title}' : 'Details of ${program.title}',
                  onPressed: () => _details(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The 72x3 progress bar: [fraction] of it filled with ink on the track colour.
class _Bar extends StatelessWidget {
  final double fraction;

  const _Bar({required this.fraction});

  @override
  Widget build(BuildContext context) {
    final t = VitrineTheme.of(context);
    return SizedBox(
      key: const ValueKey('vitrine-hero-bar'),
      width: 72,
      height: 3,
      child: DecoratedBox(
        decoration: BoxDecoration(color: t.track, borderRadius: BorderRadius.circular(2)),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: fraction,
            heightFactor: 1,
            child: DecoratedBox(decoration: BoxDecoration(color: t.ink, borderRadius: BorderRadius.circular(2))),
          ),
        ),
      ),
    );
  }
}

/// A capsule of the hero: 26 tall, radius 13, a 16 px icon and a 12 px w600 label. It keeps its own focus state, so a
/// focus change repaints only this capsule. OK (any validation key) or a click does [onPressed].
class _Capsule extends StatefulWidget {
  final bool primary;
  final IconData icon;
  final String label;
  final String semanticLabel;
  final FocusNode? focusNode;
  final VoidCallback onPressed;

  const _Capsule({
    required this.primary,
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.onPressed,
    this.focusNode,
  });

  @override
  State<_Capsule> createState() => _CapsuleState();
}

class _CapsuleState extends State<_Capsule> {
  bool _focused = false;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!AppCardKeys.validationKeys.contains(event.logicalKey)) return KeyEventResult.ignored;
    // Once per press: a key held down repeats, and the panel it opens would open again.
    if (event is KeyDownEvent) widget.onPressed();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final t = VitrineTheme.of(context);
    final fill = widget.primary ? t.primary : t.quiet;
    final ink = widget.primary ? t.primaryInk : t.ink;
    final edge = widget.primary ? t.primaryEdge : t.quietEdge;
    const shape = BorderRadius.all(Radius.circular(13));
    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: _onKey,
      onFocusChange: (focused) {
        if (focused != _focused) setState(() => _focused = focused);
      },
      child: HoverFocus(
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Semantics(
            button: true,
            label: widget.semanticLabel,
            excludeSemantics: true,
            child: VitrineFocusFrame(
              focused: _focused,
              radius: 13,
              scale: 1.05,
              child: DecoratedBox(
                decoration: BoxDecoration(color: fill, borderRadius: shape),
                // The 1 px edge is painted inside the capsule, so it never changes the capsule's size.
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    borderRadius: shape,
                    border: edge == null ? null : Border.all(color: edge, strokeAlign: BorderSide.strokeAlignInside),
                  ),
                  child: SizedBox(
                    height: 26,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 9, right: 13),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(widget.icon, size: 16, color: ink),
                          const SizedBox(width: 4),
                          Text(widget.label, style: vitrineText(12, weight: 600, color: ink)),
                        ],
                      ),
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
