"""Render a non-destructive two-tile footprint proposal for the synthesizer."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art-source" / "game-previews" / "2x" / "synthesizer"
OUTPUT = ROOT / "art-source" / "proposals" / "synthesizer-2x1-v1"

ORIENTATIONS = (
    ("front-right", "S", (64, 32), "1,0"),
    ("rear-right", "E", (-64, 32), "0,1"),
    ("rear-left", "N", (64, 32), "1,0"),
    ("front-left", "W", (-64, 32), "0,1"),
)

FACING_ROTATION = {
    # Only the two views whose bases did not follow the isometric tile edge
    # are rotated. East and North remain pixel-for-pixel unchanged.
    "S": -11.5,
    "E": 0.0,
    "N": 0.0,
    "W": 11.5,
}


def diamond(draw: ImageDraw.ImageDraw, cx: int, cy: int, fill, outline, width: int = 3) -> None:
    points = ((cx, cy - 32), (cx + 64, cy), (cx, cy + 32), (cx - 64, cy))
    draw.polygon(points, fill=fill)
    draw.line(points + (points[0],), fill=outline, width=width)


def base_center_x(sprite: Image.Image, rows: int = 16) -> float:
    """Estimate the visual support point from the lowest opaque rows."""
    alpha = sprite.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError("Synthesizer sprite has no visible pixels")
    start_y = max(bbox[1], bbox[3] - rows)
    weighted_x = 0.0
    total_alpha = 0.0
    for y in range(start_y, bbox[3]):
        for x in range(sprite.width):
            value = alpha.getpixel((x, y))
            weighted_x += x * value
            total_alpha += value
    return weighted_x / total_alpha


def rotate_to_tile_edge(sprite: Image.Image, angle: float) -> Image.Image:
    """Rotate without changing the model's proportions; zero is untouched."""
    if angle == 0.0:
        return sprite
    return sprite.rotate(
        angle,
        resample=Image.Resampling.BICUBIC,
        expand=True,
    )


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    panel_width = 300
    panel_height = 330
    sheet = Image.new("RGBA", (panel_width * 4, panel_height), (27, 29, 32, 255))
    font = ImageFont.load_default()

    for index, (orientation, facing, delta, extension_pos) in enumerate(ORIENTATIONS):
        panel = Image.new("RGBA", (panel_width, panel_height), (35, 38, 42, 255))
        draw = ImageDraw.Draw(panel, "RGBA")
        main_center = (150, 250)
        extension_center = (main_center[0] + delta[0], main_center[1] + delta[1])

        diamond(draw, extension_center[0], extension_center[1], (220, 151, 45, 70), (245, 177, 66, 235))
        diamond(draw, main_center[0], main_center[1], (62, 142, 220, 70), (90, 172, 250, 245))

        sprite = Image.open(SOURCE / f"{orientation}.png").convert("RGBA")
        sprite = rotate_to_tile_edge(sprite, FACING_ROTATION[facing])
        bbox = sprite.getchannel("A").getbbox()
        if bbox is None:
            raise ValueError("Transformed synthesizer has no visible pixels")
        support_x = base_center_x(sprite)
        target_support_x = main_center[0] + round(delta[0] / 2)
        target_bottom_y = main_center[1] + 32 + round(delta[1] / 2) - 7
        sprite_x = round(target_support_x - support_x)
        sprite_y = target_bottom_y - bbox[3]
        panel.alpha_composite(sprite, (sprite_x, sprite_y))

        draw = ImageDraw.Draw(panel, "RGBA")
        draw.text((12, 10), f"{orientation} / Facing {facing}", font=font, fill=(255, 255, 255, 255))
        draw.text((12, 27), "azul: principal (0,0)", font=font, fill=(125, 194, 255, 255))
        draw.text((12, 43), f"ambar: extension ({extension_pos})", font=font, fill=(255, 195, 95, 255))
        adjustment = FACING_ROTATION[facing]
        label = "sin cambios" if adjustment == 0.0 else f"rotacion: {adjustment:+.1f} grados"
        draw.text((12, 59), label, font=font, fill=(210, 210, 210, 255))
        sheet.alpha_composite(panel, (index * panel_width, 0))

    sheet.save(OUTPUT / "footprint-comparison.png")


if __name__ == "__main__":
    main()
