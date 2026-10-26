#!/usr/bin/env python3
# Copyright (C) 2026 Claudio Bertini (devBertini). GPL-3.0-or-later, like the rest of this project.
"""Measures how smoothly the launcher draws on the TV, from the frames the screen really showed.

  python tools/devbertini/measure_frames.py --label baseline [--device <name>|<serial>|ip:port] [--repeat 3] [--skip-open]

Each moment is driven with `adb shell input keyevent` from the home: moving along the row, moving between the row and
what is above it (the hero's capsules on the Vitrine, the top bar before it), opening the side rail from the first
plate and closing it, opening the first app, returning home from it. The cold starts come first, so the moments begin where a
fresh home puts the focus, on the first plate (Home with the home in front also goes back there). Frame present times come from SurfaceFlinger
(`dumpsys SurfaceFlinger --latency` on the launcher's Flutter surface), so the numbers are what the panel showed,
not what Flutter thinks it drew. Within a moment, frames closer than 100 ms belong to one animation; the gap between
two such frames over 1.5 refresh periods is a missed frame. Also: cold start (the system's launch time after a force stop),
PSS and idle CPU ticks over 30 s at the home. The intro is not measured here: it plays once per power-on.

Writes build/devbertini-measure/<label>.json and prints the table. adb must already be connected (deploy.ps1
-KeepConnection, or adb connect).
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
PKG = "com.leanbitlab.ltvL"
BURST_GAP_NS = 100_000_000
OUT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "build", "devbertini-measure")


def adb(serial, *args, check=False):
    p = subprocess.run([ADB, "-s", serial, *args], capture_output=True, text=True, encoding="utf-8", errors="replace")
    if check and p.returncode != 0:
        sys.exit(f"adb {' '.join(args)} failed: {p.stderr.strip()}")
    return p.stdout


def shell(serial, command):
    return adb(serial, "shell", command)


def resolve(device):
    if re.fullmatch(r"[\d.]+:\d+", device):
        return device
    serial = local_config.serial_for(device)
    if not serial:
        sys.exit(local_config.unknown_device(device))
    listed = subprocess.run([ADB, "devices"], capture_output=True, text=True).stdout.splitlines()
    for line in listed:
        name = line.split("\t")[0]
        if serial in name and line.endswith("device"):
            return name
    sys.exit(f"the {device} is not connected (run deploy.ps1 -KeepConnection first)")


def flutter_layer(serial):
    for line in shell(serial, "dumpsys SurfaceFlinger --list").splitlines():
        line = line.strip()
        if line.startswith(f"SurfaceView[{PKG}/") and "(BLAST)" in line:
            return line
    sys.exit("the launcher's Flutter surface is not on screen (is the home in front?)")


def keys(serial, *names, gap=0.35):
    for name in names:
        shell(serial, f"input keyevent KEYCODE_{name}")
        time.sleep(gap)


def frames(serial, layer):
    """(refresh period ns, actual present times ns) recorded since the last clear."""
    lines = shell(serial, f"dumpsys SurfaceFlinger --latency '{layer}'").split()
    period = int(lines[0])
    rows = [lines[i:i + 3] for i in range(1, len(lines) - 2, 3)]
    present = sorted(int(r[1]) for r in rows if r[1] != "0" and int(r[1]) < 2**62)
    return period, present


def summarize(period, present_lists):
    intervals = []
    count = 0
    for present in present_lists:
        count += len(present)
        for a, b in zip(present, present[1:]):
            if b - a <= BURST_GAP_NS:
                intervals.append((b - a) / 1e6)
    if not intervals:
        return {"frames": count, "intervals": 0}
    ordered = sorted(intervals)
    budget = 1.5 * period / 1e6
    return {
        "frames": count,
        "intervals": len(intervals),
        "p50_ms": round(statistics.median(ordered), 1),
        "p95_ms": round(ordered[min(len(ordered) - 1, int(0.95 * len(ordered)))], 1),
        "max_ms": round(ordered[-1], 1),
        "missed": sum(1 for x in intervals if x > budget),
        "missed_pct": round(100 * sum(1 for x in intervals if x > budget) / len(intervals), 1),
    }


def home(serial):
    keys(serial, "HOME", gap=2.5)


def focused_package(window_dump):
    """The package of the window in front, from `dumpsys window` (its mCurrentFocus line), or None."""
    m = re.search(r"mCurrentFocus=Window\{\S+ \S+ ([\w.]+)/", window_dump)
    return m.group(1) if m else None


def measure_moment(serial, act, repeat):
    collected = []
    for _ in range(repeat):
        home(serial)
        layer = flutter_layer(serial)
        act(serial, layer, collected)
    return frames(serial, flutter_layer(serial))[0], collected


def run_moment(serial, steps):
    """`steps(serial)` runs between a clear and a read of the Flutter surface."""
    def act(serial, layer, collected):
        shell(serial, f"dumpsys SurfaceFlinger --latency-clear '{layer}'")
        steps(serial)
        time.sleep(0.8)
        collected.append(frames(serial, layer)[1])
    return act


def open_and_return(serial, repeat):
    opened, returned, period = [], [], 16_666_666
    for _ in range(repeat):
        home(serial)
        layer = flutter_layer(serial)
        shell(serial, f"dumpsys SurfaceFlinger --latency-clear '{layer}'")
        keys(serial, "DPAD_CENTER", gap=1.5)
        period, present = frames(serial, layer)
        opened.append(present)
        time.sleep(4)
        shell(serial, f"dumpsys SurfaceFlinger --latency-clear '{layer}'")
        keys(serial, "HOME", gap=2.5)
        layer = flutter_layer(serial)
        returned.append(frames(serial, layer)[1])
    return period, opened, returned


def cold_start(serial, repeat):
    """The launcher is the home, so after a force stop the system starts it again by itself: the time is the
    system's own `Displayed ... +Nms` line for that start."""
    times = []
    for _ in range(repeat):
        adb(serial, "logcat", "-c")
        shell(serial, f"am force-stop {PKG}")
        time.sleep(7)
        m = re.search(rf"Displayed {re.escape(PKG)}/\S+.*?\+(?:(\d+)s)?(\d+)ms", adb(serial, "logcat", "-d"))
        if m:
            times.append(int(m.group(1) or 0) * 1000 + int(m.group(2)))
    return times


def pss_kb(serial):
    m = re.search(r"TOTAL PSS:\s*(\d+)|TOTAL\s+(\d+)", shell(serial, f"dumpsys meminfo {PKG}"))
    return int(m.group(1) or m.group(2)) if m else None


def idle_ticks(serial, seconds=30):
    pid = shell(serial, f"pidof {PKG}").strip().split()[0]
    def ticks():
        fields = shell(serial, f"cat /proc/{pid}/stat").rsplit(")", 1)[1].split()
        return int(fields[11]) + int(fields[12])
    home(serial)
    time.sleep(3)
    first = ticks()
    time.sleep(seconds)
    return ticks() - first


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--label", required=True)
    ap.add_argument("--device", default="tcl")
    ap.add_argument("--repeat", type=int, default=3)
    ap.add_argument("--skip-open", action="store_true", help="do not open an app (nothing launches on the TV)")
    ap.add_argument("--force", action="store_true", help="measure even when an app is in front (it is closed by Home)")
    a = ap.parse_args()
    serial = resolve(a.device)
    # The run starts by pressing Home: with an app in front someone may be watching, so it stops before any key.
    front = focused_package(shell(serial, "dumpsys window | grep mCurrentFocus"))
    if front and front != PKG and not a.force:
        sys.exit(f"{front} is in front on the {a.device}: someone may be watching; open the home first or pass --force")
    result = {"label": a.label, "device": a.device, "time": time.strftime("%Y-%m-%d %H:%M"),
              "model": shell(serial, "getprop ro.product.model").strip(), "moments": {}}

    result["cold_start_ms"] = cold_start(serial, a.repeat)
    time.sleep(10)  # the last start's art, logos and Watch Next list, before the first moment
    period, row = measure_moment(serial, run_moment(serial, lambda s: keys(
        s, *(["DPAD_RIGHT"] * 5 + ["DPAD_LEFT"] * 5))), a.repeat)
    result["refresh_ms"] = round(period / 1e6, 2)
    result["moments"]["row"] = summarize(period, row)
    _, bar = measure_moment(serial, run_moment(serial, lambda s: keys(s, "DPAD_UP", "DPAD_DOWN", "DPAD_UP", "DPAD_DOWN",
                                                                      gap=0.6)), a.repeat)
    result["moments"]["top_bar_and_back"] = summarize(period, bar)
    _, rail = measure_moment(serial, run_moment(serial, lambda s: keys(s, "DPAD_LEFT", "DPAD_RIGHT", "DPAD_LEFT",
                                                                       "DPAD_RIGHT", gap=0.6)), a.repeat)
    result["moments"]["rail_open_and_close"] = summarize(period, rail)
    if not a.skip_open:
        _, opened, returned = open_and_return(serial, a.repeat)
        result["moments"]["open_app"] = summarize(period, opened)
        result["moments"]["return_home"] = summarize(period, returned)
    result["pss_kb"] = pss_kb(serial)
    result["idle_cpu_ticks_30s"] = idle_ticks(serial)
    home(serial)

    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, f"{a.label}.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(result, f, indent=1)
    print(f"{result['model']} ({a.device}), refresh {result['refresh_ms']} ms, {a.repeat} runs per moment")
    print(f"{'moment':<18}{'frames':>7}{'p50 ms':>8}{'p95 ms':>8}{'max ms':>8}{'missed':>8}{'missed %':>10}")
    for name, m in result["moments"].items():
        print(f"{name:<18}{m['frames']:>7}{m.get('p50_ms', '-'):>8}{m.get('p95_ms', '-'):>8}{m.get('max_ms', '-'):>8}"
              f"{m.get('missed', '-'):>8}{m.get('missed_pct', '-'):>10}")
    print(f"cold start ms {result['cold_start_ms']}, PSS {result['pss_kb']} kB, idle CPU ticks/30 s "
          f"{result['idle_cpu_ticks_30s']}")
    print(f"saved {path}")


if __name__ == "__main__":
    main()
