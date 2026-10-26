#!/usr/bin/env python3
"""Says how long the TV's GPU takes for each frame of the launcher moving along its Apps row, and how much of it is
SurfaceFlinger's own composition, from a system trace (`atrace gfx`), with no VM service and no build of its own.

    python -B tools/devbertini/gpu_trace.py --label <name> [--device <name>|<serial>] [--package com.leanbitlab.ltvL.profile]
                                            [--moment row|rail] [--lab cards] [--repeat 3] [--force]

The app's `GPU completion` thread waits on each frame's fence from queueBuffer until the GPU is done with it, and
SurfaceFlinger's `RE Completion` thread does the same for every composition its RenderEngine draws (on the TCL every
frame: its hardware composer puts the launcher's two layers on the GPU). A job's own GPU time is read where it had
the GPU to itself, from its queueing to its fence: the first frame of each press, and the compositions between
presses; jobs that overlap share the GPU and say nothing alone. A frame fits the 60 Hz budget only when the app's
job and SurfaceFlinger's fit 16.7 ms together.

The package is opened from cold so the focus starts on the first plate: the home (`com.leanbitlab.ltvL`) is force
stopped and comes back by itself; any other package is started. `--lab` writes the words of
`lib/devbertini/perf_lab.dart` (the parts to leave out, today `cards`) to the package's `perf_lab.txt` first, only
for a lab build (`--dart-define=DEVBERTINI_PERF_LAB=true`, beside the home), and checks in logcat that the app read
them. A row run is Right x5 then Left x5, one press every 0.35 s, as in measure_frames.py's row moment; a rail run
opens and closes the side rail twice (Left, Right, one press every 0.6 s); what the panel showed in the same runs is
read beside it. Writes
build/devbertini-measure/<label>.gpu.json. Refuses to start while another app is in front (someone may be watching)
unless --force.
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
_spec = importlib.util.spec_from_file_location("measure_frames", os.path.join(HERE, "measure_frames.py"))
measure_frames = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(measure_frames)
# The adb path and the device names come from local.json (local_config.py), not from this file.
_cfg_spec = importlib.util.spec_from_file_location("local_config", os.path.join(HERE, "local_config.py"))
local_config = importlib.util.module_from_spec(_cfg_spec)
_cfg_spec.loader.exec_module(local_config)

ADB = local_config.adb_path()
HOME_PKG = measure_frames.PKG
OUT = measure_frames.OUT
BUDGET_MS = 1000 / 60
# Each moment starts and ends on the first plate: along the row, or the side rail opened (Left) and closed (Right).
MOMENTS = {
    "row": (["DPAD_RIGHT"] * 5 + ["DPAD_LEFT"] * 5, 0.35),
    "rail": (["DPAD_LEFT", "DPAD_RIGHT"] * 2, 0.6),
}
# One atrace line: task-tid (tgid) [cpu] flags seconds: tracing_mark_write: B|pid|name, E|pid or C|pid|name|value.
MARK = re.compile(r"^\s*(.+?)-(\d+)\s+\(\s*(\d+|-+)\)\s+\[\d+\]\s+\S+\s+([\d.]+): tracing_mark_write: (.*)$")


def slices(trace_text):
    """Every begin-end slice of the trace as (thread name, tid, tgid, name, start s, end s)."""
    open_slices, done = {}, []
    for line in trace_text.splitlines():
        m = MARK.match(line)
        if not m:
            continue
        thread, tid, tgid, ts, body = m.group(1), m.group(2), m.group(3), float(m.group(4)), m.group(5)
        parts = body.split("|")
        if parts[0] == "B" and len(parts) >= 3:
            open_slices.setdefault(tid, []).append((thread, tgid, "|".join(parts[2:]), ts))
        elif parts[0] == "E" and open_slices.get(tid):
            thread, tgid, name, start = open_slices[tid].pop()
            done.append((thread, tid, tgid, name, start, ts))
    return done


def gpu_jobs(all_slices, app_pid):
    """The GPU jobs in order of queueing: ('app' or 'sf', queued s, done s). An app job is a frame of [app_pid] (its
    fence wait on the `GPU completion` thread); an SF job is a RenderEngine composition (`RE Completion`)."""
    jobs = []
    for _thread, _tid, tgid, name, start, end in all_slices:
        if tgid == str(app_pid) and name.startswith("waiting for GPU completion"):
            jobs.append(("app", start, end))
        elif name.startswith("waiting for RE Completion"):
            jobs.append(("sf", start, end))
    return sorted(jobs, key=lambda job: job[1])


def alone(jobs):
    """The jobs that had the GPU to themselves (no other job between their queueing and their fence), with their own
    GPU time: ('app' or 'sf', ms)."""
    found = []
    for i, (kind, queued, done) in enumerate(jobs):
        if all(not (q < done and d > queued) for j, (_, q, d) in enumerate(jobs) if j != i):
            found.append((kind, round((done - queued) * 1000, 2)))
    return found


def summarize(runs):
    """Over the runs (each a list of jobs, judged alone or not within its own run): per kind, the own GPU time of the
    jobs that ran alone, how many frames the app drew, and the two medians added, the GPU time of a frame."""
    def stats(values):
        if not values:
            return {"jobs": 0}
        ordered = sorted(values)
        return {
            "jobs": len(ordered),
            "p50_ms": round(statistics.median(ordered), 1),
            "p90_ms": round(ordered[min(len(ordered) - 1, int(0.9 * len(ordered)))], 1),
            "max_ms": round(ordered[-1], 1),
        }
    timed = [job for run in runs for job in alone(run)]
    app = [ms for kind, ms in timed if kind == "app"]
    sf = [ms for kind, ms in timed if kind == "sf"]
    result = {"app": stats(app), "surfaceflinger": stats(sf),
              "frames": sum(1 for run in runs for kind, *_ in run if kind == "app")}
    if app and sf:
        result["per_frame_ms"] = round(statistics.median(app) + statistics.median(sf), 1)
        result["fits_60hz"] = result["per_frame_ms"] <= BUDGET_MS
    return result


def adb(serial, *args):
    return measure_frames.adb(serial, *args)


def files_dir(package):
    return f"/sdcard/Android/data/{package}/files"


def open_cold(serial, package):
    adb(serial, "logcat", "-c")
    adb(serial, "shell", f"am force-stop {package}")
    if package == HOME_PKG:
        time.sleep(1)
        adb(serial, "shell", "input keyevent KEYCODE_HOME")  # the home comes back by itself; Home makes sure
    else:
        adb(serial, "shell", f"am start -n {package}/{HOME_PKG}.MainActivity")
    time.sleep(18)  # the intro where it plays, then the art, the logos and the Watch Next list


def app_pid(serial, package):
    pid = adb(serial, "shell", f"pidof {package}").strip().split()
    if not pid:
        sys.exit(f"{package} is not running on the device")
    return pid[0]


def app_layer(serial, package):
    for line in adb(serial, "shell", "dumpsys SurfaceFlinger --list").splitlines():
        line = line.strip()
        if line.startswith(f"SurfaceView[{package}/") and "(BLAST)" in line:
            return line
    return None


def run_once(serial, layer, moment="row"):
    """One run of [moment] under atrace: the trace text and what the panel showed (present times)."""
    if layer:
        adb(serial, "shell", f"dumpsys SurfaceFlinger --latency-clear '{layer}'")
    adb(serial, "shell", "atrace --async_start -b 8192 gfx")
    time.sleep(0.5)
    keys, gap = MOMENTS[moment]
    for key in keys:
        adb(serial, "shell", f"input keyevent KEYCODE_{key}")
        time.sleep(gap)
    time.sleep(0.8)
    text = subprocess.run([ADB, "-s", serial, "exec-out", "atrace --async_stop"], capture_output=True,
                          text=True, encoding="utf-8", errors="replace").stdout
    period, present = measure_frames.frames(serial, layer) if layer else (16_666_666, [])
    return text, period, present


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--label", required=True)
    ap.add_argument("--device", default="tcl")
    ap.add_argument("--package", default=HOME_PKG + ".profile")
    ap.add_argument("--lab", default=None, help="words for perf_lab.txt (a lab build only); '' clears it")
    ap.add_argument("--moment", choices=sorted(MOMENTS), default="row")
    ap.add_argument("--repeat", type=int, default=3)
    ap.add_argument("--force", action="store_true", help="start even when another app is in front")
    a = ap.parse_args()
    serial = measure_frames.resolve(a.device)
    front = measure_frames.focused_package(adb(serial, "shell", "dumpsys window | grep mCurrentFocus"))
    if front and front not in (HOME_PKG, a.package) and not a.force:
        sys.exit(f"{front} is in front on the {a.device}: someone may be watching; open the home first or pass --force")
    if a.lab is not None:
        if a.package == HOME_PKG:
            sys.exit("--lab is for the lab build beside the home, never the home itself")
        words = " ".join(a.lab.split())
        adb(serial, "shell", f"echo '{words}' > {files_dir(a.package)}/perf_lab.txt")
    open_cold(serial, a.package)
    if a.lab is not None:
        log = adb(serial, "logcat", "-d", "-v", "brief", "flutter:I", "*:S")
        read = re.search(r"DevBertiniPerfLab words=(\S*)", log)
        if not read or set(filter(None, read.group(1).split(","))) != set(a.lab.split()):
            sys.exit(f"the app did not read the lab words {a.lab!r} (log: {read.group(0) if read else 'none'}): "
                     "is it a lab build?")
    pid = app_pid(serial, a.package)
    layer = app_layer(serial, a.package)
    runs, presents, period = [], [], 16_666_666
    for _ in range(a.repeat):
        # Each run ends where it began, on the first plate: five plates to the right and back.
        text, period, present = run_once(serial, layer, a.moment)
        runs.append(gpu_jobs(slices(text), pid))
        presents.append(present)
    if a.package != HOME_PKG:
        adb(serial, "shell", f"am force-stop {a.package}")
    if not any(kind == "app" for run in runs for kind, *_ in run):
        sys.exit("no GPU completion waits for the app in the trace: did the app draw, is atrace allowed?")
    result = {"label": a.label, "device": a.device, "package": a.package, "lab": a.lab, "moment": a.moment,
              "time": time.strftime("%Y-%m-%d %H:%M"),
              "gpu": summarize(runs),
              "shown": measure_frames.summarize(period, presents),
              "jobs": [[[kind, round(q * 1000, 2), round(d * 1000, 2)] for kind, q, d in run] for run in runs]}
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, f"{a.label}.gpu.json")
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(result, handle, indent=2)
    g, s = result["gpu"], result["shown"]
    print(f"{a.label} ({a.device}, {a.package}, {a.moment}{', lab: ' + a.lab if a.lab is not None else ''})")
    print(f"app frames drawn {g.get('frames')}")
    for who in ("app", "surfaceflinger"):
        x = g[who]
        print(f"GPU {who:<15} alone {x.get('jobs', 0):>4}  p50/p90/max {x.get('p50_ms')}/{x.get('p90_ms')}/"
              f"{x.get('max_ms')} ms")
    print(f"GPU per frame (app + SurfaceFlinger, medians) {g.get('per_frame_ms')} ms, budget {BUDGET_MS:.1f} ms")
    print(f"shown: intervals {s.get('intervals')}, late {s.get('missed')} ({s.get('missed_pct')}%), "
          f"p50/p95/max {s.get('p50_ms')}/{s.get('p95_ms')}/{s.get('max_ms')} ms")
    print(f"saved {path}")


if __name__ == "__main__":
    main()
