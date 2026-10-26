/*
 * DevBertini theme for LTvLauncher (GPL-3.0, like the rest of this project).
 */

import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// The apps' banners and icons kept on disk, so a launcher that starts again (the TV frees memory
/// while another app runs, or after a reboot) shows every card's art at once instead of a
/// "Loading" placeholder while it asks Android for each image again.
class ArtDiskCache {
  /// Raised whenever the launcher starts taking the art from Android differently, so the images an
  /// older build stored are dropped and taken again (2: the densest banner the app ships).
  static const version = '2';

  Future<Directory?>? _dir;

  // One opening per cache, so two first calls never both clear the folder.
  Future<Directory?> _directory() => _dir ??= _open();

  Future<Directory?> _open() async {
    try {
      final dir = Directory('${(await getApplicationSupportDirectory()).path}/art');
      await dir.create(recursive: true);
      final stamp = File('${dir.path}/.version');
      if (!await stamp.exists() || await stamp.readAsString() != version) {
        await for (final entry in dir.list()) {
          if (entry is File) await entry.delete();
        }
        await stamp.writeAsString(version);
      }
      return dir;
    } catch (_) {
      // No storage (tests, a broken install): the launcher works as before, without the cache.
      return null;
    }
  }

  static String _name(String kind, String packageName) => '${kind}_$packageName.img';

  /// Every stored image of [kind] ('banner' or 'icon'), by package name.
  Future<Map<String, Uint8List>> loadAll(String kind) async {
    final images = <String, Uint8List>{};
    final dir = await _directory();
    if (dir == null) return images;
    try {
      await for (final entry in dir.list()) {
        final name = entry.uri.pathSegments.last;
        if (entry is! File || !name.startsWith('${kind}_') || !name.endsWith('.img')) continue;
        final bytes = await entry.readAsBytes();
        if (bytes.isNotEmpty) images[name.substring(kind.length + 1, name.length - 4)] = bytes;
      }
    } catch (_) {
      // A file that cannot be read is fetched from Android again.
    }
    return images;
  }

  Future<void> save(String kind, String packageName, Uint8List bytes) async {
    final dir = await _directory();
    if (dir == null || bytes.isEmpty) return;
    try {
      await File('${dir.path}/${_name(kind, packageName)}').writeAsBytes(bytes, flush: false);
    } catch (_) {}
  }

  /// Drops [packageName]'s stored art, when the app is updated or removed.
  Future<void> forget(String packageName) async {
    final dir = await _directory();
    if (dir == null) return;
    for (final kind in const ['banner', 'icon']) {
      try {
        final file = File('${dir.path}/${_name(kind, packageName)}');
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }
}

/// HD card art the PC puts on the device (`tools/devbertini/hd_art.py`, `deploy.ps1 -Art`), as
/// `hd_<package>.png` in the launcher's external files folder: the apps ship 320x180 banners, and this
/// art is drawn again at 960x540 from each brand's vector logo. It wins over the app's own banner.
class HdArt {
  static const prefix = 'hd_';

  Future<Directory?>? _dir;

  Future<Directory?> _directory() => _dir ??= () async {
        try {
          return await getExternalStorageDirectory();
        } catch (_) {
          return null; // No external storage (tests): the apps' own banners are used.
        }
      }();

  /// Every HD image on the device, by package name.
  Future<Map<String, Uint8List>> loadAll() async {
    final images = <String, Uint8List>{};
    final dir = await _directory();
    if (dir == null) return images;
    try {
      await for (final entry in dir.list()) {
        final name = entry.uri.pathSegments.last;
        if (entry is! File || !name.startsWith(prefix) || !name.endsWith('.png')) continue;
        final bytes = await entry.readAsBytes();
        if (bytes.isNotEmpty) images[name.substring(prefix.length, name.length - 4)] = bytes;
      }
    } catch (_) {}
    return images;
  }

  /// [packageName]'s HD image, or null when the PC put none.
  Future<Uint8List?> load(String packageName) async {
    final dir = await _directory();
    if (dir == null) return null;
    try {
      final file = File('${dir.path}/$prefix$packageName.png');
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) return bytes;
      }
    } catch (_) {}
    return null;
  }
}
