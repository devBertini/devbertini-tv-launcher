/*
 * DevBertini theme for LTvLauncher (GPL-3.0, like the rest of this project).
 */

import 'dart:ui' as ui;

import 'package:flauncher/devbertini/vitrine/tokens.dart';
import 'package:flutter/material.dart';

/// Paints the field of [t] over [size] on [canvas]: black on the dark field, the light field's gradient on the light
/// one.
void paintVitrineField(Canvas canvas, VitrineTokens t, Size size) {
  final painter = t.fieldDecoration.createBoxPainter();
  painter.paint(canvas, Offset.zero, ImageConfiguration(size: size));
  painter.dispose();
}

/// The Vitrine field under a whole page (it fills the screen): the dark field's black as a plain fill, the light
/// field's three-colour gradient painted once into a picture of the screen and drawn as that one image. A gradient
/// over the whole screen painted every frame costs the TCL's Mali-G52 several ms of GPU per frame
/// (docs/devbertini/DESIGN-VITRINE.md, "Performance"). [child] is drawn over it.
class VitrineField extends StatefulWidget {
  final Widget? child;

  const VitrineField({super.key, this.child});

  /// The field of [t] painted over [size] at [scale] device pixels per logical pixel, into one image the caller owns.
  static ui.Image paint(VitrineTokens t, Size size, double scale) {
    final recorder = ui.PictureRecorder();
    paintVitrineField(Canvas(recorder)..scale(scale), t, size);
    final picture = recorder.endRecording();
    final image = picture.toImageSync((size.width * scale).round(), (size.height * scale).round());
    picture.dispose();
    return image;
  }

  @override
  State<VitrineField> createState() => _VitrineFieldState();
}

class _VitrineFieldState extends State<VitrineField> {
  ui.Image? _image;
  Object? _paintedFrom;

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = VitrineTheme.of(context);
    if (t.isDark) return ColoredBox(color: t.field, child: SizedBox.expand(child: widget.child));
    final size = MediaQuery.sizeOf(context);
    final scale = MediaQuery.devicePixelRatioOf(context);
    final from = (t, size, scale);
    if (_image == null || _paintedFrom != from) {
      // The frame already sent keeps its own reference to the old picture, so it can go now.
      _image?.dispose();
      _image = VitrineField.paint(t, size, scale);
      _paintedFrom = from;
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        RawImage(image: _image, fit: BoxFit.fill, filterQuality: FilterQuality.low),
        if (widget.child != null) widget.child!,
      ],
    );
  }
}
