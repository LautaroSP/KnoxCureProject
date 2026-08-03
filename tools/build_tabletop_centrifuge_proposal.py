"""Create a non-destructive tabletop-size centrifuge proposal."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from build_hd_preview_proposal import checkerboard, resize_premultiplied


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art-source" / "approved" / "orientations" / "centrifuge"
CURRENT = ROOT / "art-source" / "game-previews" / "2x" / "centrifuge"
OUTPUT = ROOT / "art-source" / "proposals" / "tabletop-centrifuge-v1"

ORIENTATIONS = ("front-left", "rear-left", "rear-right", "front-right")

# Facing order is S, E, N, W. These bottom registrations mirror vanilla
# tabletop appliances, whose north/west views sit lower in the tile canvas.
TARGET_ALPHA_BOTTOM = {
    "front-left": 170,
    "rear-left": 170,
    "rear-right": 182,
    "front-right": 181,
}


def place_tabletop(image: Image.Image, orientation: str) -> Image.Image:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("Centrifuge source has no visible pixels")
    center = (bbox[0] + bbox[2] - 1) / 2
    x = round(63.5 - center)
    y = TARGET_ALPHA_BOTTOM[orientation] - bbox[3]
    canvas = Image.new("RGBA", (128, 256), (0, 0, 0, 0))
    canvas.alpha_composite(image, (x, y))
    return canvas


def build_comparison(pairs: dict[str, tuple[Image.Image, Image.Image]]) -> None:
    margin = 16
    label_height = 32
    pair_width = 128 * 2 + margin
    sheet = Image.new(
        "RGBA",
        (margin + pair_width * len(ORIENTATIONS), margin + label_height + 256),
        (28, 28, 28, 255),
    )
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()

    for column, orientation in enumerate(ORIENTATIONS):
        current, proposal = pairs[orientation]
        x = margin + column * pair_width
        y = margin + label_height
        left = checkerboard((128, 256))
        right = checkerboard((128, 256))
        left.alpha_composite(current)
        right.alpha_composite(proposal)
        sheet.alpha_composite(left, (x, y))
        sheet.alpha_composite(right, (x + 128, y))
        draw.text((x, y - 28), orientation, font=font, fill="white")
        draw.text((x, y - 14), "actual            sobremesa", font=font, fill=(205, 205, 205))

    sheet.save(OUTPUT / "comparison.png")


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    pairs: dict[str, tuple[Image.Image, Image.Image]] = {}
    for orientation in ORIENTATIONS:
        source = Image.open(SOURCE / f"{orientation}.png").convert("RGBA")
        current = Image.open(CURRENT / f"{orientation}.png").convert("RGBA")
        smooth = resize_premultiplied(source, 84)
        proposal = place_tabletop(smooth, orientation)
        proposal.save(OUTPUT / f"{orientation}.png")
        pairs[orientation] = (current, proposal)
    build_comparison(pairs)


if __name__ == "__main__":
    main()
