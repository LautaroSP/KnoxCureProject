"""Build non-destructive static light-state proposals for laboratory equipment."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art-source" / "game-previews" / "2x"
OUTPUT = ROOT / "art-source" / "proposals" / "station-states-v1"

MACHINES = (
    ("centrifuge", "Centrífuga", (101, 153), None),
    ("bio-analyzer", "Analizador", (103, 144), (48, 129, 78, 158)),
    ("synthesizer", "Sintetizador", (99, 170), (28, 162, 61, 181)),
)

ORIENTATIONS = ("front-left", "rear-left", "rear-right", "front-right")

ORIENTATION_CONFIG = {
    "centrifuge": {
        "front-left": ((61, 139), None, False),
        "rear-left": ((91, 129), None, True),
        "rear-right": ((88, 147), None, True),
        "front-right": ((101, 153), None, False),
    },
    "bio-analyzer": {
        "front-left": ((76, 139), (18, 117, 48, 149), False),
        "rear-left": ((103, 171), None, True),
        "rear-right": ((26, 171), None, True),
        "front-right": ((103, 144), (48, 129, 78, 158), False),
    },
    "synthesizer": {
        "front-left": ((29, 191), (52, 162, 86, 187), False),
        "rear-left": ((93, 166), None, True),
        "rear-right": ((32, 168), None, True),
        "front-right": ((99, 170), (28, 162, 61, 181), False),
    },
}

STATES = (
    ("off", "Apagado", None),
    ("ready", "Listo", (65, 235, 105)),
    ("working", "Trabajando", (255, 174, 52)),
    ("broken", "Averiado", (245, 58, 48)),
)


def add_indicator(image: Image.Image, center: tuple[int, int], color: tuple[int, int, int]) -> None:
    glow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    x, y = center
    glow_draw.ellipse((x - 4, y - 4, x + 4, y + 4), fill=(*color, 105))
    glow = glow.filter(ImageFilter.GaussianBlur(2.2))
    image.alpha_composite(glow)

    core = ImageDraw.Draw(image)
    core.ellipse((x - 1, y - 1, x + 1, y + 1), fill=(*color, 255))
    core.point((x, y), fill=(255, 245, 220, 255))


def add_indicator_fixture(image: Image.Image, center: tuple[int, int]) -> None:
    draw = ImageDraw.Draw(image)
    x, y = center
    draw.ellipse((x - 2, y - 2, x + 2, y + 2), fill=(35, 37, 38, 255))
    draw.point((x - 1, y - 1), fill=(125, 118, 103, 255))


def checkerboard(size: tuple[int, int], cell: int = 8) -> Image.Image:
    board = Image.new("RGBA", size, (50, 52, 55, 255))
    draw = ImageDraw.Draw(board)
    for y in range(0, size[1], cell):
        for x in range(0, size[0], cell):
            if (x // cell + y // cell) % 2:
                draw.rectangle((x, y, x + cell - 1, y + cell - 1), fill=(67, 70, 74, 255))
    return board


def build_state(base: Image.Image, center, light_color) -> Image.Image:
    result = base.copy()
    if light_color:
        add_indicator(result, center, light_color)
    return result


def fitted_preview(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("State proposal has no visible pixels")
    margin = 4
    crop = image.crop(
        (
            max(0, bbox[0] - margin),
            max(0, bbox[1] - margin),
            min(image.width, bbox[2] + margin),
            min(image.height, bbox[3] + margin),
        )
    )
    scale = min(size[0] / crop.width, size[1] / crop.height)
    resized = crop.resize(
        (round(crop.width * scale), round(crop.height * scale)),
        Image.Resampling.NEAREST,
    )
    canvas = checkerboard(size)
    canvas.alpha_composite(
        resized,
        ((size[0] - resized.width) // 2, size[1] - resized.height),
    )
    return canvas


def build_all_orientation_sheets(font: ImageFont.ImageFont) -> None:
    labels = {machine: label for machine, label, _, _ in MACHINES}
    root = OUTPUT / "all-orientations"
    root.mkdir(parents=True, exist_ok=True)
    panel_width = 176
    panel_height = 250

    for machine, configs in ORIENTATION_CONFIG.items():
        sheet = Image.new(
            "RGBA",
            (panel_width * len(STATES), panel_height * len(ORIENTATIONS)),
            (27, 29, 32, 255),
        )
        for row, orientation in enumerate(ORIENTATIONS):
            center, screen_box, needs_fixture = configs[orientation]
            base = Image.open(SOURCE / machine / f"{orientation}.png").convert("RGBA")
            for column, (state, state_label, light_color) in enumerate(STATES):
                prepared = base.copy()
                if needs_fixture:
                    add_indicator_fixture(prepared, center)
                proposal = build_state(prepared, center, light_color)
                destination = root / machine / orientation
                destination.mkdir(parents=True, exist_ok=True)
                proposal.save(destination / f"{state}.png")

                panel = Image.new("RGBA", (panel_width, panel_height), (35, 38, 42, 255))
                panel.alpha_composite(fitted_preview(proposal, (160, 205)), (8, 39))
                draw = ImageDraw.Draw(panel)
                draw.text((8, 7), labels[machine], font=font, fill="white")
                draw.text((8, 22), f"{orientation} / {state_label}", font=font, fill=(210, 210, 210, 255))
                sheet.alpha_composite(panel, (column * panel_width, row * panel_height))
        sheet.save(root / f"{machine}-comparison.png")


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    panel_width = 256
    panel_height = 300
    sheet = Image.new("RGBA", (panel_width * 4, panel_height * 3), (27, 29, 32, 255))
    font = ImageFont.load_default()
    grid_sheet = Image.new("RGBA", (128 * 4 * 3, 256 * 4), (20, 20, 20, 255))

    for row, (machine, machine_label, center, screen_box) in enumerate(MACHINES):
        machine_output = OUTPUT / machine
        machine_output.mkdir(parents=True, exist_ok=True)
        base = Image.open(SOURCE / machine / "front-right.png").convert("RGBA")
        diagnostic = base.resize((512, 1024), Image.Resampling.NEAREST)
        diagnostic_draw = ImageDraw.Draw(diagnostic)
        for coordinate in range(0, 128, 8):
            x = coordinate * 4
            diagnostic_draw.line((x, 0, x, 1023), fill=(0, 180, 255, 105), width=1)
            diagnostic_draw.text((x + 2, 2), str(coordinate), font=font, fill=(255, 255, 255, 255))
        for coordinate in range(0, 256, 8):
            y = coordinate * 4
            diagnostic_draw.line((0, y, 511, y), fill=(0, 180, 255, 105), width=1)
            diagnostic_draw.text((2, y + 2), str(coordinate), font=font, fill=(255, 255, 255, 255))
        grid_sheet.alpha_composite(diagnostic, (row * 512, 0))

        for column, (state, state_label, light_color) in enumerate(STATES):
            proposal = build_state(base, center, light_color)
            proposal.save(machine_output / f"{state}.png")

            panel = Image.new("RGBA", (panel_width, panel_height), (35, 38, 42, 255))
            preview = checkerboard((128, 256))
            preview.alpha_composite(proposal)
            preview = preview.resize((192, 384), Image.Resampling.NEAREST).crop((0, 72, 192, 300))
            panel.alpha_composite(preview, (32, 62))
            draw = ImageDraw.Draw(panel)
            draw.text((12, 12), machine_label, font=font, fill=(255, 255, 255, 255))
            draw.text((12, 30), state_label, font=font, fill=(210, 210, 210, 255))
            sheet.alpha_composite(panel, (column * panel_width, row * panel_height))

    sheet.save(OUTPUT / "comparison.png")
    grid_sheet.save(OUTPUT / "coordinate-grid.png")
    build_all_orientation_sheets(font)


if __name__ == "__main__":
    main()
