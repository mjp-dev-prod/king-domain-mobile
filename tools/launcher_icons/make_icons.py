"""Regenerates the Android launcher icons for both flavors from the brand mark.

    python tools/launcher_icons/make_icons.py

The mark text comes from AppBrand.mark (lib/core/constants/app_brand.dart), so a rename only needs
that constant changed and this script re-run. Needs Chrome (set CHROME if it is not in the usual
place) and Pillow. Production: gold mark on the brand Ground. Staging: off-white on violet, so
KD Staging is never mistaken for the real app. Colours: CLAUDE.md "Brand v1".

Writes android/app/src/main/res (production) and android/app/src/staging/res (staging):
mipmap-*/ic_launcher.png (legacy) and mipmap-*/ic_launcher_foreground.png (adaptive layer).
test/launcher_icon_test.dart checks the result.
"""
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from urllib.parse import quote

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
LEGACY = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
FOREGROUND = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}

VARIANTS = {
    # name: (background, mark colour, resource root)
    "production": ("#0D0A16", "#F2C14E", ROOT / "android/app/src/main/res"),
    "staging": ("#7451F2", "#F2EFFA", ROOT / "android/app/src/staging/res"),
}


def chrome_path() -> str:
    for p in (os.environ.get("CHROME"), r"C:\Program Files\Google\Chrome\Application\chrome.exe",
              r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
              "/usr/bin/google-chrome", "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"):
        if p and Path(p).exists():
            return p
    sys.exit("Chrome not found: set the CHROME environment variable.")


def brand_mark() -> str:
    text = (ROOT / "lib/core/constants/app_brand.dart").read_text(encoding="utf-8")
    m = re.search(r"static const String mark = '([^']+)'", text)
    if not m:
        sys.exit("AppBrand.mark not found in lib/core/constants/app_brand.dart")
    return m.group(1)


def render(out: Path, bg: str, fg: str, ratio: float, mark: str) -> None:
    query = f"bg={quote(bg) if bg != 'none' else 'none'}&fg={quote(fg)}&ratio={ratio}&mark={quote(mark)}"
    subprocess.run([
        chrome_path(), "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
        "--default-background-color=00000000", "--virtual-time-budget=20000", "--window-size=1024,1024",
        f"--screenshot={out}", (HERE / "render.html").as_uri() + "?" + query,
    ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main() -> None:
    mark = brand_mark()
    with tempfile.TemporaryDirectory() as tmp:
        for name, (bg, fg, root) in VARIANTS.items():
            legacy, adaptive = Path(tmp) / f"{name}_legacy.png", Path(tmp) / f"{name}_fg.png"
            render(legacy, bg, fg, 0.58, mark)
            render(adaptive, "none", fg, 0.50, mark)
            for density, px in LEGACY.items():
                d = root / f"mipmap-{density}"
                d.mkdir(parents=True, exist_ok=True)
                Image.open(legacy).convert("RGB").resize((px, px), Image.LANCZOS).save(d / "ic_launcher.png", optimize=True)
            for density, px in FOREGROUND.items():
                d = root / f"mipmap-{density}"
                d.mkdir(parents=True, exist_ok=True)
                Image.open(adaptive).convert("RGBA").resize((px, px), Image.LANCZOS).save(d / "ic_launcher_foreground.png", optimize=True)
            print(f"{name}: wrote {len(LEGACY) + len(FOREGROUND)} icons to {root.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
