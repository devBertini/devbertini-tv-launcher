# Copyright (C) 2026 Claudio Bertini (devBertini). GPL-3.0-or-later, like the rest of this project.
"""Where the tools find what is specific to one machine: the adb path and the names of the TV devices.

Both come from tools/devbertini/local.json (never versioned; local.example.json shows its shape):

    adb      the adb executable; the environment variable ADB wins over it; without either, `adb` on PATH
    devices  {"<name>": {"serial": "<adb serial>", ...}}; without the file there are no names, and a device is
             given as ip:port or as its serial

measure_frames.py, frame_log.py, gpu_trace.py and return_video.py read it through this module; deploy.ps1 and its
siblings read the same file through local_config.ps1.
"""
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
LOCAL_JSON = os.path.join(HERE, "local.json")
# A serial as adb lists it: letters and digits, at least eight, at least one digit (a plain word is a typo).
SERIAL = re.compile(r"(?=.*\d)[A-Za-z0-9]{8,}")


def load(path=None):
    """The configuration of `path` (local.json beside this file by default); {} when the file does not exist."""
    path = path or LOCAL_JSON
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except FileNotFoundError:
        return {}
    except json.JSONDecodeError as error:
        raise ValueError(f"{path} is not valid JSON: {error}") from error
    if not isinstance(data, dict):
        raise ValueError(f"{path} must hold a JSON object")
    return data


def adb_path(env=None, config=None):
    """The adb executable: the environment's ADB, else the file's `adb`, else `adb` (found on PATH)."""
    env = os.environ if env is None else env
    if env.get("ADB"):
        return env["ADB"]
    config = load() if config is None else config
    return config.get("adb") or "adb"


def devices(config=None):
    """{name: serial} of the file's `devices`; empty without the file or the key."""
    config = load() if config is None else config
    known = {}
    for name, entry in (config.get("devices") or {}).items():
        serial = entry.get("serial") if isinstance(entry, dict) else entry
        if serial:
            known[name] = str(serial)
    return known


def serial_for(device, config=None):
    """The serial of a named device, a serial given as it is, or None when `device` is neither."""
    known = devices(config)
    if device in known:
        return known[device]
    if SERIAL.fullmatch(device):
        return device
    return None


def unknown_device(device, config=None):
    """The message for a device that is not a known name, a serial or ip:port."""
    names = ", ".join(devices(config))
    if names:
        return f"unknown device {device!r} ({names}, a serial or ip:port)"
    return f"unknown device {device!r} (give ip:port or a serial; names come from tools/devbertini/local.json)"
