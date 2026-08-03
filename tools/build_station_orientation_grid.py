"""Build coordinate grids for reviewing state-light placement in every orientation."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art-source" / "game-previews" / "2x"
OUTPUT = ROOT / "art-source" / "proposals" / "station-states-v1" / "diagnostics"
MACHINES = ("centrifuge", "bio-analyzer", "synthesizer")
ORIENTATIONS = ("front-left", "rear-left", "rear-right", "front-right")


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    font = ImageFont.load_default()
    for machine in MACHINES:
        sheet = Image.new("RGBA", (512 * 4, 1024), (20, 20, 20, 255))
        for column, orientation in enumerate(ORIENTATIONS):
            source = Image.open(SOURCE / machine / f"{orientation}.png").convert("RGBA")
            image = source.resize((512, 1024), Image.Resampling.NEAREST)
            draw = ImageDraw.Draw(image)
            for coordinate in range(0, 128, 8):
                x = coordinate * 4
                draw.line((x, 0, x, 1023), fill=(0, 180, 255, 105), width=1)
                draw.text((x + 2, 2), str(coordinate), font=font, fill="white")
            for coordinate in range(0, 256, 8):
                y = coordinate * 4
                draw.line((0, y, 511, y), fill=(0, 180, 255, 105), width=1)
                draw.text((2, y + 2), str(coordinate), font=font, fill="white")
            draw.rectangle((0, 0, 511, 22), fill=(0, 0, 0, 180))
            draw.text((180, 6), orientation, font=font, fill="white")
            sheet.alpha_composite(image, (column * 512, 0))
        sheet.save(OUTPUT / f"{machine}.png")


if __name__ == "__main__":
    main()
