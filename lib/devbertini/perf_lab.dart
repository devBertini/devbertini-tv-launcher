/*
 * DevBertini theme for LTvLauncher (GPL-3.0, like the rest of this project).
 */

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Whether this build is the GPU lab: `--dart-define=DEVBERTINI_PERF_LAB=true`, only in the profile build that installs
/// beside the home as `com.leanbitlab.ltvL.profile`, never in a build that goes to the TVs as their home.
const bool devBertiniPerfLab = bool.fromEnvironment('DEVBERTINI_PERF_LAB');

/// The words of this lab run, from `perf_lab.txt` in the app's external files folder, read once at start.
Set<String> _words = const {};

/// Reads `perf_lab.txt` in a lab build (words separated by spaces or lines: the parts of the home to leave out:
/// `cards`, `semantics`, and the rail's `rail-panel`, `rail-profile`, `rail-signature`, `rail-labels`, `rail-frames`;
/// `tools/devbertini/gpu_trace.py --lab` writes them) and logs what the run uses; nothing in every other build.
Future<void> loadDevBertiniPerfLab() async {
  if (!devBertiniPerfLab) return;
  try {
    final dir = await getExternalStorageDirectory();
    final file = File('${dir?.path}/perf_lab.txt');
    if (dir != null && await file.exists()) {
      _words = (await file.readAsString()).split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toSet();
    }
  } catch (_) {
    // No file, no words: the lab draws the home as it is.
  }
  debugPrint('DevBertiniPerfLab words=${_words.join(',')}');
}

/// Whether the home draws [part]: always, except in a lab run that leaves it out.
bool perfLabShows(String part) => !devBertiniPerfLab || !_words.contains(part);
