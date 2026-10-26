#!/usr/bin/env python3
"""Shows, frame by frame, what the TV shows when Home is pressed inside an app: whether the home comes back whole or
is drawn again from black (docs/devbertini/PERFORMANCE.md).

    python -B tools/devbertini/return_video.py --device <name>|<serial>|ip:port [--stay 8] [--out build/devbertini-return]

From the home, with the focus on an app's plate, it opens that app (OK), waits --stay seconds, records the screen as
raw frames (`screenrecord --output-format=frames`, 480x270, one frame per change of the screen) while it presses
Home, pulls them and writes each one as a PNG into --out, and prints for each frame its mean brightness and how far it
is from the last one (the settled home): a home that comes back whole goes from the app's frames to 0.0 at once.
Also says whether the launcher's process survived. Refuses to start unless the home is in front.
"""
import argparse
import importlib.util
import os
import struct
import subprocess
import sys
import time
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("measure_frames", os.path.join(HERE, "measure_frames.py"))
measure_frames = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(measure_frames)
# The adb path and the device names come from local.json (local_config.py), not from this file.
_cfg_spec = importlib.util.spec_from_file_location("local_config", os.path.join(HERE, "local_config.py"))
local_config = importlib.util.module_from_spec(_cfg_spec)
_cfg_spec.loader.exec_module(local_config)

ADB = local_config.adb_path()
PKG = measure_frames.PKG
W, H = 480, 270
SIZE = W * H * 3


def parse_frames(data):
    """The RGB frames of a `screenrecord --output-format=frames` file: each is a u32 length of what follows, u32
    width, u32 height, an 8-byte field, then the pixels."""
    frames, pos = [], 0
    while pos + 20 + SIZE <= len(data):
        length, width, height = struct.unpack("<III", data[pos:pos + 12])
        if (width, height) != (W, H) or length != 16 + SIZE:
            raise ValueError(f"unexpected frame header at byte {pos}: {length} {width}x{height}")
        frames.append(data[pos + 20:pos + 20 + SIZE])
        pos += 4 + length
    return frames


def distance(a, b, step=97):
    """Mean absolute difference of a sample of the two frames' bytes (0 when equal)."""
    sample = range(0, SIZE, step)
    return sum(abs(a[k] - b[k]) for k in sample) / len(sample)


def brightness(frame, step=97):
    sample = range(0, SIZE, step)
    return sum(frame[k] for k in sample) / len(sample)


def write_png(path, rgb):
    raw = b"".join(b"\x00" + rgb[y * W * 3:(y + 1) * W * 3] for y in range(H))

    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)

    with open(path, "wb") as handle:
        handle.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0))
                     + chunk(b"IDAT", zlib.compress(raw, 1)) + chunk(b"IEND", b""))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--device", default="tcl")
    ap.add_argument("--stay", type=float, default=8)
    ap.add_argument("--out", default=os.path.join(os.path.dirname(os.path.dirname(HERE)), "build", "devbertini-return"))
    a = ap.parse_args()
    serial = measure_frames.resolve(a.device)

    def sh(command):
        return measure_frames.shell(serial, command)

    if measure_frames.focused_package(sh("dumpsys window | grep mCurrentFocus")) != PKG:
        sys.exit("the home is not in front: open it, with the focus on an app's plate")
    pid_before = sh(f"pidof {PKG}").strip()
    sh("input keyevent KEYCODE_DPAD_CENTER")
    time.sleep(a.stay)
    print("in the app:", measure_frames.focused_package(sh("dumpsys window | grep mCurrentFocus")))
    sh("rm -f /sdcard/devbertini_return.raw")
    recorder = subprocess.Popen([ADB, "-s", serial, "shell",
                                 f"screenrecord --output-format=frames --size {W}x{H} /sdcard/devbertini_return.raw"],
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(1.0)
    sh("input keyevent KEYCODE_HOME")
    time.sleep(3.0)
    sh("pkill -INT screenrecord")
    recorder.wait(timeout=20)
    print("launcher process before/after:", pid_before, sh(f"pidof {PKG}").strip())
    os.makedirs(a.out, exist_ok=True)
    raw_path = os.path.join(a.out, "return.raw")
    subprocess.run([ADB, "-s", serial, "pull", "/sdcard/devbertini_return.raw", raw_path], capture_output=True)
    sh("rm -f /sdcard/devbertini_return.raw")
    with open(raw_path, "rb") as handle:
        frames = parse_frames(handle.read())
    os.remove(raw_path)
    if not frames:
        sys.exit("no frames recorded")
    settled = frames[-1]
    for i, frame in enumerate(frames):
        write_png(os.path.join(a.out, f"f{i:03d}.png"), frame)
        print(f"f{i:03d}  brightness {brightness(frame):5.1f}  from the settled home {distance(frame, settled):5.1f}")
    print(f"{len(frames)} frames in {a.out}")


if __name__ == "__main__":
    main()
