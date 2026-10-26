/*
 * DevBertini theme for LTvLauncher (GPL-3.0, like the rest of this project).
 * Copyright (C) 2026 Claudio Bertini (devBertini)
 */

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Whether this build logs its frames: `--dart-define=DEVBERTINI_FRAME_LOG=true`, never in the builds that go to the
/// TVs as their home.
const bool devBertiniFrameLog = bool.fromEnvironment('DEVBERTINI_FRAME_LOG');

/// One logcat line per frame with the time the UI thread (build, layout, paint) and the raster thread took, from
/// Flutter's own FrameTiming, which profile and release builds report without a VM service
/// (`tools/devbertini/frame_log.py` drives the home and reads them).
void startDevBertiniFrameLog() {
  if (!devBertiniFrameLog) return;
  SchedulerBinding.instance.addTimingsCallback((timings) {
    for (final timing in timings) {
      debugPrint('DevBertiniFrame build=${timing.buildDuration.inMicroseconds} '
          'raster=${timing.rasterDuration.inMicroseconds} total=${timing.totalSpan.inMicroseconds}');
    }
  });
}
