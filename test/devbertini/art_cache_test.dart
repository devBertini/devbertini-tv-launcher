import 'dart:io';
import 'dart:typed_data';

import 'package:flauncher/devbertini/art_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Hands the cache a folder of the test's own instead of the app's storage.
class _Paths extends PathProviderPlatform with MockPlatformInterfaceMixin {
  String? support;

  @override
  Future<String?> getApplicationSupportPath() async {
    if (support == null) throw const FileSystemException('no storage');
    return support;
  }
}

void main() {
  late Directory temp;
  late _Paths paths;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('art_cache_test_');
    paths = _Paths()..support = temp.path;
    PathProviderPlatform.instance = paths;
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  final banner = Uint8List.fromList([1, 2, 3, 4]);
  final icon = Uint8List.fromList([9, 8, 7]);

  test('saved banner and icon bytes load back equal', () async {
    final cache = ArtDiskCache();
    await cache.save('banner', 'com.app', banner);
    await cache.save('icon', 'com.app', icon);

    expect((await cache.loadAll('banner'))['com.app'], banner);
    expect((await cache.loadAll('icon'))['com.app'], icon);
  });

  test('loadAll returns only the kind asked for, by package name', () async {
    final cache = ArtDiskCache();
    await cache.save('banner', 'com.one', banner);
    await cache.save('banner', 'com.two', Uint8List.fromList([5]));
    await cache.save('icon', 'com.one', icon);

    final banners = await cache.loadAll('banner');
    final icons = await cache.loadAll('icon');

    expect(banners.keys.toSet(), {'com.one', 'com.two'});
    expect(icons.keys.toSet(), {'com.one'});
  });

  test('a new cache instance finds what an earlier one saved', () async {
    await ArtDiskCache().save('banner', 'com.app', banner);

    final reopened = await ArtDiskCache().loadAll('banner');

    expect(reopened['com.app'], banner);
  });

  test('saving again replaces the stored bytes', () async {
    final cache = ArtDiskCache();
    await cache.save('icon', 'com.app', icon);
    await cache.save('icon', 'com.app', Uint8List.fromList([42]));

    expect((await cache.loadAll('icon'))['com.app'], Uint8List.fromList([42]));
  });

  test('empty bytes are not stored', () async {
    final cache = ArtDiskCache();
    await cache.save('banner', 'com.app', Uint8List(0));

    expect(await cache.loadAll('banner'), isEmpty);
  });

  test('forget removes both the banner and the icon of that app only', () async {
    final cache = ArtDiskCache();
    await cache.save('banner', 'com.gone', banner);
    await cache.save('icon', 'com.gone', icon);
    await cache.save('banner', 'com.kept', banner);
    await cache.save('icon', 'com.kept', icon);

    await cache.forget('com.gone');

    final banners = await cache.loadAll('banner');
    final icons = await cache.loadAll('icon');
    expect(banners.containsKey('com.gone'), isFalse);
    expect(icons.containsKey('com.gone'), isFalse);
    expect(banners['com.kept'], banner);
    expect(icons['com.kept'], icon);
  });

  test('forget of an app with nothing stored does nothing', () async {
    final cache = ArtDiskCache();
    await cache.save('banner', 'com.kept', banner);

    await cache.forget('com.unknown');

    expect((await cache.loadAll('banner'))['com.kept'], banner);
  });

  test('art an older build stored is dropped, so it is taken from Android again', () async {
    final dir = Directory('${temp.path}/art')..createSync(recursive: true);
    File('${dir.path}/banner_com.old.img').writeAsBytesSync(banner);

    expect(await ArtDiskCache().loadAll('banner'), isEmpty);
    expect(File('${dir.path}/.version').readAsStringSync(), ArtDiskCache.version);
  });

  test('two first calls at once keep what one of them saves', () async {
    final cache = ArtDiskCache();
    await Future.wait([cache.save('banner', 'com.app', banner), cache.loadAll('icon')]);

    expect((await ArtDiskCache().loadAll('banner'))['com.app'], banner);
  });

  test('without storage the cache is empty and saving does not fail', () async {
    paths.support = null;
    final cache = ArtDiskCache();

    await cache.save('banner', 'com.app', banner);
    await cache.forget('com.app');

    expect(await cache.loadAll('banner'), isEmpty);
  });
}
