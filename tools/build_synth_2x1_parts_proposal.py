"""Build a non-destructive eight-sprite proposal for the 2x1 synthesizer."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art-source" / "game-previews" / "2x" / "synthesizer"
OUTPUT = ROOT / "art-source" / "proposals" / "synthesizer-2x1-v1" / "parts"

TILE_WIDTH = 128
TILE_HEIGHT = 256
TILE_CENTER_Y = 224

FACINGS = (
    ("S", "front-right", (64, 32), "1,0", -11.5),
    ("E", "rear-right", (-64, 32), "0,1", 0.0),
    ("N", "rear-left", (64, 32), "1,0", 0.0),
    ("W", "front-left", (-64, 32), "0,1", 11.5),
)


def base_center_x(sprite: Image.Image, rows: int = 16) -> float:
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


def rotate_without_distortion(sprite: Image.Image, angle: float) -> Image.Image:
    if angle == 0.0:
        return sprite
    return sprite.rotate(
        angle,
        resample=Image.Resampling.BICUBIC,
        expand=True,
    )


def sprite_placement(sprite: Image.Image, delta: tuple[int, int]) -> tuple[int, int]:
    bbox = sprite.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("Synthesizer sprite has no visible pixels")
    support_x = base_center_x(sprite)
    target_support_x = round(delta[0] / 2)
    target_bottom_y = 32 + round(delta[1] / 2) - 7
    return round(target_support_x - support_x), target_bottom_y - bbox[3]


def split_at_placement(
    sprite: Image.Image,
    delta: tuple[int, int],
    offset_x: int,
    offset_y: int,
) -> tuple[Image.Image, Image.Image]:
    """Partition world pixels between two tile-local 128x256 canvases."""

    parts = [
        Image.new("RGBA", (TILE_WIDTH, TILE_HEIGHT), (0, 0, 0, 0)),
        Image.new("RGBA", (TILE_WIDTH, TILE_HEIGHT), (0, 0, 0, 0)),
    ]
    tile_offsets = ((0, 0), delta)
    lost = 0

    for source_y in range(sprite.height):
        for source_x in range(sprite.width):
            pixel = sprite.getpixel((source_x, source_y))
            if pixel[3] == 0:
                continue

            world_x = source_x + offset_x
            world_y = source_y + offset_y
            distance_primary = world_x * world_x + world_y * world_y
            distance_extension = (
                (world_x - delta[0]) ** 2 + (world_y - delta[1]) ** 2
            )
            preferred = 0 if distance_primary <= distance_extension else 1
            candidates = (preferred, 1 - preferred)

            placed = False
            for part_index in candidates:
                tile_x, tile_y = tile_offsets[part_index]
                local_x = world_x - tile_x + TILE_WIDTH // 2
                local_y = world_y - tile_y + TILE_CENTER_Y
                if 0 <= local_x < TILE_WIDTH and 0 <= local_y < TILE_HEIGHT:
                    parts[part_index].putpixel((local_x, local_y), pixel)
                    placed = True
                    break
            if not placed:
                lost += 1

    if lost:
        raise ValueError(f"Split lost {lost} visible pixels")
    return parts[0], parts[1]


def split_sprite(sprite: Image.Image, delta: tuple[int, int]) -> tuple[Image.Image, Image.Image]:
    return split_at_placement(sprite, delta, *sprite_placement(sprite, delta))


def diamond(draw: ImageDraw.ImageDraw, cx: int, cy: int, fill, outline) -> None:
    points = ((cx, cy - 32), (cx + 64, cy), (cx, cy + 32), (cx - 64, cy))
    draw.polygon(points, fill=fill)
    draw.line(points + (points[0],), fill=outline, width=3)


def checker(size: tuple[int, int], cell: int = 8) -> Image.Image:
    result = Image.new("RGBA", size, (63, 66, 71, 255))
    draw = ImageDraw.Draw(result)
    for y in range(0, size[1], cell):
        for x in range(0, size[0], cell):
            if (x // cell + y // cell) % 2:
                draw.rectangle((x, y, x + cell - 1, y + cell - 1), fill=(45, 48, 52, 255))
    return result


def composite_part(panel: Image.Image, part: Image.Image, tile_center: tuple[int, int]) -> None:
    x = tile_center[0] - TILE_WIDTH // 2
    y = tile_center[1] - TILE_CENTER_Y
    panel.alpha_composite(part, (x, y))


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    panel_width = 300
    panel_height = 520
    sheet = Image.new("RGBA", (panel_width * 4, panel_height), (27, 29, 32, 255))
    font = ImageFont.load_default()

    for index, (facing, orientation, delta, extension_pos, angle) in enumerate(FACINGS):
        source = Image.open(SOURCE / f"{orientation}.png").convert("RGBA")
        transformed = rotate_without_distortion(source, angle)
        primary, extension = split_sprite(transformed, delta)
        primary.save(OUTPUT / f"synth_{facing}_primary_0_0.png")
        extension.save(OUTPUT / f"synth_{facing}_extension_{extension_pos.replace(',', '_')}.png")

        panel = Image.new("RGBA", (panel_width, panel_height), (35, 38, 42, 255))
        draw = ImageDraw.Draw(panel, "RGBA")
        main_center = (150, 270)
        extension_center = (main_center[0] + delta[0], main_center[1] + delta[1])
        diamond(draw, extension_center[0], extension_center[1], (220, 151, 45, 70), (245, 177, 66, 235))
        diamond(draw, main_center[0], main_center[1], (62, 142, 220, 70), (90, 172, 250, 245))
        composite_part(panel, primary, main_center)
        composite_part(panel, extension, extension_center)

        draw = ImageDraw.Draw(panel, "RGBA")
        draw.text((12, 10), f"Facing {facing} / {orientation}", font=font, fill=(255, 255, 255, 255))
        adjustment = "sin cambios" if angle == 0.0 else f"rotacion {angle:+.1f} grados"
        draw.text((12, 27), adjustment, font=font, fill=(210, 210, 210, 255))
        draw.text((12, 44), f"reconstruccion: (0,0) + ({extension_pos})", font=font, fill=(255, 195, 95, 255))

        draw.text((12, 345), "piezas PNG 128x256", font=font, fill=(255, 255, 255, 255))
        for part_index, (part, label) in enumerate(((primary, "principal"), (extension, "extension"))):
            preview = checker((64, 128), 4)
            preview.alpha_composite(part.resize((64, 128), Image.Resampling.LANCZOS))
            px = 70 + part_index * 100
            panel.alpha_composite(preview, (px, 370))
            draw.rectangle((px, 370, px + 63, 497), outline=(130, 135, 142, 255), width=1)
            draw.text((px + 3, 501), label, font=font, fill=(210, 210, 210, 255))

        sheet.alpha_composite(panel, (index * panel_width, 0))

    sheet.save(OUTPUT.parent / "eight-parts-comparison.png")


if __name__ == "__main__":
    main()
