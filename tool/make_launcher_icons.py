#!/usr/bin/env python3
"""Renders the legacy launcher icons (Android 7.x, API 24-25) of every brand.

From Android 8 the launcher uses the adaptive icon XML. Older versions need
bitmaps, and this draws them from the SAME glyph path as the adaptive icon
(`ic_launcher_foreground.xml`, read from the project), so the two cannot drift
apart. Colours come from `ic_launcher_colors.xml` next to it.

    python3 tool/make_launcher_icons.py

It reads the brand ids from android/brands.json and needs ImageMagick (`magick`)
on the PATH. It is a development tool: the PNGs are committed, and no build step
runs it. The standard library is all it imports.
"""

import json
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ANDROID_NS = "{http://schemas.android.com/apk/res/android}"
SIZES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
SUPERSAMPLE = 4  # drawn four times larger, then scaled down, for smooth edges
VIEWPORT = 108  # the adaptive icon's canvas, in dp
SPAN = 80  # how many of those units fill a legacy tile: the glyph is a little larger than in the adaptive icon
CORNER = 0.18  # corner radius of the square legacy icon, as a share of its side


def colours(res: Path) -> dict[str, str]:
    root = ET.parse(res / "values" / "ic_launcher_colors.xml").getroot()
    return {c.get("name"): c.text.strip() for c in root.iter("color")}


def resolve(value: str | None, palette: dict[str, str]) -> str:
    if value is None:
        return "none"
    if value.startswith("@color/"):
        return palette[value.removeprefix("@color/")]
    return value


def glyph_paths(res: Path, palette: dict[str, str]) -> list[dict[str, str]]:
    root = ET.parse(res / "drawable" / "ic_launcher_foreground.xml").getroot()
    return [
        {
            "d": p.get(ANDROID_NS + "pathData"),
            "fill": resolve(p.get(ANDROID_NS + "fillColor"), palette),
            "stroke": resolve(p.get(ANDROID_NS + "strokeColor"), palette),
            "width": p.get(ANDROID_NS + "strokeWidth", "0"),
        }
        for p in root.iter("path")
    ]


def render(
    out: Path, size: int, shape: str, background: str, paths: list[dict[str, str]]
) -> None:
    n = size * SUPERSAMPLE
    scale = n / SPAN
    offset = (n - VIEWPORT * scale) / 2
    if shape == "round":
        tile = f"circle {n / 2},{n / 2} {n / 2},0.5"
    else:
        tile = f"roundrectangle 0.5,0.5 {n - 0.5},{n - 0.5} {CORNER * n},{CORNER * n}"
    command = [
        "magick", "-size", f"{n}x{n}", "xc:none",
        "-fill", background, "-stroke", "none", "-draw", tile,
    ]
    for path in paths:
        command += [
            "-fill", path["fill"], "-stroke", path["stroke"],
            "-strokewidth", path["width"],
            "-draw",
            f"stroke-linecap round translate {offset},{offset} scale {scale},{scale} path '{path['d']}'",
        ]
    command += ["-filter", "Lanczos", "-resize", f"{size}x{size}", "-strip", f"PNG32:{out}"]
    subprocess.run(command, check=True)


def main() -> int:
    brands = json.loads((ROOT / "android" / "brands.json").read_text())
    for brand in brands:
        res = ROOT / "android" / "app" / "src" / brand["id"] / "res"
        palette = colours(res)
        paths = glyph_paths(res, palette)
        for density, size in SIZES.items():
            folder = res / f"mipmap-{density}"
            folder.mkdir(parents=True, exist_ok=True)
            for shape, name in (("square", "ic_launcher.png"), ("round", "ic_launcher_round.png")):
                render(folder / name, size, shape, palette["ic_launcher_background"], paths)
        print(f"{brand['id']}: {len(SIZES) * 2} legacy icons")
    return 0


if __name__ == "__main__":
    sys.exit(main())
