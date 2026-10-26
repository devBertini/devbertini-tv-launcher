"""HD card art for the apps on the home, drawn from the brands' vector logos.

The apps ship their TV banners at 320x180 (Netflix 480x270) and the card is 427x240 pixels on a 1920x1080
screen, so every banner is stretched. This draws each banner again at 960x540 from the brand's vector logo
(Wikimedia Commons), with the same background and logo size as the app's own banner, and a sheet that compares
both as the TV panel shows them (card size, then the TV's 2x scale to 4K).

    python -B tools/devbertini/hd_art.py build/devbertini-art/orig   (the original banners, <package>.png|webp,
                                                                    taken from the installed APKs)

Writes build/devbertini-art/<package>.png and build/devbertini-art/comparison.png. The logos are downloaded
once into build/devbertini-art/logos (never committed: they are the brands' marks).
"""
import json
import re
import pathlib
import subprocess
import sys
import time
import urllib.parse
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "build" / "devbertini-art"
LOGOS = OUT / "logos"
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
UA = "devBertini-launcher-art/1.0 (personal TV launcher)"
W, H = 960, 540
CARD = (427, 240)

# Package: Commons file, background (CSS), logo width as a share of the banner (measured on the app's own
# banner), and how the logo is coloured.
APPS = {
    "com.google.android.youtube.tv": dict(file="YouTube Logo 2017.svg", bg="#f5f5f5", width=0.719),
    "com.netflix.ninja": dict(file="Netflix 2015 logo.svg", bg="#ffffff", width=0.787, fill="#e50914"),
    "com.wbd.stream": dict(file="HBO Max (2025).svg", width=0.49, fill="url(#metal)",
                           bg="radial-gradient(ellipse at 50% 50%, #243040 0%, #0d121c 55%, #00040c 100%)"),
    "tv.twitch.android.app": dict(file="Twitch logo 2019.svg", bg="#9146ff", width=0.563,
                                  replace=(".cls-2{fill:#9146ff;}", ".cls-2{fill:#000000;}")),
    "com.amazon.amazonvideo.livingroom": dict(file="Prime Video logo (2024).svg", bg="#0578ff", width=0.669,
                                              fill="#ffffff"),
    "com.spotify.tv.android": dict(file="Spotify logo with text.svg", bg="#191414", width=0.825),
    "com.android.vending": dict(file="Google Play 2022 icon.svg", bg="#f5f5f5", width=None),
}

DETAIL = ("com.google.android.youtube.tv", "com.spotify.tv.android")

METAL = ('<defs><linearGradient id="metal" x1="0" y1="0" x2="0" y2="1">'
         '<stop offset="0" stop-color="#f6f4f8"/><stop offset="0.55" stop-color="#dcd7e0"/>'
         '<stop offset="1" stop-color="#b9b2bf"/></linearGradient></defs>')


def fetch(title):
    target = LOGOS / re.sub(r"[^\w.-]", "_", title)
    if target.exists():
        return target
    LOGOS.mkdir(parents=True, exist_ok=True)
    api = ("https://commons.wikimedia.org/w/api.php?action=query&format=json&prop=imageinfo&iiprop=url&titles="
           + urllib.parse.quote("File:" + title))
    for attempt in range(5):
        try:
            info = json.loads(get(api))["query"]["pages"]
            url = list(info.values())[0]["imageinfo"][0]["url"]
            target.write_bytes(get(url))
            time.sleep(2)
            return target
        except Exception as e:  # Commons answers 429 to quick requests
            print(f"  {title}: retry {attempt + 1} ({e})")
            time.sleep(5 * (attempt + 1))
    raise SystemExit(f"could not download {title}")


def get(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": UA}), timeout=30) as r:
        return r.read()


def logo_svg(spec):
    svg = fetch(spec["file"]).read_text(encoding="utf-8")
    svg = svg[svg.index("<svg"):]
    if "replace" in spec:
        svg = svg.replace(*spec["replace"])
    if "fill" in spec:
        # Every shape takes the one colour (or the metal gradient), whatever the file says.
        style = f"<style>path,polygon,rect,circle,ellipse{{fill:{spec['fill']} !important;}}</style>"
        svg = svg.replace(">", ">" + (METAL if "url(#metal)" in spec["fill"] else "") + style, 1)
    return svg


def page(package, spec):
    body = (f'<div class="logo" style="width:{spec["width"] * 100:.1f}%">{logo_svg(spec)}</div>'
            if spec["width"] else play_store(spec))
    return f"""<!doctype html><html><head><style>
html,body{{margin:0;width:{W}px;height:{H}px;overflow:hidden}}
body{{background:{spec['bg']};display:flex;align-items:center;justify-content:center}}
.logo svg{{width:100%;height:auto;display:block}}
</style></head><body>{body}</body></html>"""


def play_store(spec):
    # The Play Store banner: the icon, then "Google Play" over "Store" in grey, 73% of the width.
    return f"""<div style="display:flex;align-items:center;gap:{W * 0.05:.0f}px;white-space:nowrap">
<div style="width:{W * 0.21:.0f}px">{logo_svg(spec).replace('<svg ', '<svg style="width:100%;height:auto;display:block" ', 1)}</div>
<div style="font-family:'Google Sans','Product Sans','Century Gothic',sans-serif;color:#5f6368;
font-size:{H * 0.14:.0f}px;line-height:1.12;letter-spacing:-1px">Google Play<br>Store</div></div>"""


def shoot(html, png, size):
    html.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--allow-file-access-from-files",
                    "--virtual-time-budget=4000", f"--window-size={size[0]},{size[1]}", f"--screenshot={png}",
                    html.as_uri()], check=True, capture_output=True)


def comparison(originals):
    rows = []
    for package in APPS:
        orig = next((p for p in originals.glob(package + ".*")), None)
        if orig is None:
            continue
        row = f"""<div class="row"><canvas data-src="{orig.as_uri()}"></canvas>
<canvas data-src="{(OUT / (package + '.png')).as_uri()}"></canvas></div>"""
        rows.append(row)
        if package in DETAIL:
            # A 4x detail of the card's centre, pixels shown as they are, so the difference reads on a PC.
            rows.insert(len(rows) - 1, '<div class="note">Detalhe do centro do card, ampliado 4x</div>'
                        + row.replace('<canvas ', '<canvas data-detail="1" '))
    cw, ch = CARD[0] * 2, CARD[1] * 2
    html = OUT / "comparison.html"
    html.write_text(f"""<!doctype html><html><head><style>
body{{margin:0;background:#101014;font:28px 'Segoe UI',sans-serif;color:#eee;padding:24px;width:{cw * 2 + 72}px}}
.head{{display:flex;gap:24px;margin-bottom:16px}}.head div{{width:{cw}px}}
.row{{display:flex;gap:24px;margin-bottom:24px}}.note{{color:#aab;margin:8px 0 10px}}canvas{{width:{cw}px;height:{ch}px;border-radius:24px}}
</style></head><body><div class="head"><div>Hoje: imagem do app (320x180) no card</div><div>HD: 960x540 no card</div></div>
{''.join(rows)}
<script>
// As the TV shows it: drawn into the 427x240 card with cubic filtering, then scaled 2x by the TV to 4K.
document.querySelectorAll('canvas').forEach(c => {{
  const img = new Image();
  img.onload = () => {{
    const card = document.createElement('canvas'); card.width = {CARD[0]}; card.height = {CARD[1]};
    const g = card.getContext('2d'); g.imageSmoothingQuality = 'high'; g.drawImage(img, 0, 0, {CARD[0]}, {CARD[1]});
    c.width = {cw}; c.height = {ch};
    const t = c.getContext('2d');
    if (c.dataset.detail) {{
      t.imageSmoothingEnabled = false;
      t.drawImage(card, {CARD[0] * 3 // 8}, {CARD[1] * 3 // 8}, {CARD[0] // 4}, {CARD[1] // 4}, 0, 0, {cw}, {ch});
    }} else {{
      t.imageSmoothingQuality = 'medium'; t.drawImage(card, 0, 0, {cw}, {ch});
    }}
  }};
  img.src = c.dataset.src;
}});
</script></body></html>""", encoding="utf-8")
    height = 24 * 2 + 60 + len(rows) * (ch + 24) + 60 * len(DETAIL)
    shoot(html, OUT / "comparison.png", (cw * 2 + 72, height))


def main():
    originals = pathlib.Path(sys.argv[1])
    for package, spec in APPS.items():
        html = OUT / "html" / (package + ".html")
        html.parent.mkdir(parents=True, exist_ok=True)
        html.write_text(page(package, spec), encoding="utf-8")
        shoot(html, OUT / (package + ".png"), (W, H))
        print(f"{package}: {OUT / (package + '.png')}")
    comparison(originals)
    print(f"comparison: {OUT / 'comparison.png'}")


if __name__ == "__main__":
    main()
