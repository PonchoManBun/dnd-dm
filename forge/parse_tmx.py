#!/usr/bin/env python3
"""Parse DawnLike .tmx files (Tiled Map Editor XML) and extract layout patterns as ASCII grids.

Usage:
    python3 forge/parse_tmx.py                          # Parse all TMX files
    python3 forge/parse_tmx.py Town.tmx                 # Parse specific file
    python3 forge/parse_tmx.py --output forge/reference_maps/  # Save output files
"""

import argparse
import os
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional


# Tiled stores flip flags in the upper bits of tile GIDs.
# We must mask these off to get the actual tile ID.
FLIPPED_HORIZONTALLY_FLAG = 0x80000000
FLIPPED_VERTICALLY_FLAG   = 0x40000000
FLIPPED_DIAGONALLY_FLAG   = 0x20000000
FLIP_MASK = FLIPPED_HORIZONTALLY_FLAG | FLIPPED_VERTICALLY_FLAG | FLIPPED_DIAGONALLY_FLAG

TMX_DIR = Path("/home/jetson/dnd-dm/game/art/DawnLike/Examples")

# ASCII legend characters
CHAR_WALL      = '#'
CHAR_FLOOR     = '.'
CHAR_DOOR      = 'D'
CHAR_FURNITURE = 'F'
CHAR_CHARACTER = 'C'
CHAR_TREE      = 'T'
CHAR_GROUND    = '.'
CHAR_PIT       = 'P'
CHAR_ITEM      = 'I'
CHAR_EMPTY     = ' '

LEGEND = f"""\
Legend:
  {CHAR_WALL}  = Wall
  {CHAR_FLOOR}  = Floor / Ground
  {CHAR_DOOR}  = Door
  {CHAR_FURNITURE}  = Furniture / Decor
  {CHAR_CHARACTER}  = Character (Player / NPC / Monster)
  {CHAR_TREE}  = Tree
  P  = Pit / Trap
  {CHAR_ITEM}  = Item (Chest / Money / Weapon / etc.)
  (space) = Empty / Transparent"""

# Classify tileset names into categories.
# Keys are substrings matched against the lowercased tileset name.
# Order matters: first match wins.
TILESET_CATEGORIES: list[tuple[str, str]] = [
    # Walls
    ("wall",       "wall"),
    ("fence",      "wall"),
    # Floors
    ("floor",      "floor"),
    ("tile",       "floor"),   # "Tile" tileset in Underworld is floor-like
    # Doors
    ("door",       "door"),
    # Pits
    ("pit",        "pit"),
    # Decor / Furniture
    ("decor",      "decor"),
    # Ground (outdoor)
    ("ground",     "ground"),
    # Trees
    ("tree",       "tree"),
    # Characters (players, NPCs, monsters)
    ("player",     "character"),
    ("humanoid",   "character"),
    ("cat",        "character"),
    ("quadraped",  "character"),
    ("pest",       "character"),
    ("rodent",     "character"),
    ("undead",     "character"),
    ("demon",      "character"),
    ("dog",        "character"),
    ("elemental",  "character"),
    ("misc",       "character"),  # Misc0 in Characters/
    ("avian",      "character"),
    # Items
    ("chest",      "item"),
    ("container",  "item"),
    ("money",      "item"),
    ("food",       "item"),
    ("ore",        "item"),
    ("longwep",    "item"),
    ("shortwep",   "item"),
    ("book",       "item"),
    ("amulet",     "item"),
    ("ring",       "item"),
    ("scroll",     "item"),
    ("potion",     "item"),
    ("shield",     "item"),
    ("armor",      "item"),
    ("hat",        "item"),
    ("boot",       "item"),
]

# Map category -> ASCII character
CATEGORY_TO_CHAR: dict[str, str] = {
    "wall":      CHAR_WALL,
    "floor":     CHAR_FLOOR,
    "door":      CHAR_DOOR,
    "decor":     CHAR_FURNITURE,
    "ground":    CHAR_GROUND,
    "character": CHAR_CHARACTER,
    "tree":      CHAR_TREE,
    "pit":       CHAR_PIT,
    "item":      CHAR_ITEM,
}


@dataclass
class Tileset:
    """A tileset definition from a TMX file."""
    firstgid: int
    name: str
    tile_count: int  # computed from image dimensions
    image_source: str
    category: str    # classified category


@dataclass
class Layer:
    """A single tile layer."""
    name: str
    width: int
    height: int
    data: list[list[int]]  # 2D grid of raw tile GIDs (with flip flags stripped)


@dataclass
class TmxMap:
    """Parsed TMX map."""
    source_file: str
    width: int
    height: int
    tile_width: int
    tile_height: int
    tilesets: list[Tileset]
    layers: list[Layer]


def classify_tileset(name: str) -> str:
    """Classify a tileset by name into a rendering category."""
    name_lower = name.lower()
    for substr, category in TILESET_CATEGORIES:
        if substr in name_lower:
            return category
    # Unknown tileset -- treat as floor (safe default for base layers)
    return "floor"


def compute_tile_count(image_width: int, image_height: int, tile_size: int) -> int:
    """Compute number of tiles in a tileset image."""
    cols = image_width // tile_size
    rows = image_height // tile_size
    return cols * rows


def parse_tmx(filepath: Path) -> TmxMap:
    """Parse a .tmx file and return a TmxMap."""
    tree = ET.parse(filepath)
    root = tree.getroot()

    map_width = int(root.attrib["width"])
    map_height = int(root.attrib["height"])
    tile_width = int(root.attrib["tilewidth"])
    tile_height = int(root.attrib["tileheight"])

    # Parse tilesets
    tilesets: list[Tileset] = []
    for ts_elem in root.findall("tileset"):
        firstgid = int(ts_elem.attrib["firstgid"])
        name = ts_elem.attrib["name"]
        ts_tile_w = int(ts_elem.attrib.get("tilewidth", tile_width))
        ts_tile_h = int(ts_elem.attrib.get("tileheight", tile_height))

        img_elem = ts_elem.find("image")
        if img_elem is not None:
            img_source = img_elem.attrib["source"]
            img_w = int(img_elem.attrib["width"])
            img_h = int(img_elem.attrib["height"])
            tile_count = compute_tile_count(img_w, img_h, ts_tile_w)
        else:
            img_source = ""
            tile_count = 0

        category = classify_tileset(name)
        tilesets.append(Tileset(
            firstgid=firstgid,
            name=name,
            tile_count=tile_count,
            image_source=img_source,
            category=category,
        ))

    # Sort tilesets by firstgid (they usually are, but be safe)
    tilesets.sort(key=lambda ts: ts.firstgid)

    # Parse layers
    layers: list[Layer] = []
    for layer_elem in root.findall("layer"):
        layer_name = layer_elem.attrib["name"]
        layer_w = int(layer_elem.attrib["width"])
        layer_h = int(layer_elem.attrib["height"])

        data_elem = layer_elem.find("data")
        if data_elem is None or data_elem.text is None:
            continue

        # Parse CSV tile data, stripping flip flags
        raw_text = data_elem.text.strip()
        all_values: list[int] = []
        for token in raw_text.split(","):
            token = token.strip()
            if token:
                raw_gid = int(token)
                # Strip flip flags to get the actual tile ID
                gid = raw_gid & ~FLIP_MASK
                all_values.append(gid)

        # Reshape into 2D grid
        grid: list[list[int]] = []
        for row in range(layer_h):
            start = row * layer_w
            end = start + layer_w
            grid.append(all_values[start:end])

        layers.append(Layer(name=layer_name, width=layer_w, height=layer_h, data=grid))

    return TmxMap(
        source_file=str(filepath),
        width=map_width,
        height=map_height,
        tile_width=tile_width,
        tile_height=tile_height,
        tilesets=tilesets,
        layers=layers,
    )


def resolve_tileset(gid: int, tilesets: list[Tileset]) -> Optional[Tileset]:
    """Find which tileset a given tile GID belongs to.

    Tilesets are sorted by firstgid. A GID belongs to the tileset with the
    highest firstgid that is <= the GID and where the GID is within range.
    """
    if gid == 0:
        return None

    result: Optional[Tileset] = None
    for ts in tilesets:
        if ts.firstgid <= gid:
            result = ts
        else:
            break
    return result


def gid_to_char(gid: int, tilesets: list[Tileset]) -> str:
    """Convert a tile GID to its ASCII character representation."""
    if gid == 0:
        return CHAR_EMPTY

    ts = resolve_tileset(gid, tilesets)
    if ts is None:
        return CHAR_EMPTY

    return CATEGORY_TO_CHAR.get(ts.category, '?')


def render_ascii_grid(layer: Layer, tilesets: list[Tileset]) -> list[str]:
    """Render a layer as an ASCII grid. Returns list of strings (one per row)."""
    lines: list[str] = []
    for row in layer.data:
        line = "".join(gid_to_char(gid, tilesets) for gid in row)
        lines.append(line)
    return lines


def merge_layers(layers: list[Layer], tilesets: list[Tileset]) -> list[str]:
    """Merge all layers into a single ASCII grid.

    Later layers (sprites) overlay earlier layers (tiles).
    Non-empty sprite tiles take priority over base tiles.
    """
    if not layers:
        return []

    height = layers[0].height
    width = layers[0].width

    # Start with empty grid
    merged: list[list[str]] = [[CHAR_EMPTY] * width for _ in range(height)]

    for layer in layers:
        for y, row in enumerate(layer.data):
            for x, gid in enumerate(row):
                if gid == 0:
                    continue
                ch = gid_to_char(gid, tilesets)
                if ch != CHAR_EMPTY:
                    merged[y][x] = ch

    return ["".join(row) for row in merged]


def format_grid_with_border(lines: list[str], title: str, width: int) -> str:
    """Format an ASCII grid with a border and row/column numbers."""
    output_parts: list[str] = []
    output_parts.append(f"  {title}")
    output_parts.append(f"  {'=' * len(title)}")

    # Column numbers (tens)
    if width >= 10:
        tens_line = "    "
        for x in range(width):
            tens_line += str(x // 10) if x >= 10 else " "
        output_parts.append(tens_line)

    # Column numbers (ones)
    ones_line = "    "
    for x in range(width):
        ones_line += str(x % 10)
    output_parts.append(ones_line)

    # Top border
    output_parts.append(f"   +{'-' * width}+")

    # Grid rows with row numbers
    for y, line in enumerate(lines):
        output_parts.append(f"{y:2d} |{line}|")

    # Bottom border
    output_parts.append(f"   +{'-' * width}+")

    return "\n".join(output_parts)


def format_map_output(tmx: TmxMap) -> str:
    """Generate the complete formatted output for a parsed TMX map."""
    parts: list[str] = []

    # Header
    basename = os.path.basename(tmx.source_file)
    parts.append(f"{'=' * 60}")
    parts.append(f"  TMX Map: {basename}")
    parts.append(f"{'=' * 60}")
    parts.append(f"  Source: {tmx.source_file}")
    parts.append(f"  Dimensions: {tmx.width}x{tmx.height} tiles ({tmx.width * tmx.tile_width}x{tmx.height * tmx.tile_height} pixels)")
    parts.append(f"  Tile size: {tmx.tile_width}x{tmx.tile_height}")
    parts.append(f"  Layers: {len(tmx.layers)}")
    parts.append("")

    # Tileset summary
    parts.append("  Tilesets:")
    parts.append("  " + "-" * 56)
    parts.append(f"  {'Name':<16} {'FirstGID':>8}  {'Count':>5}  {'Category':<12} Source")
    parts.append("  " + "-" * 56)
    for ts in tmx.tilesets:
        src_short = os.path.basename(ts.image_source) if ts.image_source else "(none)"
        parts.append(f"  {ts.name:<16} {ts.firstgid:>8}  {ts.tile_count:>5}  {ts.category:<12} {src_short}")
    parts.append("")

    # Render each layer
    for layer in tmx.layers:
        ascii_lines = render_ascii_grid(layer, tmx.tilesets)
        parts.append(format_grid_with_border(ascii_lines, f"Layer: {layer.name}", layer.width))
        parts.append("")

    # Merged view (only if we have more than one layer)
    if len(tmx.layers) > 1:
        merged = merge_layers(tmx.layers, tmx.tilesets)
        parts.append(format_grid_with_border(merged, "Merged View (all layers)", tmx.width))
        parts.append("")
    elif len(tmx.layers) == 1:
        # Single layer maps -- the layer IS the merged view, label it as such
        ascii_lines = render_ascii_grid(tmx.layers[0], tmx.tilesets)
        parts.append(format_grid_with_border(ascii_lines, "Merged View (single layer)", tmx.width))
        parts.append("")

    # Legend
    parts.append(LEGEND)
    parts.append("")

    # Tile category statistics
    parts.append("  Tile Statistics (merged):")
    parts.append("  " + "-" * 30)
    if len(tmx.layers) > 1:
        merged_lines = merge_layers(tmx.layers, tmx.tilesets)
    elif len(tmx.layers) == 1:
        merged_lines = render_ascii_grid(tmx.layers[0], tmx.tilesets)
    else:
        merged_lines = []

    counts: dict[str, int] = {}
    total = 0
    for line in merged_lines:
        for ch in line:
            total += 1
            label = {
                CHAR_WALL: "Wall",
                CHAR_FLOOR: "Floor/Ground",
                CHAR_DOOR: "Door",
                CHAR_FURNITURE: "Furniture",
                CHAR_CHARACTER: "Character",
                CHAR_TREE: "Tree",
                CHAR_PIT: "Pit",
                CHAR_ITEM: "Item",
                CHAR_EMPTY: "Empty",
            }.get(ch, f"Unknown({ch})")
            counts[label] = counts.get(label, 0) + 1

    for label in ["Wall", "Floor/Ground", "Door", "Furniture", "Character", "Tree", "Pit", "Item", "Empty"]:
        count = counts.get(label, 0)
        if count > 0:
            pct = 100.0 * count / total if total > 0 else 0
            parts.append(f"  {label:<16} {count:>4} ({pct:5.1f}%)")
    # Show any unknowns
    for label, count in sorted(counts.items()):
        if label not in ["Wall", "Floor/Ground", "Door", "Furniture", "Character", "Tree", "Pit", "Item", "Empty"]:
            pct = 100.0 * count / total if total > 0 else 0
            parts.append(f"  {label:<16} {count:>4} ({pct:5.1f}%)")
    parts.append("")

    return "\n".join(parts)


def find_tmx_files(names: Optional[list[str]] = None) -> list[Path]:
    """Find TMX files to process.

    If names are given, resolve them relative to the TMX directory.
    Otherwise, return all .tmx files in the directory.
    """
    if names:
        files: list[Path] = []
        for name in names:
            # Accept bare name or full path
            p = Path(name)
            if not p.is_absolute():
                p = TMX_DIR / p
            if not p.suffix:
                p = p.with_suffix(".tmx")
            if p.exists():
                files.append(p)
            else:
                print(f"Warning: TMX file not found: {p}", file=sys.stderr)
        return files
    else:
        return sorted(TMX_DIR.glob("*.tmx"))


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Parse DawnLike .tmx files and extract ASCII layout grids.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""Examples:
  python3 forge/parse_tmx.py                              # Parse all TMX files
  python3 forge/parse_tmx.py Town.tmx                     # Parse specific file
  python3 forge/parse_tmx.py Town.tmx Dungeon.tmx         # Parse multiple files
  python3 forge/parse_tmx.py --output forge/reference_maps/  # Save to files""",
    )
    parser.add_argument(
        "files",
        nargs="*",
        help="TMX files to parse (names or paths). If omitted, parses all in Examples/.",
    )
    parser.add_argument(
        "--output", "-o",
        type=str,
        default=None,
        help="Output directory. When set, writes {name}_layout.txt files instead of printing.",
    )

    args = parser.parse_args()
    tmx_files = find_tmx_files(args.files if args.files else None)

    if not tmx_files:
        print("No TMX files found.", file=sys.stderr)
        sys.exit(1)

    output_dir: Optional[Path] = None
    if args.output:
        output_dir = Path(args.output)
        output_dir.mkdir(parents=True, exist_ok=True)

    for filepath in tmx_files:
        tmx = parse_tmx(filepath)
        output_text = format_map_output(tmx)

        if output_dir:
            stem = filepath.stem
            out_path = output_dir / f"{stem}_layout.txt"
            out_path.write_text(output_text, encoding="utf-8")
            print(f"Wrote: {out_path}")
        else:
            print(output_text)


if __name__ == "__main__":
    main()
