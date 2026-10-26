# Copyright (C) 2026 Claudio Bertini (devBertini). GPL-3.0-or-later, like the rest of this project.
"""Brand logo PNGs the Vitrine home draws (lib/devbertini/vitrine/logos.dart), rasterised from the brands' SVGs.

    python -B tools/devbertini/logo_art.py <svg folder> [<out folder>]

<svg folder> holds the brands' SVG logos, named as LOGOS below (never committed: they are the brands' marks).
Writes, per app package,
logo_light_<package>.png (for light surfaces and white plates) and logo_black_<package>.png (for black), on a
transparent background, trimmed of empty margins, each twice as tall as the largest height the home draws that logo
(the plate heights of docs/devbertini/DESIGN-VITRINE.md, "Apps"), as wide as the SVG's shape asks. A brand whose
mark reads on both surfaces has the light file only (the app falls back across variants). The default out folder is
build/devbertini-logos, which git ignores: the logos are the brands' marks, never committed. `deploy.ps1 -Art` puts
them on the device.

Chrome rasterises, like hd_art.py: one headless run per logo loads the SVG into a canvas, finds the drawn shape's
bounds on a large render, then draws the SVG again with its viewBox cut to those bounds at the final pixel size (a
vector render at that size, not a shrunk bitmap) and prints it as a PNG into the page, which --dump-dom hands back.
"""
import base64
import pathlib
import re
import struct
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "build" / "devbertini-logos"
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"

# Package: the height (logical px) the home draws its logo at on the plates, then the SVG for the light surfaces and
# the SVG for black (None when one mark reads on both).
LOGOS = {
    "com.netflix.ninja": (25, "netflix.svg", None),
    "com.google.android.youtube.tv": (21, "youtube.svg", "youtube-white.svg"),
    "com.wbd.stream": (37, "hbomax.svg", "hbomax-white.svg"),
    "com.amazon.amazonvideo.livingroom": (26, "prime.svg", None),
    "tv.twitch.android.app": (25, "twitch-purple.svg", "twitch.svg"),
    "com.spotify.tv.android": (26, "spotify.svg", None),
    "com.android.vending": (34, "play.svg", None),
}
SCALE = 2  # the TV's device pixel ratio
PROBE = 2400  # longest side, in pixels, of the render that finds the shape's bounds

PAGE = """<!doctype html><html><head><meta charset="utf-8"></head><body><pre id="out">pending</pre><script>
const svgText = atob("%(svg)s"), H = %(height)d, PROBE = %(probe)d;
const doc = new DOMParser().parseFromString(svgText, "image/svg+xml");
const root = doc.documentElement;
if (root.localName !== "svg") throw new Error("not an svg");
const vb = (root.getAttribute("viewBox") || "").trim().split(/[\\s,]+/).map(Number);
if (vb.length !== 4 || vb.some(isNaN)) { document.getElementById("out").textContent = "error: no viewBox"; }
else {
  const toImage = (s) => new Promise((ok, no) => {
    const img = new Image(); img.onload = () => ok(img); img.onerror = () => no(new Error("svg did not load"));
    img.src = "data:image/svg+xml;base64," + btoa(unescape(encodeURIComponent(s)));
  });
  const withBox = (x, y, w, h, pw, ph) => {
    root.setAttribute("viewBox", x + " " + y + " " + w + " " + h);
    root.setAttribute("width", pw); root.setAttribute("height", ph);
    root.setAttribute("preserveAspectRatio", "none");
    return new XMLSerializer().serializeToString(root);
  };
  (async () => {
    const k = PROBE / Math.max(vb[2], vb[3]);
    const pw = Math.max(1, Math.round(vb[2] * k)), ph = Math.max(1, Math.round(vb[3] * k));
    const big = await toImage(withBox(vb[0], vb[1], vb[2], vb[3], pw, ph));
    const c = document.createElement("canvas"); c.width = pw; c.height = ph;
    const g = c.getContext("2d", { willReadFrequently: true }); g.drawImage(big, 0, 0, pw, ph);
    const px = g.getImageData(0, 0, pw, ph).data;
    let x0 = pw, y0 = ph, x1 = -1, y1 = -1;
    for (let y = 0; y < ph; y++) for (let x = 0; x < pw; x++) {
      if (px[(y * pw + x) * 4 + 3] > 8) { if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y; }
    }
    if (x1 < 0) { document.getElementById("out").textContent = "error: nothing drawn"; return; }
    x1 += 1; y1 += 1;
    const bx = vb[0] + x0 / k, by = vb[1] + y0 / k, bw = (x1 - x0) / k, bh = (y1 - y0) / k;
    const W = Math.max(1, Math.round(H * bw / bh));
    const small = await toImage(withBox(bx, by, bw, bh, W, H));
    const o = document.createElement("canvas"); o.width = W; o.height = H;
    o.getContext("2d").drawImage(small, 0, 0, W, H);
    document.getElementById("out").textContent = o.toDataURL("image/png");
  })().catch((e) => { document.getElementById("out").textContent = "error: " + e.message; });
}
</script></body></html>"""


def raster(svg_path, height, workdir):
    """The PNG bytes of [svg_path], [height] px tall, trimmed, transparent."""
    page = workdir / (svg_path.stem + ".html")
    page.write_text(PAGE % dict(svg=base64.b64encode(svg_path.read_bytes()).decode("ascii"),
                                height=height, probe=PROBE), encoding="utf-8")
    run = subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
                          "--virtual-time-budget=10000", "--dump-dom", page.as_uri()],
                         capture_output=True, timeout=120)
    dom = run.stdout.decode("utf-8", "replace")
    found = re.search(r'<pre id="out">(.*?)</pre>', dom, re.S)
    text = found.group(1).strip() if found else ""
    if not text.startswith("data:image/png;base64,"):
        raise SystemExit(f"{svg_path.name}: Chrome gave no PNG ({text[:120] or run.stderr.decode()[-200:]})")
    return base64.b64decode(text.split(",", 1)[1])


def size(png):
    return struct.unpack(">II", png[16:24])


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    svgs = pathlib.Path(sys.argv[1])
    out = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else OUT
    out.mkdir(parents=True, exist_ok=True)
    for old in out.glob("logo_*.png"):
        old.unlink()  # a variant dropped from the table must not stay behind
    rows = []
    with tempfile.TemporaryDirectory() as tmp:
        work = pathlib.Path(tmp)
        for package, (plate, light, black) in LOGOS.items():
            for variant, name in (("light", light), ("black", black)):
                if name is None:
                    continue
                source = svgs / name
                if not source.is_file():
                    raise SystemExit(f"missing {source}")
                png = raster(source, plate * SCALE, work)
                target = out / f"logo_{variant}_{package}.png"
                target.write_bytes(png)
                width, height = size(png)
                rows.append((target.name, width, height, plate * SCALE))
    name_width = max(len(r[0]) for r in rows)
    print(f"{'file'.ljust(name_width)}  width x height  (plate x2)")
    for name, width, height, want in rows:
        print(f"{name.ljust(name_width)}  {width:>5} x {height:<5}  {want}{'' if height == want else '  MISMATCH'}")
    print(f"{len(rows)} files in {out}")


if __name__ == "__main__":
    main()
