/*
 * DevBertini theme for LTvLauncher (GPL-3.0, like the rest of this project).
 */

import 'dart:io';
import 'dart:typed_data';

import 'package:flauncher/devbertini/vitrine/tokens.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

/// The brands' logos the PC puts on the device (`tools/devbertini/logo_art.py`, `deploy.ps1 -Art`), as
/// `logo_black_<package>.png` (drawn on black: a white or bright mark) and `logo_light_<package>.png` (drawn on the
/// light field and on white plates) in the launcher's external files folder, beside the HD card art. They are the
/// brands' marks, so they never enter the repository. Rasterised at twice the largest height the home draws them, so
/// they stay sharp on the 1080p screen.
class VitrineLogos extends ChangeNotifier {
  static const prefix = 'logo_';

  final Future<Directory?> Function() _directory;
  final Map<String, Uint8List> _black = {};
  final Map<String, Uint8List> _light = {};
  bool _loaded = false;

  VitrineLogos({Future<Directory?> Function()? directory}) : _directory = directory ?? _externalFiles;

  static Future<Directory?> _externalFiles() async {
    try {
      return await getExternalStorageDirectory();
    } catch (_) {
      return null; // No external storage (tests): every logo falls back.
    }
  }

  /// Whether the folder was read (with or without logos in it).
  bool get loaded => _loaded;

  /// Reads every logo on the device once; listeners hear when they are in.
  Future<void> load() async {
    final dir = await _directory();
    if (dir != null) {
      try {
        await for (final entry in dir.list()) {
          final name = entry.uri.pathSegments.last;
          if (entry is! File || !name.startsWith(prefix) || !name.endsWith('.png')) continue;
          final rest = name.substring(prefix.length, name.length - 4);
          final split = rest.indexOf('_');
          if (split < 0) continue;
          final variant = rest.substring(0, split), package = rest.substring(split + 1);
          final bytes = await entry.readAsBytes();
          if (bytes.isEmpty) continue;
          if (variant == 'black') _black[package] = bytes;
          if (variant == 'light') _light[package] = bytes;
        }
      } catch (_) {
        // A folder that cannot be read leaves the logos out; the cards fall back.
      }
    }
    _loaded = true;
    notifyListeners();
  }

  /// [package]'s logo for a black ([onBlack]) or a light surface; a brand with one variant only (its mark reads on
  /// both, like Netflix's red) gives that one. Null when the PC put none.
  Uint8List? bytes(String package, {required bool onBlack}) =>
      onBlack ? (_black[package] ?? _light[package]) : (_light[package] ?? _black[package]);
}

/// A brand's logo [height] logical px tall, for the surface the Vitrine tokens say ([onBlack] overrides it: the
/// continue cards draw on their own dark scrim in both themes). Decoded at its drawn size. Without a
/// [VitrineLogos] above or a logo for [package], shows [fallback] (nothing by default).
class VitrineLogo extends StatelessWidget {
  final String package;
  final double height;
  final bool? onBlack;
  final Widget? fallback;

  const VitrineLogo({super.key, required this.package, required this.height, this.onBlack, this.fallback});

  @override
  Widget build(BuildContext context) {
    final black = onBlack ?? VitrineTheme.of(context).isDark;
    final bytes = context.select<VitrineLogos?, Uint8List?>((logos) => logos?.bytes(package, onBlack: black));
    if (bytes == null) return fallback ?? const SizedBox.shrink();
    final scale = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2;
    return Image.memory(
      bytes,
      height: height,
      cacheHeight: (height * scale).round(),
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      excludeFromSemantics: true,
    );
  }
}
