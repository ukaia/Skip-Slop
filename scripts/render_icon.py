#!/usr/bin/env python3
"""Renders the Skip Slop app icon: an inspection placard taped crooked in a
window, graded A, with ketchup dripping off the A.

Writes 1024x1024 light, dark and tinted PNGs into the AppIcon asset catalog,
previews (plus a small-size grid) into ~/skipslop-icon, and an Icon Composer
bundle (~/skipslop-icon/AppIcon.icon) with separate background and placard layers.

Usage:  python3 scripts/render_icon.py
Needs:  Pillow, macOS (SF Pro Rounded from /System/Library/Fonts).
"""

import json
import shutil
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
APPICON = ROOT / "Skip Slop" / "Assets.xcassets" / "AppIcon.appiconset"
PREVIEWS = Path.home() / "skipslop-icon"
FONT = "/System/Library/Fonts/SFNSRounded.ttf"

S = 4096          # supersampled canvas
OUT = 1024
K = S / 1024      # scale from 1024-point design units

KETCHUP = (229, 72, 61)
KETCHUP_DEEP = (176, 38, 32)
PAPER = (255, 244, 220)
INK = (28, 22, 18)
MUSTARD = (255, 201, 60)
TAPE = (236, 214, 160)


def u(v):
    return int(round(v * K))


def font(size):
    f = ImageFont.truetype(FONT, u(size))
    f.set_variation_by_name("Black")
    return f


def background(top, bottom):
    """Vertical gradient, full bleed (iOS masks the corners)."""
    grad = Image.new("RGB", (1, 256))
    for y in range(256):
        t = y / 255
        grad.putpixel((0, y), tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return grad.resize((S, S), Image.BICUBIC).convert("RGBA")


def placard_layer(card, rule, letter, drip, tape, shadow_alpha):
    """The tilted placard with tape, letter and drip, on a transparent canvas."""
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    w, h = 620, 700
    x0, y0 = (1024 - w) / 2, (1024 - h) / 2 + 30

    card_img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(card_img)
    d.rounded_rectangle([u(x0), u(y0), u(x0 + w), u(y0 + h)], radius=u(70), fill=card)
    inset = 34
    d.rounded_rectangle([u(x0 + inset), u(y0 + inset), u(x0 + w - inset), u(y0 + h - inset)],
                        radius=u(44), outline=rule, width=u(18))

    # The grade.
    f = font(560)
    cx, cy = 512, y0 + h / 2 + 12
    d.text((u(cx), u(cy)), "A", font=f, fill=letter, anchor="mm")

    # Ketchup splatted across the crossbar and running down: an irregular
    # blob (overlapping circles) with drips of different lengths.
    if drip:
        bar_y = cy + 70

        def circle(x, y, r):
            d.ellipse([u(x - r), u(y - r), u(x + r), u(y + r)], fill=drip)

        for (dx, dy, r) in ((-96, 6, 34), (-56, -10, 44), (-8, -4, 42), (38, 4, 36), (74, 12, 26),
                            (-128, 18, 20), (-30, 22, 40), (20, 20, 34)):
            circle(cx + dx, bar_y + dy, r)
        for (dx, length, width) in ((-74, 168, 40), (8, 104, 32), (60, 62, 24)):
            top = bar_y + 18
            d.rounded_rectangle([u(cx + dx - width / 2), u(top), u(cx + dx + width / 2), u(top + length)],
                                radius=u(width / 2), fill=drip)
            # A heavier bead at the end of each drip.
            circle(cx + dx, top + length - width * 0.2, width * 0.56)

    card_img = card_img.rotate(-7, resample=Image.BICUBIC, center=(S / 2, S / 2))

    if shadow_alpha:
        alpha = card_img.split()[3].point(lambda a: int(a * shadow_alpha))
        shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        shadow.putalpha(alpha)
        shadow = ImageChops.offset(shadow, 0, u(22)).filter(ImageFilter.GaussianBlur(u(26)))
        layer = Image.alpha_composite(layer, shadow)
    layer = Image.alpha_composite(layer, card_img)

    # Masking tape across the top edge, at its own angle.
    if tape:
        t = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        td = ImageDraw.Draw(t)
        tw, th = 300, 92
        tx, ty = 512 - tw / 2, y0 - th / 2 + 6
        # Tape strip with jagged, torn ends.
        teeth = 7
        left = [(tx + (10 if i % 2 else 0), ty + i * th / teeth) for i in range(teeth + 1)]
        right = [(tx + tw - (10 if i % 2 else 0), ty + i * th / teeth) for i in range(teeth + 1)]
        outline = [(x, y) for x, y in right] + [(x, y) for x, y in reversed(left)]
        td.polygon([(u(x), u(y)) for x, y in outline], fill=tape)
        t = t.rotate(4, resample=Image.BICUBIC, center=(S / 2, u(ty + th / 2)))
        layer = Image.alpha_composite(layer, t)
    return layer


def render(variant):
    if variant == "light":
        bg = background(KETCHUP, KETCHUP_DEEP)
        fg = placard_layer(PAPER + (255,), INK + (90,), INK + (255,), KETCHUP + (255,), TAPE + (235,), 0.55)
    elif variant == "dark":
        bg = background((44, 34, 28), (20, 15, 12))
        fg = placard_layer(MUSTARD + (255,), INK + (110,), INK + (255,), KETCHUP + (255,), PAPER + (215,), 0.7)
    else:  # tinted: iOS tints by luminance, so grayscale on black
        bg = background((0, 0, 0), (0, 0, 0))
        fg = placard_layer((236, 236, 236, 255), (0, 0, 0, 110), (0, 0, 0, 255), (90, 90, 90, 255), (180, 180, 180, 200), 0)
    img = Image.alpha_composite(bg, fg)
    return img.convert("RGB").resize((OUT, OUT), Image.LANCZOS), bg, fg


def rounded_mask(size, radius):
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    return m


def grid(images):
    """Small-size mock: each variant at 180, 120, 87, 60, 40 and 29 px, on light and dark wallpapers."""
    sizes = [180, 120, 87, 60, 40, 29]
    pad = 28
    row_h = max(sizes) + pad * 2
    width = pad + sum(s + pad for s in sizes)
    sheet = Image.new("RGB", (width, row_h * 6), (255, 255, 255))
    for r, (name, img) in enumerate(images.items()):
        for bgc_i, bgc in enumerate(((242, 242, 247), (28, 28, 30))):
            row = r * 2 + bgc_i
            ImageDraw.Draw(sheet).rectangle([0, row * row_h, width, (row + 1) * row_h], fill=bgc)
            x = pad
            for s in sizes:
                icon = img.resize((s, s), Image.LANCZOS)
                y = row * row_h + (row_h - s) // 2
                sheet.paste(icon, (x, y), rounded_mask(s, int(s * 0.2237)))
                x += s + pad
    return sheet


def icon_composer_bundle(bg, fg, dest):
    """Icon Composer (.icon) bundle: a solid background fill and the placard as a glass layer."""
    if dest.exists():
        shutil.rmtree(dest)
    (dest / "Assets").mkdir(parents=True)
    fg.resize((OUT, OUT), Image.LANCZOS).save(dest / "Assets" / "placard.png")
    manifest = {
        "fill": {"linear-gradient": ["srgb:0.89804,0.28235,0.23922,1.00000", "srgb:0.69020,0.14902,0.12549,1.00000"]},
        "groups": [{
            "layers": [{"image-name": "placard.png", "name": "placard", "glass": True}],
            "shadow": {"kind": "layer-color", "opacity": 0.5},
            "translucency": {"enabled": False, "value": 0.2},
        }],
        "supported-platforms": {"squares": "shared"},
    }
    (dest / "icon.json").write_text(json.dumps(manifest, indent=2) + "\n")


def main():
    PREVIEWS.mkdir(exist_ok=True)
    images = {}
    for variant in ("light", "dark", "tinted"):
        img, bg, fg = render(variant)
        images[variant] = img
        img.save(APPICON / f"icon-{variant}.png")
        img.save(PREVIEWS / f"icon-{variant}.png")
        if variant == "light":
            icon_composer_bundle(bg, fg, PREVIEWS / "AppIcon.icon")
    grid(images).save(PREVIEWS / "icon-grid.png")
    print("wrote", ", ".join(f"icon-{v}.png" for v in images), "icon-grid.png, AppIcon.icon ->", PREVIEWS)


if __name__ == "__main__":
    main()
