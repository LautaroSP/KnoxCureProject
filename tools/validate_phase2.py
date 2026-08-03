"""Validate the distributable Phase 2 station and visual-state assets."""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

from inspect_tiles_properties import parse


ROOT = Path(__file__).resolve().parents[1]
MOD = ROOT / "Contents" / "mods" / "KnoxCureProject" / "42"
MEDIA = MOD / "media"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def validate_images() -> None:
    expected = {
        ROOT / "art-source" / "tilesets" / "2x" / "kcp_lab_equipment_01.png": (1024, 768),
        ROOT / "art-source" / "tilesets" / "1x" / "kcp_lab_equipment_01.png": (512, 384),
        ROOT / "art-source" / "tilesets" / "2x" / "kcp_lab_equipment_leds_01.png": (1024, 1536),
        ROOT / "art-source" / "tilesets" / "1x" / "kcp_lab_equipment_leds_01.png": (512, 768),
    }
    for path, size in expected.items():
        require(path.exists(), f"Missing image: {path}")
        with Image.open(path) as image:
            require(image.size == size, f"Unexpected size for {path.name}: {image.size}")


def validate_tiles() -> None:
    sheets = parse(MEDIA / "KCP_LabEquipment.tiles")
    require(len(sheets) == 1, "Expected one custom tile-definition sheet")
    sheet = sheets[0]
    require(sheet["name"] == "kcp_lab_equipment_01", "Unexpected tilesheet name")
    require(len(sheet["tiles"]) == 24, "Expected 24 base tile cells")

    expected = {
        0: ("Centrifuge", "S", None, "200", "1"),
        1: ("Centrifuge", "E", None, "200", "1"),
        2: ("Centrifuge", "N", None, "200", "1"),
        3: ("Centrifuge", "W", None, "200", "1"),
        8: ("Biological Analyzer", "S", None, "350", "2"),
        9: ("Biological Analyzer", "E", None, "350", "2"),
        10: ("Biological Analyzer", "N", None, "350", "2"),
        11: ("Biological Analyzer", "W", None, "350", "2"),
        16: ("Synthesizer", "S", "0,0", "400", "4"),
        17: ("Synthesizer", "S", "1,0", "400", "4"),
        18: ("Synthesizer", "E", "0,0", "400", "4"),
        19: ("Synthesizer", "E", "0,1", "400", "4"),
        20: ("Synthesizer", "N", "0,0", "400", "4"),
        21: ("Synthesizer", "N", "1,0", "400", "4"),
        22: ("Synthesizer", "W", "0,0", "400", "4"),
        23: ("Synthesizer", "W", "0,1", "400", "4"),
    }
    for index, (name, facing, grid, weight, level) in expected.items():
        props = sheet["tiles"][index]["properties"]
        require(props.get("CustomName") == name, f"Tile {index}: CustomName")
        require(props.get("Facing") == facing, f"Tile {index}: Facing")
        require(props.get("SpriteGridPos") == grid, f"Tile {index}: SpriteGridPos")
        require(props.get("PickUpWeight") == weight, f"Tile {index}: PickUpWeight")
        require(props.get("PickUpLevel") == level, f"Tile {index}: PickUpLevel")
        for flag in ("IsMoveAble", "ForceSingleItem", "BlocksPlacement"):
            require(flag in props, f"Tile {index}: missing {flag}")


def validate_translations() -> None:
    required = {
        "IGUI_KCP_Context_Root",
        "IGUI_KCP_Context_Inspect",
        "IGUI_KCP_Context_PreviewState",
        "IGUI_KCP_State_off",
        "IGUI_KCP_State_ready",
        "IGUI_KCP_State_working",
        "IGUI_KCP_State_broken",
    }
    for language in ("EN", "ES"):
        path = MEDIA / "lua" / "shared" / "Translate" / language / "IG_UI.json"
        data = json.loads(path.read_text(encoding="utf-8"))
        require(required <= data.keys(), f"Missing {language} translation keys")


def validate_package() -> None:
    mod_info = (MOD / "mod.info").read_text(encoding="utf-8")
    require("pack=KCP_LabEquipment" in mod_info, "mod.info missing pack")
    require("tiledef=KCP_LabEquipment 867" in mod_info, "mod.info missing tiledef")

    pack = MEDIA / "texturepacks" / "KCP_LabEquipment.pack"
    data = pack.read_bytes()
    require(b"kcp_lab_equipment_01_" in data, "Pack missing base sprites")
    require(b"kcp_lab_equipment_leds_01_" in data, "Pack missing LED overlays")


def main() -> None:
    validate_images()
    validate_tiles()
    validate_translations()
    validate_package()
    print("Phase 2 validation: PASS")


if __name__ == "__main__":
    main()
