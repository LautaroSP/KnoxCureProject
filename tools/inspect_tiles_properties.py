"""Read TileZed .tiles files and print selected tileset properties."""

from __future__ import annotations

import argparse
import json
import re
import struct
from pathlib import Path


def read_int(data: bytes, offset: int) -> tuple[int, int]:
    return struct.unpack_from("<I", data, offset)[0], offset + 4


def read_line(data: bytes, offset: int) -> tuple[str, int]:
    end = data.index(b"\n", offset)
    return data[offset:end].decode("utf-8"), end + 1


def parse(path: Path) -> list[dict]:
    data = path.read_bytes()
    if data[:4] != b"tdef":
        raise ValueError("Not a TileZed tdef file")
    offset = 4
    version, offset = read_int(data, offset)
    sheet_count, offset = read_int(data, offset)
    sheets = []

    for _ in range(sheet_count):
        name, offset = read_line(data, offset)
        image, offset = read_line(data, offset)
        columns, offset = read_int(data, offset)
        rows, offset = read_int(data, offset)
        scale, offset = read_int(data, offset)
        tile_count, offset = read_int(data, offset)
        tiles = []
        for index in range(tile_count):
            property_count, offset = read_int(data, offset)
            properties = {}
            for _ in range(property_count):
                key, offset = read_line(data, offset)
                value, offset = read_line(data, offset)
                properties[key] = value
            tiles.append({"index": index, "properties": properties})
        sheets.append(
            {
                "version": version,
                "name": name,
                "image": image,
                "columns": columns,
                "rows": rows,
                "scale": scale,
                "tiles": tiles,
            }
        )
    return sheets


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("path", type=Path)
    parser.add_argument("--sheet")
    parser.add_argument("--property")
    parser.add_argument("--match-value")
    args = parser.parse_args()

    sheets = parse(args.path)
    if args.sheet:
        sheets = [sheet for sheet in sheets if sheet["name"] == args.sheet]
    if args.property:
        for sheet in sheets:
            sheet["tiles"] = [
                tile for tile in sheet["tiles"] if args.property in tile["properties"]
            ]
    if args.match_value:
        pattern = re.compile(args.match_value, re.IGNORECASE)
        for sheet in sheets:
            sheet["tiles"] = [
                tile
                for tile in sheet["tiles"]
                if any(pattern.search(value) for value in tile["properties"].values())
            ]
        sheets = [sheet for sheet in sheets if sheet["tiles"]]
    print(json.dumps(sheets, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
