# Performance on the TV

The bar is simple: the home never feels heavy, stuck or stuttering on a mid-range TV. It is measured on the device,
frame by frame, never assumed from a desktop run. The reference TV is a TCL C7K (Google TV, Android 14, a Mali-G52
GPU, a 4K panel driven at 1920x1080); the second device is a Xiaomi TV Box S (3rd gen,
Mali-G310).

## What the TV does with every frame

- The TCL's hardware composer puts both of the launcher's layers (Flutter's surface and the activity's window,
  1920x1080 each, scaled to the panel) on the GPU: SurfaceFlinger's composition takes about 4.5 ms of GPU in every
  frame, so the launcher's own frame has about 12 ms, not 16.7.
- On the Mali-G52 with Skia (OpenGL), large gradients painted every frame are expensive: the hero's three fades alone
  took about 11 ms of GPU per frame. The home therefore paints its backdrop (field, hero art, fades and the night dim)
  once into a single picture of the screen and draws that image (`VitrineBackdrop`).
- Impeller (Vulkan) missed 80% of the frames along the row where OpenGL missed 44% (on the home of that day, before
  its backdrop was baked), so the manifest keeps OpenGL. Flutter warns
  that the opt-out goes away in a future release; each Flutter update measures Impeller again.
- Flutter shortens its animations to 5% while the system's `transition_animation_scale` is 0; at any other scale it
  plays them whole, so a measurement names the scale it ran at.
- Faster threads are not always smoother here. As drawn, a frame of the side rail's opening takes about 5 ms of UI,
  8 of raster and 7 of GPU and reaches the panel steadily one refresh late. Making the UI and raster threads faster
  (the signature baked into images, the rail's items built once) put the frames at the panel's deadline, where they
  flipped between one and two refreshes late and missed a frame at most openings. Those changes were measured and
  taken back: a change to the rail's cost is measured on the TV before it stays.

## Results

Moving along the Apps row (three runs per moment):

| Build | Late frames | GPU per frame |
|---|---|---|
| Backdrop painted live (three fades every frame) | 36 of 120 (30%), p95 33.4 ms | about 17.8 ms + 4.5 composition |
| Backdrop as one picture | 0 of 129 | 6.8 ms + 4.5 composition |

The side rail, opened and closed 12 times with the system animations at 0.5x (120 frame intervals):

| Rail | Missed (`measure_frames.py`) | Late (`gpu_trace.py`) | UI / raster p50 (`frame_log.py`) |
|---|---|---|---|
| As drawn | 2 to 3 | 1 | 5.2 / 8.3 ms |
| Signature baked into images | 11 | 12 | 4.7 / 4.7 ms |
| Items also built once per change | 4 | 10 | about 3.5 / 5 ms |

Cold start 0.49 to 0.64 s, memory (PSS) 66 to 78 MiB, idle CPU 1 to 5 ticks in 30 s (all runs of the day).

Home pressed inside an app (`return_video.py`): when Android destroyed the home's screen ("Don't keep activities"),
the old home went black and rebuilt itself over about ten frames; with the Flutter engine kept alive across screens
(`HomeEngine`), the frame after the app's last one is the settled home.

## The tools

All of them drive the TV over adb (`input keyevent`) and read what the panel really showed. Each takes a device as a
name from `tools/devbertini/local.json`, an `ip:port` or a serial (DEVELOPMENT.md, "Machine settings").

- `tools/devbertini/measure_frames.py --label <name> --device <name|ip:port>`: missed frames per moment (along the row, up to the hero and
  down, the side rail opened and closed, opening an app and coming back), cold start, memory and idle CPU, from
  SurfaceFlinger's present times (`dumpsys SurfaceFlinger --latency`), saved under `build/devbertini-measure/`. It
  cold-starts the home first, so every moment begins on the first app. Pause music first (the island's level meter
  draws every frame). It presses Home, so it refuses to start while another app is in front unless `--force`.
- `tools/devbertini/gpu_trace.py --label <name> --device <name|ip:port> [--package <id>] [--moment row|rail]
  [--lab <words>]`: a system trace
  (`atrace gfx`) of a moment; prints the GPU time of each of the app's frames and of SurfaceFlinger's compositions
  where each had the GPU alone, and what the panel showed. Works on the installed home itself.
- `tools/devbertini/frame_log.py --label <name> --device <name|ip:port>`: the UI and raster thread times of each frame (Flutter's
  `FrameTiming`, written to logcat by a build made with `--dart-define=DEVBERTINI_FRAME_LOG=true`). `flutter drive`
  cannot reach the app's VM service over wireless debugging, so this replaces its timeline.
- `tools/devbertini/return_video.py --device <name|ip:port>`: Home pressed inside an app, recorded frame by frame
  (`screenrecord --output-format=frames`), each frame a PNG under `build/devbertini-return/` with its distance from the
  settled home; `logcat -b events` says whether Android destroyed the home's screen meanwhile.
- The lab: a profile build beside the home, which `gpu_trace.py --lab <words>` runs with parts of the home left out
  (`cards`, `semantics`, and the rail's `rail-panel`, `rail-profile`, `rail-signature`, `rail-labels`, `rail-frames`;
  `lib/devbertini/perf_lab.dart`), to find what a part costs. A `frame_log.py` run right after reads the same words.

  ```
  flutter build apk --profile --target-platform=android-arm --dart-define=DEVBERTINI_FRAME_LOG=true --dart-define=DEVBERTINI_PERF_LAB=true
  aapt2 dump packagename build/app/outputs/flutter-apk/app-profile.apk   # must print com.leanbitlab.ltvL.profile
  adb install -r build/app/outputs/flutter-apk/app-profile.apk
  adb shell pm grant com.leanbitlab.ltvL.profile android.permission.READ_TV_LISTINGS
  ```

  The permission makes the lab read the same Watch Next list as the home (without it the lab draws no hero and
  measures a lighter home). Its logos and HD art go into `/sdcard/Android/data/com.leanbitlab.ltvL.profile/files`
  once it has run. Uninstall it when done.

The tools' own tests: `python -B -m unittest discover -s tools/devbertini -p "test_*.py"`.
