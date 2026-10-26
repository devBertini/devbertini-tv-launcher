# Changelog

## 2026.10: the devBertini fork

Built on LTvLauncher 2026.10.03. What it adds and changes:

### The Vitrine home
- A new home for the bundled cinematic themes: a hero from Android's Watch Next, the Apps row as brand plates with
  the next one peeking, a "Continuar assistindo" row, a side rail (profiles, Home, apps by category, TV inputs and
  functions, music, notifications, network, settings) whose panels open on its side, and a discreet studio signature.
- Dark, light and automatic appearance; five accent palettes; the Onest typeface, bundled.
- Home always brings the start back at once; Back from an app returns to where the focus was.
- Number keys 1 to 9 open the first nine apps.

### TV extras
- A music island with the track's progress and the player's controls; weather (Open-Meteo) and a sleep timer at the
  clock; a true-black screensaver; a night mode; profiles; a studio intro once per power-on.
- The home comes back when a console rests (on the TCL); a notice when a TV update undoes the launcher's setup.
- The launcher keeps its Flutter engine when Android destroys its screen, so returning from an app shows the home at
  once.

### Performance
- Flutter 3.47.7 with the OpenGL renderer (on the reference TV Impeller missed 80% of the frames along the row,
  OpenGL 44%).
- The home's backdrop is painted once into one picture: moving along the Apps row went from 30% late frames to none.
- App art kept on disk and decoded at its drawn size, so the home never shows a loading card.

### Tools
- `deploy.ps1`: build, back up the launcher's data, install, reapply the TV's setup checks, all in one command.
- Measuring on the TV without a VM service: `measure_frames.py`, `gpu_trace.py`, `frame_log.py`, `return_video.py`.
- Brand logos and HD card art rendered on the PC (`logo_art.py`, `hd_art.py`).

### Removed
- The upstream release, badge and store files (GitHub workflows, fastlane metadata, screenshots and release notes),
  which describe LTvLauncher's own distribution.

## Upstream: LTvLauncher's changelog

As LTvLauncher's own CHANGELOG.md wrote it, under its own heading.

### Changes from the original

#### Features
* Allow users to customize the date widget format, making it possible to display the [date, time](https://pub.dev/documentation/intl/latest/intl/DateFormat-class.html), and any arbitrary text, or to hide it completely.
* Choose what the back button does while being in the launcher: Nothing, Show a fullscreen clock, Show screensaver (a.k.a Ambient Mode).
* Show the active network status next to the date widget.
* Allow users to hide the application category titles.
* Clicking or tapping on an application card now opens it.
* Ability to disable the navigation keys sound.
* The app bar can now hide automatically while not focused.
* Map "Escape" key to the "Back" action.
* Translate to Spanish.

#### Removals
* Firebase analytics and crashlytics services.
* Unsplash integration.

#### Misc
* Upgrade Flutter version from 3.7.5 to 3.24.5.
* Replace Kotlin code with Java.
* Set new language versions: Java (17), Dart (greater than or equal to 3.4.3).
* Change versioning scheme to \<year>.\<month>.\<monthly release number>
