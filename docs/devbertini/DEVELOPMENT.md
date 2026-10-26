# Building, testing and installing

## Toolchain

Flutter 3.47.7 (Dart 3.13), JDK 21 and the Android SDK (compileSdk 36, NDK 28.2.13676358). On Windows,
`tools/devbertini/install_toolchain.ps1` downloads all three into the toolchain folder of `local.json` (below), each
download checked against its published hash. The app targets Android TV and Google TV from Android 7 (minSdk 24);
the TVs it was built on run 32-bit ARM, so release builds use `--target-platform=android-arm`.

## Machine settings

What is specific to one machine never goes into the repository: `tools/devbertini/local.json` (ignored by git;
`tools/devbertini/local.example.json` shows its shape) holds the toolchain folder, the adb path, the TVs by name with
their adb serials, the folder for backups, the place the clock's weather is built for, and each TV's setup checks.
`deploy.ps1 -ShowConfig` prints what it resolves to. Without the file the tools fall back to `adb` on the PATH and
take a device as `ip:port` or a serial, and a release build has no weather. The helper scripts are written for Windows
(PowerShell; `logo_art.py` and `hd_art.py` render with Chrome at `C:\Program Files\Google\Chrome`).

## Tests

```
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # the test mocks; again when a mocked service changes
dart run drift_dev schema generate drift_schemas/ test/generated_migrations/   # the migration tests' schemas
flutter test                      # the whole suite
flutter test test/devbertini/     # the Vitrine home and the TV extras
flutter analyze
python -B -m unittest discover -s tools/devbertini -p "test_*.py"   # the measuring tools
```

`test/mocks.mocks.dart` and `test/generated_migrations/` are generated, never versioned. A widget test of the home mounts it the way the launcher does:
on no `Scaffold` and inside `RowByRowTraversalPolicy`.

The README's pictures are the real widgets, with landscapes painted by the test itself and the brand logos that
`tools/devbertini/logo_art.py` writes to `build/devbertini-logos` (without them the plates show the apps' names):

```
VITRINE_CAPTURE=1 flutter test test/devbertini/vitrine_capture_test.dart     # Git Bash
$env:VITRINE_CAPTURE = "1"; flutter test test/devbertini/vitrine_capture_test.dart   # PowerShell
```

It writes `build/vitrine-capture/home-dark.png`, `rail-dark.png` and `home-light.png`.

## Logos and card art

The brands' marks are never in the repository; two scripts make them on your machine, and `deploy.ps1 -Art` puts
them on the TV, where the home reads them from the launcher's files folder.

- `python -B tools/devbertini/logo_art.py <svg folder>`: the plate logos, `logo_light_<package>.png` and
  `logo_black_<package>.png` in `build/devbertini-logos`, from these SVGs in `<svg folder>`: `netflix.svg`,
  `youtube.svg` and `youtube-white.svg`, `hbomax.svg` and `hbomax-white.svg`, `prime.svg`, `twitch-purple.svg` and
  `twitch.svg`, `spotify.svg`, `play.svg`.
- `python -B tools/devbertini/hd_art.py <folder of the apps' own banners>`: 960x540 art that the launcher prefers
  over the apps' own small banners, drawn from the brands' vector logos (downloaded once from Wikimedia Commons), in `build/devbertini-art`.

## Building

```
flutter build apk --release --target-platform=android-arm
```

A release build is signed with the keystore named by the environment variables `KEYSTORE_FILE`, `KEYSTORE_PASSWORD`,
`KEY_ALIAS` and `KEY_PASSWORD` (or `storeFile`, `storePassword`, `keyAlias` and `keyPassword` in
`android/local.properties`); without a keystore the release APK is unsigned and will not install. To try the launcher
without one, `flutter build apk --debug` installs beside any other build as `com.leanbitlab.ltvL.debug`. An update
installs over the previous one only when both are signed with the same key. `tools/devbertini/build_release.ps1`
builds the release with the toolchain of `local.json`, the keystore `keys\ltv-release.jks` of the toolchain folder
(its password in `keys\ltv-release.pass`, alias `ltv`; never in the repository) and the weather place of
`local.json`.

## Installing on a TV

Enable Developer options and Wireless debugging on the TV, then from the PC:

```
tools/devbertini/deploy.ps1 -Device <name>          # build, back up, install, open the home, disconnect
tools/devbertini/deploy.ps1 -Device <name> -Setup   # also reapply the TV's setup checks
tools/devbertini/deploy.ps1 -Device <name> -ApkPath build/app/outputs/flutter-apk/app-debug.apk   # another APK
```

The first connection after the TV reboots needs its pairing code (Settings, System, Developer options, Wireless
debugging, Pair device with pairing code): add `-Pair <tv-ip>:<port> -Code <6 digits>` to the command, which then
goes on to build and install.

Before every install `deploy.ps1` asks the launcher for a snapshot of its data (every profile, the settings;
`SnapshotReceiver`) and copies it to the backups folder; the install does not run when that copy fails, and
`-Restore <folder>` puts a copy back. The setup checks (from `local.json`) read each setting first and change only what
differs. `local.example.json` holds the ones a Google TV needs: the launcher takes the HOME role, Google TV's own home
and its setup recovery are disabled (`pm disable-user`; `pm enable` undoes it), the launcher's permissions (usage
stats, overlay, TV listings, notification listener, secure settings), its accessibility service, "Don't keep
activities" off and the system screensaver off. After an install only the checks marked `on_install` run. `deploy.ps1 -Art` also puts
the brand logos and HD card art on the device (`tools/devbertini/logo_art.py`, `tools/devbertini/hd_art.py`).

Over wireless debugging `adb install` may print `INSTALL_PARSE_FAILED_NOT_APK` from a first streamed attempt and
still install: the "installed: lastUpdateTime=" line is what tells.

Never install another build under the home's own package on a TV in use: a build signed with another key replaces
the launcher and takes its data with it. A profile build (the lab of PERFORMANCE.md) installs beside it as
`com.leanbitlab.ltvL.profile`; check the package with `aapt2 dump packagename <apk>` before installing.

## Driving the TV over adb

`input keyevent --longpress` and `--duration` reach the launcher as a click, not a hold: they open the focused app.
Check `dumpsys window | grep mCurrentFocus` before sending more keys, so keys meant for the launcher never land in
another app.

From Git Bash, prefix device paths with `MSYS_NO_PATHCONV=1` (`MSYS_NO_PATHCONV=1 adb shell ls /sdcard/...`): without
it Git Bash rewrites `/sdcard/...` into `C:/Program Files/Git/sdcard/...` before adb sees it. The same variable also
stops the conversion adb needs for a local path, so local paths are written in Windows form (`C:/...`). PowerShell
passes paths unchanged.
