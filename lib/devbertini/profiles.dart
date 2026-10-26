/*
 * DevBertini theme for LTvLauncher (GPL-3.0, like the rest of this project).
 *
 * Profiles: each one has its own app order, hidden apps and categories (its own database file) and
 * its own launcher settings (its own prefix in the shared preferences). The list and the profile in
 * use live in a small file read before the launcher starts; switching restarts the launcher, which
 * Android brings straight back as the home app, so every service starts clean on the new profile.
 */

import 'dart:convert';
import 'dart:io';

import 'package:flauncher/database.dart';
import 'package:flauncher/devbertini/profile_model.dart';
import 'package:flutter/foundation.dart';

export 'package:flauncher/devbertini/profile_model.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The profiles file: which profiles exist and which one is in use.
class ProfileStore {
  final File _file;
  final List<LauncherProfile> profiles;
  String currentId;

  ProfileStore._(this._file, this.profiles, this.currentId);

  static Future<ProfileStore> load() async {
    final folder = await getApplicationSupportDirectory();
    final file = File(path.join(folder.path, 'profiles.json'));
    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final profiles = (json['profiles'] as List).map((p) => LauncherProfile.fromJson(p as Map<String, dynamic>)).toList();
      final current = json['current'] as String;
      if (profiles.any((p) => p.id == current)) {
        return ProfileStore._(file, profiles, current);
      }
    } catch (_) {
      // No file yet, or unreadable: start with the main profile.
    }
    return ProfileStore._(file, [LauncherProfile(id: mainProfileId, name: 'Principal', color: 0)], mainProfileId);
  }

  LauncherProfile get current => profiles.firstWhere((p) => p.id == currentId);

  static String settingsPrefixOf(String id) => id == mainProfileId ? '' : 'p_$id.';
  static String databaseFileOf(String id) => id == mainProfileId ? 'db.sqlite' : 'db_$id.sqlite';

  String get settingsPrefix => settingsPrefixOf(currentId);
  String get databaseFile => databaseFileOf(currentId);

  /// Written and flushed at once: a switch restarts the process right after.
  Future<void> save() async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(
      jsonEncode({'current': currentId, 'profiles': profiles.map((p) => p.toJson()).toList()}),
      flush: true,
    );
  }
}

/// Profiles for the UI: create, rename, recolour, delete, switch.
class ProfileService extends ProfilesController {
  final ProfileStore _store;
  final FLauncherDatabase _database;
  final SharedPreferences _preferences;

  ProfileService(this._store, this._database, this._preferences);

  @override
  List<LauncherProfile> get profiles => List.unmodifiable(_store.profiles);
  @override
  LauncherProfile get current => _store.current;

  /// A new profile starting as a copy of the one in use: same apps, order, look and settings.
  @override
  Future<LauncherProfile> create(String name) async {
    final id = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final profile = LauncherProfile(id: id, name: name.trim(), color: _store.profiles.length % profileColors.length);
    final folder = await getApplicationDocumentsDirectory();
    final target = File(path.join(folder.path, ProfileStore.databaseFileOf(id)));
    if (await target.exists()) await target.delete();
    // VACUUM INTO writes a consistent copy of the open database, write-ahead log included.
    await _database.customStatement("VACUUM INTO '${target.path.replaceAll("'", "''")}'");
    await _copySettings(fromPrefix: _store.settingsPrefix, toPrefix: ProfileStore.settingsPrefixOf(id));
    _store.profiles.add(profile);
    await _store.save();
    notifyListeners();
    return profile;
  }

  @override
  Future<void> rename(LauncherProfile profile, String name) async {
    if (name.trim().isEmpty) return;
    profile.name = name.trim();
    await _store.save();
    notifyListeners();
  }

  @override
  Future<void> nextColour(LauncherProfile profile) async {
    profile.color = (profile.color + 1) % profileColors.length;
    await _store.save();
    notifyListeners();
  }

  /// Deletes a profile other than the main one and the one in use, with its database and settings.
  @override
  Future<void> delete(LauncherProfile profile) async {
    if (profile.id == mainProfileId || profile.id == _store.currentId) return;
    final folder = await getApplicationDocumentsDirectory();
    final base = path.join(folder.path, ProfileStore.databaseFileOf(profile.id));
    for (final suffix in ['', '-wal', '-shm']) {
      final file = File('$base$suffix');
      if (await file.exists()) await file.delete();
    }
    final prefix = ProfileStore.settingsPrefixOf(profile.id);
    for (final key in _preferences.getKeys().where((k) => k.startsWith(prefix)).toList()) {
      await _preferences.remove(key);
    }
    _store.profiles.remove(profile);
    await _store.save();
    notifyListeners();
  }

  /// Makes [profile] the one in use and restarts the launcher on it.
  @override
  Future<void> switchTo(LauncherProfile profile) async {
    if (profile.id == _store.currentId) return;
    _store.currentId = profile.id;
    await _store.save();
    await _database.close();
    // Android starts the home app again as soon as its process ends.
    exit(0);
  }

  Future<void> _copySettings({required String fromPrefix, required String toPrefix}) async {
    for (final key in _preferences.getKeys().toList()) {
      final String bare;
      if (fromPrefix.isEmpty) {
        // The main profile's keys are the bare ones: skip other profiles' and the global ones.
        if (key.startsWith('p_') || globalSettingsKeys.contains(key)) continue;
        bare = key;
      } else {
        if (!key.startsWith(fromPrefix)) continue;
        bare = key.substring(fromPrefix.length);
      }
      final value = _preferences.get(key);
      final target = '$toPrefix$bare';
      if (value is String) {
        await _preferences.setString(target, value);
      } else if (value is bool) {
        await _preferences.setBool(target, value);
      } else if (value is int) {
        await _preferences.setInt(target, value);
      } else if (value is double) {
        await _preferences.setDouble(target, value);
      } else if (value is List) {
        await _preferences.setStringList(target, value.cast<String>());
      } else if (kDebugMode) {
        debugPrint('ProfileService: setting $key not copied');
      }
    }
  }
}