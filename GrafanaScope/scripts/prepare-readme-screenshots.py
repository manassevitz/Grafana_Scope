#!/usr/bin/env python3
"""Process real README screenshots (crop, menubar hero, fix alerts banner)."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "docs" / "screenshots" / "source"
OUT = ROOT / "docs" / "screenshots"
MENU_ICON = ROOT / "GrafanaScope" / "GrafanaScope" / "Resources" / "MenuBarIcon@2x.png"

REQUIRED = [
    "source-alerts.png",
    "source-settings-general.png",
    "source-settings-instances.png",
    "source-settings-add.png",
]

OPTIONAL = [
    "source-menubar.png",
    "source-settings-menu.png",
]


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf",
    ]
    for path in candidates:
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()


def copy(name: str, dest: str) -> None:
    src = SRC / name
    Image.open(src).convert("RGB").save(OUT / dest)
    print(f"  {name} → {dest}")


def fix_alerts_banner(img: Image.Image) -> Image.Image:
    """Replace red 'Error fetching instances' with green ok message."""
    img = img.convert("RGB")
    draw = ImageDraw.Draw(img)
    w, h = img.size

    # Banner under header; cover any red error text completely.
    banner_top = 48
    banner_bottom = 74
    bg = img.getpixel((14, 42))
    draw.rectangle((0, banner_top, w, banner_bottom), fill=bg)

    draw.text(
        (14, banner_top + 6),
        "No active alerts across any instance",
        fill=(48, 209, 88),
        font=font(13, bold=True),
    )
    return img


def crop_alerts_panel(path: Path) -> Image.Image:
    img = Image.open(path).convert("RGB")
    if img.width <= 420:
        return fix_alerts_banner(img)
    top = min(32, img.height // 12)
    cropped = img.crop((0, top, img.width, img.height))
    return fix_alerts_banner(cropped)


def make_menubar_hero() -> None:
    optional = SRC / "source-menubar.png"
    if optional.exists():
        Image.open(optional).convert("RGBA").save(OUT / "menubar-hero.png")
        print("  source-menubar.png → menubar-hero.png")
        return

    bar = Image.new("RGBA", (240, 34), (24, 24, 26, 255))
    if MENU_ICON.exists():
        icon = Image.open(MENU_ICON).convert("RGBA")
        icon = icon.resize((18, 18), Image.Resampling.LANCZOS)
        bar.paste(icon, (200, 8), icon)
    bar.save(OUT / "menubar-hero.png")
    print("  MenuBarIcon → menubar-hero.png")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    SRC.mkdir(parents=True, exist_ok=True)

    missing = [name for name in REQUIRED if not (SRC / name).exists()]
    if missing:
        print("Missing captures in docs/screenshots/source/:\n")
        for name in missing:
            print(f"  - {name}")
        raise SystemExit(1)

    print("Processing screenshots:")
    crop_alerts_panel(SRC / "source-alerts.png").save(OUT / "alerts.png")
    print("  source-alerts.png → alerts.png (banner fixed)")

    copy("source-settings-general.png", "settings-general.png")
    copy("source-settings-instances.png", "settings-instances.png")
    copy("source-settings-add.png", "settings-add-instance.png")

    menu = SRC / "source-settings-menu.png"
    if menu.exists():
        copy("source-settings-menu.png", "settings-menu.png")
    elif (OUT / "settings-menu.png").exists():
        print("  settings-menu.png (unchanged)")
    else:
        print("  settings-menu.png skipped (optional capture missing)")

    make_menubar_hero()
    print(f"\nDone. Output: {OUT}")


if __name__ == "__main__":
    main()
