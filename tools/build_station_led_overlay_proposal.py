"""Build a non-destructive tilesheet proposal containing LED overlays only."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from build_station_state_proposal import (
    ORIENTATION_CONFIG,
    SOURCE,
    add_indicator,
    add_indicator_fixture,
)
from build_synth_2x1_parts_proposal import (
    FACINGS,
    composite_part,
    diamond,
    rotate_without_distortion,
    split_at_placement,
    sprite_placement,
)


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "art-source" / "proposals" / "station-led-overlays-v1"
ORIENTATIONS = ("front-left", "rear-left", "rear-right", "front-right")
ACTIVE_STATES = (
    ("ready", (65, 235, 105)),
    ("working", (255, 174, 52)),
    ("broken", (245, 58, 48)),
)


def light_overlay(center: tuple[int, int], color: tuple[int, int, int]) -> Image.Image:
    overlay = Image.new("RGBA", (128, 256), (0, 0, 0, 0))
    add_indicator(overlay, center, color)
    return overlay


def synth_parts(state: str, color: tuple[int, int, int]) -> list[Image.Image]:
    parts = []
    for facing, orientation, delta, _, angle in FACINGS:
        center, _, needs_fixture = ORIENTATION_CONFIG["synthesizer"][orientation]
        base = Image.open(SOURCE / "synthesizer" / f"{orientation}.png").convert("RGBA")
        if needs_fixture:
            add_indicator_fixture(base, center)
        transformed_base = rotate_without_distortion(base, angle)
        placement = sprite_placement(transformed_base, delta)

        overlay = light_overlay(center, color)
        transformed_overlay = rotate_without_distortion(overlay, angle)
        primary, extension = split_at_placement(
            transformed_overlay,
            delta,
            placement[0],
            placement[1],
        )
        primary.save(OUTPUT / "parts" / f"synth_{state}_{facing}_primary.png")
        extension.save(OUTPUT / "parts" / f"synth_{state}_{facing}_extension.png")
        parts.extend((primary, extension))
    return parts


def build_synth_reconstruction() -> None:
    panel_width = 300
    panel_height = 330
    sheet = Image.new("RGBA", (panel_width * 4, panel_height * 3), (27, 29, 32, 255))
    font = ImageFont.load_default()

    for row, (state, color) in enumerate(ACTIVE_STATES):
        for column, (facing, orientation, delta, _, angle) in enumerate(FACINGS):
            center, _, needs_fixture = ORIENTATION_CONFIG["synthesizer"][orientation]
            base = Image.open(SOURCE / "synthesizer" / f"{orientation}.png").convert("RGBA")
            if needs_fixture:
                add_indicator_fixture(base, center)
            transformed_base = rotate_without_distortion(base, angle)
            placement = sprite_placement(transformed_base, delta)
            base_primary, base_extension = split_at_placement(
                transformed_base, delta, placement[0], placement[1]
            )

            overlay = light_overlay(center, color)
            transformed_overlay = rotate_without_distortion(overlay, angle)
            led_primary, led_extension = split_at_placement(
                transformed_overlay, delta, placement[0], placement[1]
            )
            base_primary.alpha_composite(led_primary)
            base_extension.alpha_composite(led_extension)

            panel = Image.new("RGBA", (panel_width, panel_height), (35, 38, 42, 255))
            draw = ImageDraw.Draw(panel, "RGBA")
            main_center = (150, 255)
            extension_center = (main_center[0] + delta[0], main_center[1] + delta[1])
            diamond(draw, extension_center[0], extension_center[1], (220, 151, 45, 55), (245, 177, 66, 210))
            diamond(draw, main_center[0], main_center[1], (62, 142, 220, 55), (90, 172, 250, 220))
            composite_part(panel, base_primary, main_center)
            composite_part(panel, base_extension, extension_center)
            draw = ImageDraw.Draw(panel)
            draw.text((10, 10), f"{state} / Facing {facing}", font=font, fill="white")
            sheet.alpha_composite(panel, (column * panel_width, row * panel_height))

    sheet.save(OUTPUT / "synthesizer-reconstruction.png")


def main() -> None:
    (OUTPUT / "parts").mkdir(parents=True, exist_ok=True)
    slots: list[Image.Image] = []
    labels: list[str] = []

    # Twelve centrifuge cells followed by twelve analyzer cells.
    for machine in ("centrifuge", "bio-analyzer"):
        for state, color in ACTIVE_STATES:
            for orientation in ORIENTATIONS:
                center, _, _ = ORIENTATION_CONFIG[machine][orientation]
                overlay = light_overlay(center, color)
                overlay.save(OUTPUT / "parts" / f"{machine}_{state}_{orientation}.png")
                slots.append(overlay)
                labels.append(f"{machine}\n{state}\n{orientation}")

    # Three complete rows: two pieces for each S/E/N/W facing.
    for state, color in ACTIVE_STATES:
        parts = synth_parts(state, color)
        slots.extend(parts)
        for facing, _, _, _, _ in FACINGS:
            labels.extend((f"synth {state}\n{facing} primary", f"synth {state}\n{facing} extension"))

    if len(slots) != 48:
        raise ValueError(f"Expected 48 overlay cells, got {len(slots)}")

    tilesheet = Image.new("RGBA", (128 * 8, 256 * 6), (0, 0, 0, 0))
    for index, overlay in enumerate(slots):
        tilesheet.alpha_composite(overlay, ((index % 8) * 128, (index // 8) * 256))
    tilesheet.save(OUTPUT / "kcp_lab_equipment_leds_01.png")

    # Technical contact sheet: every transparent cell enlarged over gray.
    cell_width = 160
    cell_height = 190
    contact = Image.new("RGBA", (cell_width * 8, cell_height * 6), (28, 30, 33, 255))
    font = ImageFont.load_default()
    for index, overlay in enumerate(slots):
        cell = Image.new("RGBA", (cell_width, cell_height), (43, 46, 50, 255))
        preview = overlay.resize((96, 192), Image.Resampling.NEAREST).crop((0, 80, 96, 176))
        cell.alpha_composite(preview, (32, 62))
        draw = ImageDraw.Draw(cell)
        draw.multiline_text((7, 7), labels[index], font=font, fill=(225, 225, 225, 255), spacing=2)
        draw.rectangle((0, 0, cell_width - 1, cell_height - 1), outline=(78, 82, 88, 255))
        contact.alpha_composite(cell, ((index % 8) * cell_width, (index // 8) * cell_height))
    contact.save(OUTPUT / "overlay-layout.png")
    build_synth_reconstruction()


if __name__ == "__main__":
    main()
