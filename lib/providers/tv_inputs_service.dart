import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flauncher/flauncher_channel.dart';
import 'package:flauncher/models/tv_input.dart';

class TvInputsService extends ChangeNotifier with WidgetsBindingObserver {
  final FLauncherChannel _channel;
  List<TvInput> _inputs = [];
  bool _initialized = false;

  TvInputsService(this._channel) {
    WidgetsBinding.instance.addObserver(this);
    _init();
    _startWatch();
  }

  List<TvInput> get inputs => List.unmodifiable(_inputs);
  bool get hasInputs => _inputs.isNotEmpty;
  bool get initialized => _initialized;

  /// The devices plugged in over HDMI that name themselves (a console), for their home cards.
  List<TvInput> get devices => _inputs.where((input) => input.device && input.label.isNotEmpty).toList();

  Future<void> _init() async {
    await refreshInputs();
    _initialized = true;
    notifyListeners();
  }

  /// A console plugged in or taken out while another app ran shows up when the home comes back.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refreshInputs();
      _startWatch();
    } else {
      _watch?.cancel();
      _watch = null;
    }
  }

  /// A console turned on or off while the home shows: its card's light follows within half a minute.
  Timer? _watch;

  void _startWatch() {
    _watch ??= Timer.periodic(const Duration(seconds: 30), (_) => refreshInputs());
  }

  Future<void> refreshInputs() async {
    final List<Map<dynamic, dynamic>> rawInputs = await _channel.getTvInputs();
    final inputs = rawInputs.map((map) => TvInput.fromMap(map)).toList();
    final same = inputs.length == _inputs.length &&
        Iterable.generate(inputs.length).every((i) =>
            inputs[i].id == _inputs[i].id &&
            inputs[i].label == _inputs[i].label &&
            inputs[i].device == _inputs[i].device &&
            inputs[i].on == _inputs[i].on);
    _inputs = inputs;
    if (!same || !_initialized) notifyListeners();
  }

  Future<bool> switchInput(String id) async {
    return await _channel.launchTvInput(id);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _watch?.cancel();
    super.dispose();
  }
}
