/*
 * DevBertini theme for LTvLauncher (GPL-3.0, like the rest of this project).
 * Copyright (C) 2026 Claudio Bertini (devBertini)
 *
 * The studio intro, ported from the canonical iOS view (DevBertiniIntro.swift): the tile grows in
 * (0.15 to 0.6 s), the stem and the bowls draw (0.3 to 0.95 s), the name rises (0.75 to 1.15 s) and
 * the end frame is held until 2 s. With animations turned off on the TV nothing scales, draws or
 * slides: the marks fade in over the same times.
 */

import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flauncher/devbertini/brand.dart';
import 'package:flutter/material.dart';

/// Eases a moment [t] (seconds) through the interval a...b into 0...1, ease-out cubic.
double _ramp(double t, double a, double b) {
  final x = ((t - a) / (b - a)).clamp(0.0, 1.0);
  return 1 - math.pow(1 - x, 3).toDouble();
}

/// One moment [t] of the studio intro, full screen.
class DevBertiniIntro extends StatelessWidget {
  static const double duration = 2.0;

  final double t;
  final bool reduceMotion;

  const DevBertiniIntro({super.key, required this.t, this.reduceMotion = false});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: DevBertiniColors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The drawing is made for a 440 short side, like the iOS original.
          final k = (math.min(constraints.maxWidth, constraints.maxHeight) / 440).clamp(0.7, 1.6);
          return Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(dimension: 156 * k, child: DevBertiniMark(t: t, reduceMotion: reduceMotion)),
                SizedBox(width: 40 * k),
                DevBertiniWordmark(t: t, size: 88 * k, reduceMotion: reduceMotion),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The dB monogram on its graphite tile; still unless a moment [t] of the intro is given.
class DevBertiniMark extends StatelessWidget {
  final double t;
  final bool reduceMotion;

  const DevBertiniMark({super.key, this.t = DevBertiniIntro.duration, this.reduceMotion = true});

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _MarkPainter(t, reduceMotion));
}

class _MarkPainter extends CustomPainter {
  static const double _dx = 0.0175; // centres the group's ink, which runs from 0.15 to 0.815 of the square

  final double t;
  final bool reduce;

  _MarkPainter(this.t, this.reduce);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final tile = _ramp(t, 0.15, 0.6);
    final stem = reduce ? 1.0 : _ramp(t, 0.3, 0.6);
    final bowls = reduce ? 1.0 : _ramp(t, 0.45, 0.95);
    if (tile <= 0) return;

    // An offscreen layer only while the tile fades in (about a dozen frames): it is the costly part
    // of a frame on the TV's GPU, and once the tile is opaque the marks need no group alpha.
    final fading = tile < 1;
    if (fading) {
      canvas.saveLayer(Offset.zero & size, Paint()..color = Color.fromRGBO(0, 0, 0, tile));
    } else {
      canvas.save();
    }
    final scale = reduce ? 1.0 : 0.86 + 0.14 * tile;
    canvas.translate(s / 2, s / 2);
    canvas.scale(scale);
    canvas.translate(-s / 2, -s / 2);

    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(s * 0.225)),
      Paint()..color = DevBertiniColors.tile,
    );
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final paths = _MarkPaths.of(s);
    canvas.drawPath(paths.dBowl.trimmed(bowls), stroke..color = DevBertiniColors.bowl);
    canvas.drawPath(paths.bBowls.trimmed(bowls), stroke..color = DevBertiniColors.stem);
    canvas.drawPath(paths.stem.trimmed(stem), stroke..color = DevBertiniColors.stem);
    canvas.restore();
  }

  static Offset _p(double s, double x, double y) => Offset((x + _dx) * s, y * s);

  /// The stem the d and the B share.
  static Path _stem(double s) {
    final a = _p(s, 0.5, 0.22), b = _p(s, 0.5, 0.78);
    return Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy);
  }

  /// The d's bowl, left of the stem.
  static Path _dBowl(double s) => Path()
    ..addArc(Rect.fromCircle(center: _p(s, 0.35, 0.63), radius: 0.15 * s), 0, 2 * math.pi * 359.9 / 360);

  /// The B's two bowls, right of the stem, as one stroke.
  static Path _bBowls(double s) {
    final path = Path();
    final start = _p(s, 0.5, 0.22), top = _p(s, 0.6, 0.22), waist = _p(s, 0.5, 0.49), lower = _p(s, 0.62, 0.49),
        end = _p(s, 0.5, 0.78);
    path.moveTo(start.dx, start.dy);
    path.lineTo(top.dx, top.dy);
    path.arcTo(Rect.fromCircle(center: _p(s, 0.6, 0.355), radius: 0.135 * s), -math.pi / 2, math.pi, false);
    path.lineTo(waist.dx, waist.dy);
    path.lineTo(lower.dx, lower.dy);
    path.arcTo(Rect.fromCircle(center: _p(s, 0.62, 0.635), radius: 0.145 * s), -math.pi / 2, math.pi, false);
    path.lineTo(end.dx, end.dy);
    return path;
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.t != t || old.reduce != reduce;
}

/// A stroke of the mark with its length measured once, so each intro frame only cuts it.
class _MeasuredPath {
  final Path path;
  final List<PathMetric> metrics;
  final double length;

  _MeasuredPath(this.path)
      : metrics = path.computeMetrics().toList(),
        length = path.computeMetrics().fold<double>(0, (sum, m) => sum + m.length);

  /// The first [fraction] of the stroke, like SwiftUI's trim(from: 0, to:).
  Path trimmed(double fraction) {
    if (fraction >= 1) return path;
    final out = Path();
    if (fraction <= 0) return out;
    var remaining = length * fraction;
    for (final m in metrics) {
      if (remaining <= 0) break;
      final part = math.min(m.length, remaining);
      out.addPath(m.extractPath(0, part), Offset.zero);
      remaining -= part;
    }
    return out;
  }
}

/// The mark's three strokes for one tile size, built and measured once per size.
class _MarkPaths {
  final _MeasuredPath stem, dBowl, bBowls;

  _MarkPaths(double s)
      : stem = _MeasuredPath(_MarkPainter._stem(s)),
        dBowl = _MeasuredPath(_MarkPainter._dBowl(s)),
        bBowls = _MeasuredPath(_MarkPainter._bBowls(s));

  static final Map<double, _MarkPaths> _bySize = {};

  static _MarkPaths of(double s) => _bySize.putIfAbsent(s, () => _MarkPaths(s));
}

/// "dev" in soft grey, "Bertini" in cream; rises in during the intro.
class DevBertiniWordmark extends StatelessWidget {
  final double t;
  final double size;
  final bool reduceMotion;

  const DevBertiniWordmark({super.key, this.t = DevBertiniIntro.duration, required this.size, this.reduceMotion = true});

  @override
  Widget build(BuildContext context) {
    final k = _ramp(t, 0.75, 1.15);
    // Its own text style: the intro sits outside any Material, where Flutter's
    // fallback style would draw the name in a monospace font with a yellow underline.
    // The fade is in the text colours, not an Opacity layer, so each frame stays cheap on the TV.
    return DefaultTextStyle(
      style: const TextStyle(decoration: TextDecoration.none),
      child: Transform.translate(
        offset: Offset(0, reduceMotion ? 0 : (1 - k) * size * 0.12),
        child: Text.rich(
          TextSpan(children: [
            TextSpan(text: 'dev', style: TextStyle(color: DevBertiniColors.inkSoft.withValues(alpha: k))),
            TextSpan(text: 'Bertini', style: TextStyle(color: DevBertiniColors.ink.withValues(alpha: k))),
          ]),
          textScaler: TextScaler.noScaling,
          style: TextStyle(fontSize: size, fontWeight: FontWeight.w700, letterSpacing: -size * 0.01, height: 1.0),
        ),
      ),
    );
  }
}
