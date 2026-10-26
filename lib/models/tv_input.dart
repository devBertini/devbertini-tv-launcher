enum TvInputType {
  tuner,
  hdmi,
  av,
  other
}

class TvInput {
  final String id;
  final String label;
  final TvInputType type;

  /// A device found over HDMI-CEC (a console, a player), named by itself, not an HDMI port.
  final bool device;

  /// The device is on: not in standby, not unplugged, and not resting (the TCL reports a resting console
  /// as on, so the launcher's own reading of "no signal" on its input counts too).
  final bool on;

  TvInput({
    required this.id,
    required this.label,
    required this.type,
    this.device = false,
    this.on = false,
  });

  factory TvInput.fromMap(Map<dynamic, dynamic> map) {
    final int typeInt = map['type'] as int? ?? 1000;
    TvInputType type;
    if (typeInt == 1007) {
      type = TvInputType.hdmi;
    } else if (typeInt == 0 || typeInt == 2 || typeInt == 3) {
      type = TvInputType.tuner;
    } else if (typeInt >= 1001 && typeInt <= 1004) {
      type = TvInputType.av;
    } else {
      type = TvInputType.other;
    }

    return TvInput(
      id: map['id'] as String? ?? '',
      label: map['label'] as String? ?? '',
      type: type,
      device: map['device'] as bool? ?? false,
      on: (map['state'] as int? ?? 2) == 0 && map['resting'] != true,
    );
  }
}
