#!/usr/bin/env python3
"""Generate app + menubar icons from LogoSource.png."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / "GrafanaScope" / "Resources"
SOURCE = RES / "LogoSource.png"


def is_background(r: int, g: int, b: int, a: int) -> bool:
    if a < 16:
        return True
    return r < 42 and g < 48 and b < 72


def fit_square(image: Image.Image, size: int) -> Image.Image:
    bbox = image.getbbox()
    if not bbox:
        return Image.new("RGBA", (size, size), (0, 0, 0, 0))

    cropped = image.crop(bbox)
    max_dim = max(cropped.size)
    square = Image.new("RGBA", (max_dim, max_dim), (0, 0, 0, 0))
    offset = ((max_dim - cropped.width) // 2, (max_dim - cropped.height) // 2)
    square.paste(cropped, offset)
    return square.resize((size, size), Image.Resampling.LANCZOS)


def app_icon(size: int) -> Image.Image:
    source = Image.open(SOURCE).convert("RGBA")
    return fit_square(source, size)


def menubar_template(size: int) -> Image.Image:
    source = Image.open(SOURCE).convert("RGBA")
    work_size = size * 16
    big = fit_square(source, work_size)

    silhouette = Image.new("RGBA", big.size, (0, 0, 0, 0))
    src_pixels = big.load()
    out_pixels = silhouette.load()

    for y in range(big.height):
        for x in range(big.width):
            r, g, b, a = src_pixels[x, y]
            if not is_background(r, g, b, a):
                out_pixels[x, y] = (0, 0, 0, 255)

    if size <= 18:
        silhouette = silhouette.filter(ImageFilter.MaxFilter(3))

    return fit_square(silhouette, size)


def draw_fallback_template(size: int) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    pad = size * 0.12
    bbox = [pad, pad, size - pad, size - pad]
    width = max(1, int(size * 0.08))
    draw.arc(bbox, start=55, end=205, fill=(0, 0, 0, 255), width=width)
    draw.arc(bbox, start=235, end=25, fill=(0, 0, 0, 255), width=width)

    bolt = [
        (size * 0.56, size * 0.14),
        (size * 0.38, size * 0.46),
        (size * 0.50, size * 0.46),
        (size * 0.40, size * 0.86),
        (size * 0.66, size * 0.54),
        (size * 0.52, size * 0.54),
    ]
    draw.polygon(bolt, fill=(0, 0, 0, 255))
    return img


def main() -> None:
    if not SOURCE.exists():
        raise SystemExit(f"Missing logo source: {SOURCE}")

    RES.mkdir(parents=True, exist_ok=True)

    app_icon(512).save(RES / "AppIcon.png")
    menubar_template(18).save(RES / "MenuBarIcon.png")
    menubar_template(36).save(RES / "MenuBarIcon@2x.png")

    print(f"Generated icons from {SOURCE.name} in {RES}")


if __name__ == "__main__":
    main()
