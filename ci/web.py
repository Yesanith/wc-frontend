#!/usr/bin/env python3
"""Sets up the web build of the app: the page's title, colours and icons, and what
iOS needs to add it to the home screen and run it like an app. Run after
`flutter create --platforms=web .`, from the repository root."""
import json
import re
import sys
from pathlib import Path

WEB = Path("web")
BG = "#0D0B09"   # the app's background, warm black
GOLD = "#DFC295"  # its accent
NAME = "Tyria Codex"
DESCRIPTION = "An unofficial Guild Wars 2 companion: characters, wallet, trading post, crafting, world bosses, a world map and guild events."
ICON = Path("ci/launcher/play_store_512.png")


def patch_index(html: str) -> str:
    # the title and the description
    html = re.sub(r"<title>.*?</title>", f"<title>{NAME}</title>", html, count=1, flags=re.S)
    html = re.sub(r'(<meta name="description" content=")[^"]*(")', rf"\g<1>{DESCRIPTION}\g<2>", html, count=1)
    # a phone shows the page edge to edge, and the colours of the app instead of white
    extra = f"""
  <meta name="theme-color" content="{BG}">
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
  <meta name="apple-mobile-web-app-title" content="{NAME}">
  <link rel="apple-touch-icon" href="icons/Icon-192.png">
  <style>
    html, body {{ background: {BG}; margin: 0; height: 100%; }}
    #loading {{ position: fixed; inset: 0; display: flex; flex-direction: column; align-items: center;
      justify-content: center; gap: 16px; color: {GOLD}; font: 600 15px system-ui, sans-serif; }}
    #loading img {{ width: 96px; height: 96px; border-radius: 22px; }}
    #loading .bar {{ width: 120px; height: 3px; background: #2a2620; border-radius: 2px; overflow: hidden; }}
    #loading .bar::after {{ content: ""; display: block; width: 40%; height: 100%; background: {GOLD};
      animation: slide 1.1s ease-in-out infinite; }}
    @keyframes slide {{ from {{ margin-left: -40%; }} to {{ margin-left: 100%; }} }}
  </style>
"""
    if 'name="theme-color"' not in html:
        # the template writes some of these itself, with values of its own: ours replace them
        html = re.sub(
            r'\s*<meta name="(?:apple-mobile-web-app-capable|apple-mobile-web-app-status-bar-style|apple-mobile-web-app-title)"[^>]*>',
            "",
            html,
        )
        html = re.sub(r'\s*<link rel="apple-touch-icon"[^>]*>', "", html)
        html = html.replace("</head>", extra + "</head>", 1)
    # what shows while the engine loads, taken away once the app draws its first frame
    if 'id="loading"' not in html:
        html = html.replace(
            "<body>",
            f'<body>\n  <div id="loading"><img src="icons/Icon-192.png" alt=""><div>{NAME}</div><div class="bar"></div></div>',
            1,
        )
        html = html.replace(
            "</body>",
            "  <script>window.addEventListener('flutter-first-frame', function () {"
            " var l = document.getElementById('loading'); if (l) l.remove(); });</script>\n</body>",
            1,
        )
    return html


def patch_manifest(data: dict) -> dict:
    data.update({
        "name": NAME,
        "short_name": NAME,
        "description": DESCRIPTION,
        "background_color": BG,
        "theme_color": BG,
        "display": "standalone",
        "orientation": "portrait-primary",
        "start_url": ".",
        "scope": ".",
    })
    return data


def make_icons() -> None:
    from PIL import Image

    source = Image.open(ICON).convert("RGBA")
    icons = WEB / "icons"
    icons.mkdir(parents=True, exist_ok=True)
    for name, size, pad in [
        ("Icon-192.png", 192, 0), ("Icon-512.png", 512, 0),
        ("Icon-maskable-192.png", 192, 0.2), ("Icon-maskable-512.png", 512, 0.2),
    ]:
        inner = round(size * (1 - pad))
        picture = source.resize((inner, inner), Image.LANCZOS)
        if pad:
            # a maskable icon keeps its picture inside the safe zone, on the app's own background
            canvas = Image.new("RGBA", (size, size), BG)
            canvas.paste(picture, ((size - inner) // 2, (size - inner) // 2), picture)
            picture = canvas
        picture.save(icons / name)
    source.resize((48, 48), Image.LANCZOS).save(WEB / "favicon.png")


def main() -> int:
    if not (WEB / "index.html").exists():
        print("run flutter create --platforms=web . first", file=sys.stderr)
        return 1
    index = WEB / "index.html"
    index.write_text(patch_index(index.read_text()))
    manifest = WEB / "manifest.json"
    manifest.write_text(json.dumps(patch_manifest(json.loads(manifest.read_text())), indent=2, ensure_ascii=False))
    make_icons()
    print("web build set up")
    return 0


if __name__ == "__main__":
    sys.exit(main())
