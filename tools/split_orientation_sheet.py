"""Split an approved 2x2 RGBA turnaround into aligned transparent assets."""

from __future__ import annotations

import argparse
import math
from pathlib import Path

from PIL import Image


ORIENTATION_NAMES = ("front-left", "rear-left", "rear-right", "front-right")


def split_sheet(source: Path, output_dir: Path) -> None:
    sheet = Image.open(source).convert("RGBA")
    width, height = sheet.size
    if width % 2 or height % 2:
        raise ValueError(f"sheet dimensions must be even, got {sheet.size}")

    half_w, half_h = width // 2, height // 2
    boxes = (
        (0, 0, half_w, half_h),
        (half_w, 0, width, half_h),
        (0, half_h, half_w, height),
        (half_w, half_h, width, height),
    )
    cropped = []
    for box in boxes:
        quadrant = sheet.crop(box)
        bbox = quadrant.getchannel("A").getbbox()
        if bbox is None:
            raise ValueError("orientation quadrant has no visible pixels")
        cropped.append(quadrant.crop(bbox))

    content_w = max(image.width for image in cropped)
    content_h = max(image.height for image in cropped)
    padding = max(8, math.ceil(max(content_w, content_h) * 0.04))
    canvas_w = content_w + (padding * 2)
    canvas_h = content_h + (padding * 2)
    output_dir.mkdir(parents=True, exist_ok=True)

    for orientation, image in zip(ORIENTATION_NAMES, cropped):
        canvas = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
        x = (canvas_w - image.width) // 2
        y = canvas_h - padding - image.height
        canvas.alpha_composite(image, (x, y))
        canvas.save(output_dir / f"{orientation}.png", optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output_dir", type=Path)
    args = parser.parse_args()
    split_sheet(args.source, args.output_dir)


if __name__ == "__main__":
    main()
