/*
 * DevBertini theme for LTvLauncher (GPL-3.0, like the rest of this project).
 * Copyright (C) 2026 Claudio Bertini (devBertini)
 *
 * The profile model and what the profiles panel needs, free of platform code.
 */

import 'package:flutter/material.dart';

/// The first profile, made from the launcher as it was before profiles existed.
const String mainProfileId = 'main';

/// Settings every profile shares: read by Android code before any profile is known, or global.
const Set<String> globalSettingsKeys = {
  'start_on_boot',
  'devbertini_intro_build_seen',
  'devbertini_intro_boot_seen',
  // Read by the Android notification listener, which knows no profile.
  'system_notifications_popup',
  'devbertini_tv_maker_apps_hidden',
  'devbertini_tv_maker_apps_hidden_v2',
  'devbertini_tv_maker_apps_hidden_v3',
  'devbertini_weather',
  'devbertini_weather_last',
  'devbertini_night_mode',
};

/// Avatar colours, in the order new profiles take them. The first (the main profile's) is the Vitrine's neutral
/// graphite, never a purple.
const List<Color> profileColors = [
  Color(0xFF4A525E),
  Color(0xFF10B981),
  Color(0xFFF59E0B),
  Color(0xFFF43F5E),
  Color(0xFF0EA5E9),
  Color(0xFFD946EF),
  Color(0xFF84CC16),
  Color(0xFFF97316),
];

class LauncherProfile {
  final String id;
  String name;
  int color;

  LauncherProfile({required this.id, required this.name, required this.color});

  Color get colour => profileColors[color % profileColors.length];

  String get initial => name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();

  Map<String, Object> toJson() => {'id': id, 'name': name, 'color': color};

  factory LauncherProfile.fromJson(Map<String, dynamic> json) =>
      LauncherProfile(id: json['id'] as String, name: json['name'] as String, color: (json['color'] as num).toInt());
}

/// What the profiles panel needs; the launcher's ProfileService gives it.
abstract class ProfilesController extends ChangeNotifier {
  List<LauncherProfile> get profiles;
  LauncherProfile get current;
  Future<LauncherProfile> create(String name);
  Future<void> rename(LauncherProfile profile, String name);
  Future<void> nextColour(LauncherProfile profile);
  Future<void> delete(LauncherProfile profile);
  Future<void> switchTo(LauncherProfile profile);
}
