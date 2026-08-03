"""Build non-destructive smooth 2x sprite proposals from approved HD sources."""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art-source" / "approved" / "orientations"
CURRENT = ROOT / "art-source" / "game-previews" / "2x"
OUTPUT = ROOT / "art-source" / "proposals" / "hd-pass-v1"

MACHINES = ("centrifuge", "bio-analyzer", "synthesizer")
ORIENTATIONS = ("front-left", "rear-left", "rear-right", "front-right")

# Visual correction only. Facing metadata remains S/E/N/W.
SYNTH_X_OFFSET = {
    "front-left": 0,
    "rear-left": -4,
    "rear-right": 5,
    "front-right": -6,
}


def resize_premultiplied(image: Image.Image, width: int) -> Image.Image:
    """Resize RGBA without dark fringes from transparent RGB pixels."""
    image = image.convert("RGBA")
    height = round(image.height * width / image.width)
    rgba = np.asarray(image, dtype=np.float32) / 255.0
    alpha = rgba[..., 3:4]
    premultiplied = np.concatenate((rgba[..., :3] * alpha, alpha), axis=2)

    channels = []
    for index in range(4):
        channel = Image.fromarray(premultiplied[..., index], mode="F")
        channels.append(
            np.asarray(
                channel.resize((width, height), Image.Resampling.LANCZOS),
                dtype=np.float32,
            )
        )

    resized = np.stack(channels, axis=2)
    out_alpha = np.clip(resized[..., 3:4], 0.0, 1.0)
    out_rgb = np.divide(
        resized[..., :3],
        np.maximum(out_alpha, 1.0 / 255.0),
        out=np.zeros_like(resized[..., :3]),
        where=out_alpha > 0.0,
    )
    result = np.concatenate((np.clip(out_rgb, 0.0, 1.0), out_alpha), axis=2)
    return Image.fromarray(np.rint(result * 255.0).astype(np.uint8), mode="RGBA")


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("Image has no visible pixels")
    return bbox


def composite_to_existing_registration(
    smooth: Image.Image, current: Image.Image, x_adjustment: int
) -> Image.Image:
    """Preserve current bottom registration, then apply an approved X correction."""
    current_box = alpha_bbox(current)
    smooth_box = alpha_bbox(smooth)
    current_center = (current_box[0] + current_box[2] - 1) / 2
    smooth_center = (smooth_box[0] + smooth_box[2] - 1) / 2
    x = round(current_center - smooth_center) + x_adjustment
    y = current_box[3] - smooth_box[3]

    canvas = Image.new("RGBA", current.size, (0, 0, 0, 0))
    canvas.alpha_composite(smooth, (x, y))
    return canvas


def checkerboard(size: tuple[int, int], cell: int = 8) -> Image.Image:
    board = Image.new("RGBA", size, (52, 52, 52, 255))
    draw = ImageDraw.Draw(board)
    for y in range(0, size[1], cell):
        for x in range(0, size[0], cell):
            if (x // cell + y // cell) % 2:
                draw.rectangle((x, y, x + cell - 1, y + cell - 1), fill=(72, 72, 72, 255))
    return board


def build_comparison(images: dict[tuple[str, str], tuple[Image.Image, Image.Image]]) -> None:
    margin = 16
    label_height = 34
    pair_width = 128 * 2 + margin
    row_height = 256 + label_height + margin
    sheet = Image.new(
        "RGBA",
        (margin + pair_width * len(ORIENTATIONS), margin + row_height * len(MACHINES)),
        (28, 28, 28, 255),
    )
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()

    for row, machine in enumerate(MACHINES):
        for column, orientation in enumerate(ORIENTATIONS):
            current, proposal = images[(machine, orientation)]
            x = margin + column * pair_width
            y = margin + row * row_height + label_height
            background = checkerboard((128, 256))
            left = background.copy()
            left.alpha_composite(current)
            right = background.copy()
            right.alpha_composite(proposal)
            sheet.alpha_composite(left, (x, y))
            sheet.alpha_composite(right, (x + 128, y))
            draw.text((x, y - 30), f"{machine} / {orientation}", font=font, fill="white")
            draw.text((x, y - 16), "actual            propuesta", font=font, fill=(205, 205, 205))

    sheet.save(OUTPUT / "comparison.png")


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    comparisons: dict[tuple[str, str], tuple[Image.Image, Image.Image]] = {}

    for machine in MACHINES:
        machine_output = OUTPUT / machine
        machine_output.mkdir(parents=True, exist_ok=True)
        for orientation in ORIENTATIONS:
            source = Image.open(SOURCE / machine / f"{orientation}.png").convert("RGBA")
            current = Image.open(CURRENT / machine / f"{orientation}.png").convert("RGBA")
            smooth = resize_premultiplied(source, 128)
            x_adjustment = SYNTH_X_OFFSET.get(orientation, 0) if machine == "synthesizer" else 0
            proposal = composite_to_existing_registration(smooth, current, x_adjustment)
            proposal.save(machine_output / f"{orientation}.png")
            comparisons[(machine, orientation)] = (current, proposal)

    build_comparison(comparisons)


if __name__ == "__main__":
    main()
