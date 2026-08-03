"""Promote approved LED fixtures and overlays into active art sources."""

from __future__ import annotations

from pathlib import Path
from shutil import copy2

from PIL import Image

from build_station_state_proposal import ORIENTATION_CONFIG, add_indicator_fixture
from build_synth_2x1_parts_proposal import (
    FACINGS,
    rotate_without_distortion,
    split_at_placement,
    sprite_placement,
)


ROOT = Path(__file__).resolve().parents[1]
PREVIEWS = ROOT / "art-source" / "game-previews"
TILESETS = ROOT / "art-source" / "tilesets"
PACK_INPUT = ROOT / "art-source" / "pack-input" / "2x"
LED_PROPOSAL = (
    ROOT
    / "art-source"
    / "proposals"
    / "station-led-overlays-v1"
    / "kcp_lab_equipment_leds_01.png"
)
MODDING_TOOLS_TILESET = Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\Project Zomboid Modding Tools"
    r"\Tiles\2x\kcp_lab_equipment_01.png"
)
ORIENTATIONS = ("front-left", "rear-left", "rear-right", "front-right")


def add_rear_fixtures() -> None:
    for machine, configs in ORIENTATION_CONFIG.items():
        for orientation, (center, _, needs_fixture) in configs.items():
            if not needs_fixture:
                continue
            path = PREVIEWS / "2x" / machine / f"{orientation}.png"
            image = Image.open(path).convert("RGBA")
            add_indicator_fixture(image, center)
            image.save(path)
            image.resize((64, 128), Image.Resampling.LANCZOS).save(
                PREVIEWS / "1x" / machine / f"{orientation}.png"
            )


def rebuild_synth_parts() -> None:
    for facing, orientation, delta, extension_pos, angle in FACINGS:
        source = Image.open(PREVIEWS / "2x" / "synthesizer" / f"{orientation}.png").convert("RGBA")
        transformed = rotate_without_distortion(source, angle)
        primary, extension = split_at_placement(
            transformed,
            delta,
            *sprite_placement(transformed, delta),
        )
        names = (
            f"synth_{facing}_primary_0_0.png",
            f"synth_{facing}_extension_{extension_pos.replace(',', '_')}.png",
        )
        for image, name in zip((primary, extension), names):
            image.save(PREVIEWS / "2x" / "synthesizer-2x1" / name)
            image.resize((64, 128), Image.Resampling.LANCZOS).save(
                PREVIEWS / "1x" / "synthesizer-2x1" / name
            )


def rebuild_base_tileset(scale: str) -> None:
    tile_width, tile_height = ((128, 256) if scale == "2x" else (64, 128))
    canvas = Image.new("RGBA", (tile_width * 8, tile_height * 3), (0, 0, 0, 0))
    for row, machine in enumerate(("centrifuge", "bio-analyzer")):
        for column, orientation in enumerate(ORIENTATIONS):
            image = Image.open(PREVIEWS / scale / machine / f"{orientation}.png").convert("RGBA")
            canvas.alpha_composite(image, (column * tile_width, row * tile_height))

    synth_names = (
        "synth_S_primary_0_0.png",
        "synth_S_extension_1_0.png",
        "synth_E_primary_0_0.png",
        "synth_E_extension_0_1.png",
        "synth_N_primary_0_0.png",
        "synth_N_extension_1_0.png",
        "synth_W_primary_0_0.png",
        "synth_W_extension_0_1.png",
    )
    for column, name in enumerate(synth_names):
        image = Image.open(PREVIEWS / scale / "synthesizer-2x1" / name).convert("RGBA")
        canvas.alpha_composite(image, (column * tile_width, tile_height * 2))
    canvas.save(TILESETS / scale / "kcp_lab_equipment_01.png")


def build_led_1x(source: Image.Image) -> Image.Image:
    output = Image.new("RGBA", (64 * 8, 128 * 6), (0, 0, 0, 0))
    for index in range(48):
        x = (index % 8) * 128
        y = (index // 8) * 256
        cell = source.crop((x, y, x + 128, y + 256))
        cell = cell.resize((64, 128), Image.Resampling.LANCZOS)
        output.alpha_composite(cell, ((index % 8) * 64, (index // 8) * 128))
    return output


def main() -> None:
    add_rear_fixtures()
    rebuild_synth_parts()
    rebuild_base_tileset("2x")
    rebuild_base_tileset("1x")

    led_2x = Image.open(LED_PROPOSAL).convert("RGBA")
    led_2x.save(TILESETS / "2x" / "kcp_lab_equipment_leds_01.png")
    build_led_1x(led_2x).save(TILESETS / "1x" / "kcp_lab_equipment_leds_01.png")

    PACK_INPUT.mkdir(parents=True, exist_ok=True)
    copy2(TILESETS / "2x" / "kcp_lab_equipment_01.png", PACK_INPUT / "kcp_lab_equipment_01.png")
    copy2(TILESETS / "2x" / "kcp_lab_equipment_leds_01.png", PACK_INPUT / "kcp_lab_equipment_leds_01.png")
    copy2(TILESETS / "2x" / "kcp_lab_equipment_01.png", MODDING_TOOLS_TILESET)


if __name__ == "__main__":
    main()
