/*
 * DevBertini theme for LTvLauncher (GPL-3.0, like the rest of this project).
 */

import 'dart:async';
import 'dart:typed_data';

import 'package:flauncher/flauncher_channel.dart';
import 'package:flutter/widgets.dart';

/// Music or video another app plays in the background, for the line beside the clock.
class NowPlaying {
  final String packageName;
  final String title;
  final String artist;
  final bool playing;

  const NowPlaying(this.packageName, this.title, this.artist, this.playing);

  @override
  bool operator ==(Object other) =>
      other is NowPlaying &&
      other.packageName == packageName &&
      other.title == title &&
      other.artist == artist &&
      other.playing == playing;

  @override
  int get hashCode => Object.hash(packageName, title, artist, playing);
}

/// Asks Android what plays every few seconds, and only while the home is on screen: nothing runs
/// while another app is in front.
class NowPlayingService extends ChangeNotifier with WidgetsBindingObserver {
  final FLauncherChannel _channel;
  Timer? _timer;
  NowPlaying? _current;
  bool _disposed = false;

  NowPlayingService(this._channel) {
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  NowPlaying? get current => _current;

  void _start() {
    _refresh();
    _timer ??= Timer.periodic(const Duration(seconds: 4), (_) => _refresh());
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    state == AppLifecycleState.resumed ? _start() : _stop();
  }

  int _positionMs = 0;
  int _durationMs = 0;
  final Stopwatch _sinceRead = Stopwatch();

  /// How far the track is, from 0 to 1, moving on between reads while it plays; null when the app
  /// reports no duration.
  double? get progress {
    final current = _current;
    if (current == null || _durationMs <= 0) return null;
    final at = _positionMs + (current.playing ? _sinceRead.elapsedMilliseconds : 0);
    return (at / _durationMs).clamp(0.0, 1.0);
  }

  /// What is left of the track, or null with no duration.
  Duration? get remaining {
    final p = progress;
    return p == null ? null : Duration(milliseconds: ((1 - p) * _durationMs).round());
  }

  Future<void> _refresh() async {
    final map = await _channel.getNowPlaying();
    if (_disposed) return;
    _positionMs = (map?['position'] as num?)?.toInt() ?? 0;
    _durationMs = (map?['duration'] as num?)?.toInt() ?? 0;
    _sinceRead
      ..reset()
      ..start();
    final next = map == null
        ? null
        : NowPlaying(
            map['package'] as String? ?? '',
            map['title'] as String? ?? '',
            map['artist'] as String? ?? '',
            map['playing'] as bool? ?? false,
          );
    if (next != _current) {
      final newTrack = next == null ||
          _current == null ||
          next.packageName != _current!.packageName ||
          next.title != _current!.title;
      _current = next;
      if (newTrack) {
        _art = null;
        if (next != null) _readArt(next);
      }
      notifyListeners();
    }
  }

  Uint8List? _art;

  /// The cover of the track playing, read once per track; null until read or when there is none.
  Uint8List? get art => _art;

  Future<void> _readArt(NowPlaying track) async {
    final bytes = await _channel.getNowPlayingArt(track.packageName);
    if (_disposed || _current?.title != track.title) return;
    _art = bytes;
    notifyListeners();
  }

  Future<void> skip({required bool next}) async {
    final current = _current;
    if (current == null) return;
    await _channel.mediaSkip(current.packageName, next: next);
    await Future.delayed(const Duration(milliseconds: 500));
    await _refresh();
  }

  /// Opens the app that plays.
  Future<void> openApp() async {
    final current = _current;
    if (current == null) return;
    await _channel.launchApp(current.packageName);
  }

  /// Pauses or resumes what plays, then reads the new state back.
  Future<void> playPause() async {
    final current = _current;
    if (current == null) return;
    await _channel.mediaPlayPause(current.packageName);
    await Future.delayed(const Duration(milliseconds: 300));
    await _refresh();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    super.dispose();
  }
}
