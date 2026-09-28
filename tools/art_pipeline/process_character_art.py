#!/usr/bin/env python3
"""
process_character_art.py

Turns a single ChatGPT-generated full-body character image into two
Godot-ready assets:
  - sprite.png  : small, heavily pixelated overworld sprite
  - portrait.png: larger, more detailed dialogue-box bust crop

Usage:
    python3 process_character_art.py <input_image> <output_dir> [--id character_id]
"""

import sys
import argparse
from pathlib import Path
from PIL import Image

SPRITE_SIZE = (64, 96)     # overworld sprite canvas
PORTRAIT_SIZE = (256, 256) # dialogue box portrait canvas
SPRITE_PIXEL_WIDTH = 48    # internal low-res grid width before upscaling
SPRITE_COLORS = 24         # palette size for the sprite
PORTRAIT_COLORS = 64       # palette size for the portrait (kept richer)
TRIM_PADDING = 4           # px of breathing room kept around trimmed content


def load_rgba(path: Path) -> Image.Image:
    # PIL reads by actual file content, not extension, so a PNG
    # mislabeled as .jpg still loads correctly here.
    img = Image.open(path)
    return img.convert("RGBA")


ALPHA_TRIM_THRESHOLD = 24  # ignore near-invisible stray pixels when finding content bounds


def trim_to_content(img: Image.Image, padding: int = TRIM_PADDING) -> Image.Image:
    alpha = img.split()[-1]
    # A raw getbbox() on the alpha channel treats any pixel with even
    # alpha=1 as "content," so faint AI-generated background dust can
    # skew the crop off-center. Threshold it first.
    mask = alpha.point(lambda a: 255 if a > ALPHA_TRIM_THRESHOLD else 0)
    bbox = mask.getbbox()
    if bbox is None:
        return img

    left, top, right, bottom = bbox
    left = max(0, left - padding)
    top = max(0, top - padding)
    right = min(img.width, right + padding)
    bottom = min(img.height, bottom + padding)
    return img.crop((left, top, right, bottom))


def quantize_preserving_alpha(img: Image.Image, colors: int) -> Image.Image:
    # PIL's quantize() doesn't handle alpha well directly, so we
    # composite onto opaque white for palette reduction, then splice
    # the original alpha channel back in afterward.
    alpha = img.split()[-1]
    rgb = Image.new("RGB", img.size, (255, 255, 255))
    rgb.paste(img, mask=alpha)

    quantized = rgb.quantize(colors=colors, method=Image.MEDIANCUT).convert("RGB")
    result = quantized.convert("RGBA")
    result.putalpha(alpha)
    return result


def fit_on_transparent_canvas(img: Image.Image, canvas_size: tuple, mode: str = "contain") -> Image.Image:
    canvas_w, canvas_h = canvas_size

    if mode == "cover":
        # Fill the whole canvas, cropping any overflow -- right for a
        # bust portrait, where empty letterboxing looks wrong.
        scale = max(canvas_w / img.width, canvas_h / img.height)
        new_w = max(1, round(img.width * scale))
        new_h = max(1, round(img.height * scale))
        resized = img.resize((new_w, new_h), Image.LANCZOS)

        left = (new_w - canvas_w) // 2
        top = (new_h - canvas_h) // 2
        return resized.crop((left, top, left + canvas_w, top + canvas_h))

    # "contain": fit inside the canvas without cropping, anchored to
    # the bottom-center -- right for a full-body sprite standing on
    # the ground.
    scale = min(canvas_w / img.width, canvas_h / img.height)
    new_w = max(1, round(img.width * scale))
    new_h = max(1, round(img.height * scale))

    resized = img.resize((new_w, new_h), Image.LANCZOS)
    canvas = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    canvas.paste(resized, ((canvas_w - new_w) // 2, canvas_h - new_h), resized)
    return canvas


def make_sprite(trimmed: Image.Image) -> Image.Image:
    # Downscale hard to a small pixel grid (this is what actually
    # creates the "real pixel art" look), quantize the palette, then
    # scale back up with nearest-neighbor to keep edges crisp/blocky.
    aspect = trimmed.height / trimmed.width
    low_w = SPRITE_PIXEL_WIDTH
    low_h = max(1, round(low_w * aspect))

    small = trimmed.resize((low_w, low_h), Image.BOX)
    small = quantize_preserving_alpha(small, SPRITE_COLORS)

    upscale_factor = max(1, SPRITE_SIZE[1] // low_h)
    blocky = small.resize(
        (low_w * upscale_factor, low_h * upscale_factor), Image.NEAREST
    )

    return fit_on_transparent_canvas(blocky, SPRITE_SIZE)


def make_portrait(trimmed: Image.Image, top_frac: float, bottom_frac: float) -> Image.Image:
    # Crop the head/shoulders/bust region from the ORIGINAL trimmed
    # image (not the pixelated sprite), so the portrait stays more
    # detailed than the tiny overworld sprite. top_frac/bottom_frac
    # are fractions of the trimmed artwork's height -- these vary per
    # character (e.g. a floating flame or halo above the head shifts
    # where the face actually sits), so preview first and adjust.
    top = round(trimmed.height * top_frac)
    bottom = round(trimmed.height * bottom_frac)
    bust = trimmed.crop((0, top, trimmed.width, bottom))
    bust = quantize_preserving_alpha(bust, PORTRAIT_COLORS)

    return fit_on_transparent_canvas(bust, PORTRAIT_SIZE, mode="cover")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("input_image")
    parser.add_argument("output_dir")
    parser.add_argument("--id", default=None, help="character id, used as filename prefix info only")
    parser.add_argument("--bust-top", type=float, default=0.0,
                         help="top of the portrait crop, as a fraction (0-1) of the trimmed artwork's height")
    parser.add_argument("--bust-bottom", type=float, default=0.5,
                         help="bottom of the portrait crop, as a fraction (0-1) of the trimmed artwork's height")
    args = parser.parse_args()

    input_path = Path(args.input_image)
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    source = load_rgba(input_path)
    trimmed = trim_to_content(source)

    sprite = make_sprite(trimmed)
    portrait = make_portrait(trimmed, args.bust_top, args.bust_bottom)

    sprite_path = output_dir / "sprite.png"
    portrait_path = output_dir / "portrait.png"

    sprite.save(sprite_path)
    portrait.save(portrait_path)

    print(f"Wrote {sprite_path} ({sprite.size[0]}x{sprite.size[1]})")
    print(f"Wrote {portrait_path} ({portrait.size[0]}x{portrait.size[1]})")


if __name__ == "__main__":
    main()
