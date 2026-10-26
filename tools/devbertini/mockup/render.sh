#!/bin/bash
# Copyright (C) 2026 Claudio Bertini (devBertini). GPL-3.0-or-later, like the rest of this project.
# Renders one mockup page to a 1920x1080 PNG (960x540 CSS px at device scale 2, the launcher's logical canvas) and
# prints the page's self-check (kit/check.js) read back through Chrome's --dump-dom.
#   render.sh <page.html (Windows path, C:/...)> <query, e.g. theme=light> <out.png (Windows path)> <profile dir>
# The profile dir is the caller's own (one per agent), so parallel renders never share a Chrome profile.
set -u
page="$1"; query="$2"; out="$3"; profile="$4"
chrome="C:/Program Files/Google/Chrome/Application/chrome.exe"
url="file:///${page}?${query}"
flags=(--headless=new --hide-scrollbars --allow-file-access-from-files --force-device-scale-factor=2
       --window-size=960,540 --virtual-time-budget=8000 --no-first-run --user-data-dir="$profile")
rm -f "$out"
"$chrome" "${flags[@]}" --screenshot="$out" "$url" >/dev/null 2>&1
python -I - "$out" <<'PY'
import struct, sys
path = sys.argv[1]
try:
    with open(path, "rb") as f:
        head = f.read(24)
    w, h = struct.unpack(">II", head[16:24])
    print("png %s %dx%d %s" % (path, w, h, "OK" if (w, h) == (1920, 1080) else "WRONG SIZE"))
except OSError as e:
    print("png missing: %s (%s)" % (path, e))
PY
"$chrome" "${flags[@]}" --dump-dom "${url}&check=1" 2>/dev/null | python -I -c "
import html, json, re, sys
dom = sys.stdin.read()
m = re.search(r'data-check=\"([^\"]*)\"', dom)
if not m:
    print('check: no report (is kit/check.js the last script of the page, and did the page load?)')
    sys.exit(0)
r = json.loads(html.unescape(m.group(1)))
problems = sum(len(r[k]) for k in ('fonts_failed', 'images_failed', 'small_text', 'overflow', 'outside', 'contrast_low'))
print('check: %s; texts %d, contrast min %s (skipped over images/gradients: %d)' % (
    'clean' if problems == 0 else '%d problem(s)' % problems, r['text_count'], r['contrast_min'], r['contrast_skipped']))
for k in ('fonts_failed', 'images_failed', 'small_text', 'overflow', 'outside', 'contrast_low'):
    for item in r[k]:
        print('  %s: %s' % (k, item))
"
