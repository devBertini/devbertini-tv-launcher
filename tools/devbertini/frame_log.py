#!/usr/bin/env python3
# Copyright (C) 2026 Claudio Bertini (devBertini). GPL-3.0-or-later, like the rest of this project.
"""Says which thread makes the home's frames late on the TV: the UI thread (build, layout, paint) or the raster
thread (drawing the layers), from the `DevBertiniFrame` lines a build made with
`--dart-define=DEVBERTINI_FRAME_LOG=true` writes to logcat (lib/devbertini/frame_log.dart). measure_frames.py says how
many frames the panel showed late; this says why.

    python -B tools/devbertini/frame_log.py --label <name> [--device <name>|<serial>] [--package com.leanbitlab.ltvL.profile]
                                            [--repeat 3] [--force]

Use it on the profile build, which installs beside the home as com.leanbitlab.ltvL.profile and never replaces it:
    flutter build apk --profile --target-platform=android-arm --dart-define=DEVBERTINI_FRAME_LOG=true
    adb install -r build/app/outputs/flutter-apk/app-profile.apk   (then push its logos and HD art: docs/devbertini/PERFORMANCE.md)
It opens that app, waits for the intro and the art, then drives the moments with `input keyevent` (along the row,
right and back; up to the hero and down; the side rail opened and closed), each between two `DevBertiniMark` log
lines, and reads the frames back from logcat. Writes build/devbertini-measure/<label>.frames.json and prints, per
moment and thread, the median, the 90th percentile, the worst time and how many frames went over the 16.7 ms budget,
and beside them what the panel showed in the same moments (SurfaceFlinger's present times, read as measure_frames.py
reads them): frames short on Flutter's side but late on the panel point past Flutter, at the GPU or the TV's
compositor (gpu_trace.py reads those). Refuses to start while another app is in front (someone may be watching)
unless --force; stops the app it opened at the end.
"""
import argparse
import importlib.util
import json
import os
import re
import statistics
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
# The adb path and the device names come from local.json (local_config.py), not from this file.
_spec = importlib.util.spec_from_file_location("local_config", os.path.join(HERE, "local_config.py"))
local_config = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(local_config)
ADB = local_config.adb_path()
HOME_PKG = "com.leanbitlab.ltvL"
BUDGET_US = 16_667
OUT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "build", "devbertini-measure")
# measure_frames.py reads what the panel showed (SurfaceFlinger's present times); its reading is reused here.
_spec = importlib.util.spec_from_file_location("measure_frames", os.path.join(HERE, "measure_frames.py"))
measure_frames = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(measure_frames)
FRAME = re.compile(r"DevBertiniFrame build=(\d+) raster=(\d+) total=(\d+)")
MARK = re.compile(r"DevBertiniMark[^:]*:\s+(\S+) (start|end)")  # logcat writes the pid between the tag and the colon
MOMENTS = {
    "row": ["DPAD_RIGHT"] * 5 + ["DPAD_LEFT"] * 5,
    "hero_and_back": ["DPAD_UP", "DPAD_DOWN", "DPAD_UP", "DPAD_DOWN"],
    "rail": ["DPAD_LEFT", "DPAD_RIGHT", "DPAD_LEFT", "DPAD_RIGHT"],
}


def adb(serial, *args):
    p = subprocess.run([ADB, "-s", serial, *args], capture_output=True, text=True, encoding="utf-8", errors="replace")
    return p.stdout


def resolve(device):
    if re.fullmatch(r"[\d.]+:\d+", device):
        return device
    serial = local_config.serial_for(device)
    if not serial:
        sys.exit(local_config.unknown_device(device))
    for line in subprocess.run([ADB, "devices"], capture_output=True, text=True).stdout.splitlines():
        name = line.split("\t")[0]
        if serial in name and line.endswith("device"):
            return name
    sys.exit(f"the {device} is not connected (adb connect first)")


def focused_package(window_dump):
    """The package of the window in front, from `dumpsys window` (its mCurrentFocus line), or None."""
    m = re.search(r"mCurrentFocus=Window\{\S+ \S+ ([\w.]+)/", window_dump)
    return m.group(1) if m else None


def split_frames(log_text):
    """The frames of each moment: the DevBertiniFrame lines between that moment's start and end marks, in order."""
    moments, current = {}, None
    for line in log_text.splitlines():
        mark = MARK.search(line)
        if mark:
            name, edge = mark.groups()
            if edge == "start":
                current = name
                moments.setdefault(name, [])
            elif current == name:
                current = None
            continue
        frame = FRAME.search(line)
        if frame and current:
            build, raster, total = (int(x) for x in frame.groups())
            moments[current].append({"build": build, "raster": raster, "total": total})
    return moments


def summarize(frames):
    def stats(values):
        if not values:
            return {"p50_ms": None, "p90_ms": None, "max_ms": None, "over_budget": 0}
        ordered = sorted(values)
        return {
            "p50_ms": round(statistics.median(ordered) / 1000, 1),
            "p90_ms": round(ordered[min(len(ordered) - 1, int(0.9 * len(ordered)))] / 1000, 1),
            "max_ms": round(ordered[-1] / 1000, 1),
            "over_budget": sum(1 for v in ordered if v > BUDGET_US),
        }
    return {
        "frames": len(frames),
        "build": stats([f["build"] for f in frames]),
        "raster": stats([f["raster"] for f in frames]),
    }


def app_layer(serial, package):
    """The app's Flutter surface as SurfaceFlinger names it, or None."""
    for line in adb(serial, "shell", "dumpsys SurfaceFlinger --list").splitlines():
        line = line.strip()
        if line.startswith(f"SurfaceView[{package}/") and "(BLAST)" in line:
            return line
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--label", required=True)
    ap.add_argument("--device", default="tcl")
    ap.add_argument("--package", default=HOME_PKG + ".profile")
    ap.add_argument("--repeat", type=int, default=3)
    ap.add_argument("--force", action="store_true", help="start even when another app is in front")
    a = ap.parse_args()
    serial = resolve(a.device)
    front = focused_package(adb(serial, "shell", "dumpsys window | grep mCurrentFocus"))
    if front and front not in (HOME_PKG, a.package) and not a.force:
        sys.exit(f"{front} is in front on the {a.device}: someone may be watching; open the home first or pass --force")
    adb(serial, "logcat", "-c")
    adb(serial, "shell", f"am start -n {a.package}/{HOME_PKG}.MainActivity")
    time.sleep(18)  # the studio intro, then the art and the logos
    layer = app_layer(serial, a.package)
    shown = {}  # what the panel showed in each moment, from SurfaceFlinger, beside Flutter's own times
    period = 16_666_666
    for name, keys in MOMENTS.items():
        for _ in range(a.repeat):
            if layer:
                adb(serial, "shell", f"dumpsys SurfaceFlinger --latency-clear '{layer}'")
            adb(serial, "shell", f"log -t DevBertiniMark '{name} start'")
            time.sleep(0.3)
            for key in keys:
                adb(serial, "shell", f"input keyevent KEYCODE_{key}")
                time.sleep(0.4)
            time.sleep(0.6)
            adb(serial, "shell", f"log -t DevBertiniMark '{name} end'")
            if layer:
                period, present = measure_frames.frames(serial, layer)
                shown.setdefault(name, []).append(present)
            time.sleep(0.3)
    text = adb(serial, "logcat", "-d", "-v", "brief", "flutter:I", "DevBertiniMark:I", "*:S")
    adb(serial, "shell", f"am force-stop {a.package}")
    moments = split_frames(text)
    if not any(moments.values()):
        sys.exit("no DevBertiniFrame lines: is the app built with --dart-define=DEVBERTINI_FRAME_LOG=true?")
    result = {"label": a.label, "device": a.device, "package": a.package, "time": time.strftime("%Y-%m-%d %H:%M"),
              "moments": {name: summarize(frames) for name, frames in moments.items()},
              "shown": {name: measure_frames.summarize(period, lists) for name, lists in shown.items()}}
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, f"{a.label}.frames.json")
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(result, handle, indent=2)
    print(f"{a.label} ({a.device}, {a.package}), budget 16.7 ms")
    print(f"{'moment':<15}{'frames':>7}  {'build p50/p90/max ms':>22} {'over':>5}  {'raster p50/p90/max ms':>22} {'over':>5}")
    for name, s in result["moments"].items():
        b, r = s["build"], s["raster"]
        print(f"{name:<15}{s['frames']:>7}  {str(b['p50_ms']) + '/' + str(b['p90_ms']) + '/' + str(b['max_ms']):>22} "
              f"{b['over_budget']:>5}  {str(r['p50_ms']) + '/' + str(r['p90_ms']) + '/' + str(r['max_ms']):>22} {r['over_budget']:>5}")
    for name, s in result["shown"].items():
        print(f"shown {name:<12} intervals {s.get('intervals')}, late {s.get('missed')} ({s.get('missed_pct')}%), "
              f"p50/p95/max {s.get('p50_ms')}/{s.get('p95_ms')}/{s.get('max_ms')} ms")
    print(f"saved {path}")


if __name__ == "__main__":
    main()
