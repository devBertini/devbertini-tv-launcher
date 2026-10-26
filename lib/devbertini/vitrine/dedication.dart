/*
 * DevBertini theme for LTvLauncher (GPL-3.0, like the rest of this project).
 */

import 'package:flauncher/devbertini/vitrine/tokens.dart';
import 'package:flutter/widgets.dart';

/// What follows the studio's name in the signature, in this build.
class VitrineDedication {
  /// Whether a dedication may show; the README's pictures turn it off (test/devbertini/vitrine_capture_test.dart).
  static bool shown = true;

  /// Nothing: the signature is the studio's mark and name only.
  static Widget? of(VitrineTokens t) => null;
}
