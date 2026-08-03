"""Promote the approved synthesizer pairs into the active 2x/1x tilesets."""

from __future__ import annotations

from pathlib import Path
from shutil import copy2

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
PROPOSAL = ROOT / "art-source" / "proposals" / "synthesizer-2x1-v1" / "parts"
PREVIEWS = ROOT / "art-source" / "game-previews"
TILESETS = ROOT / "art-source" / "tilesets"
PACK_INPUT = ROOT / "art-source" / "pack-input" / "2x"
MODDING_TOOLS_TILESET = Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\Project Zomboid Modding Tools"
    r"\Tiles\2x\kcp_lab_equipment_01.png"
)

PARTS = (
    "synth_S_primary_0_0.png",
    "synth_S_extension_1_0.png",
    "synth_E_primary_0_0.png",
    "synth_E_extension_0_1.png",
    "synth_N_primary_0_0.png",
    "synth_N_extension_1_0.png",
    "synth_W_primary_0_0.png",
    "synth_W_extension_0_1.png",
)


def promote_parts() -> None:
    for scale in ("2x", "1x"):
        destination = PREVIEWS / scale / "synthesizer-2x1"
        destination.mkdir(parents=True, exist_ok=True)
        for filename in PARTS:
            source = Image.open(PROPOSAL / filename).convert("RGBA")
            if scale == "1x":
                source = source.resize((64, 128), Image.Resampling.LANCZOS)
            source.save(destination / filename)


def rebuild_tileset(scale: str) -> None:
    tile_width, tile_height = ((128, 256) if scale == "2x" else (64, 128))
    path = TILESETS / scale / "kcp_lab_equipment_01.png"
    tileset = Image.open(path).convert("RGBA")
    expected_size = (tile_width * 8, tile_height * 3)
    if tileset.size != expected_size:
        raise ValueError(f"Unexpected {scale} tileset size: {tileset.size}")

    clear = Image.new("RGBA", (tile_width * 8, tile_height), (0, 0, 0, 0))
    tileset.alpha_composite(clear, (0, tile_height * 2))
    # alpha_composite with a transparent image does not erase existing pixels.
    tileset.paste((0, 0, 0, 0), (0, tile_height * 2, tile_width * 8, tile_height * 3))

    source_dir = PREVIEWS / scale / "synthesizer-2x1"
    for column, filename in enumerate(PARTS):
        part = Image.open(source_dir / filename).convert("RGBA")
        if part.size != (tile_width, tile_height):
            raise ValueError(f"Unexpected part size for {filename}: {part.size}")
        tileset.alpha_composite(part, (column * tile_width, tile_height * 2))

    tileset.save(path)


def main() -> None:
    promote_parts()
    rebuild_tileset("2x")
    rebuild_tileset("1x")
    copy2(TILESETS / "2x" / "kcp_lab_equipment_01.png", MODDING_TOOLS_TILESET)
    PACK_INPUT.mkdir(parents=True, exist_ok=True)
    copy2(TILESETS / "2x" / "kcp_lab_equipment_01.png", PACK_INPUT / "kcp_lab_equipment_01.png")


if __name__ == "__main__":
    main()
