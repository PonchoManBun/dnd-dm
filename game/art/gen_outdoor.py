#!/usr/bin/env python3
"""
Script to process DawnLike outdoor tilesets into an outdoor tiles atlas.
Extracts all non-transparent 16x16 tiles from Ground0, Tree0, Fence, and
Floor (rows 0-2 only) and combines them into a single atlas PNG with a
coordinate JSON file.
"""

import os
import sys
import json
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

# Configuration
TILE_SIZE = 16
DAWNLIKE_OBJECTS_DIR = Path("art/DawnLike/Objects")
OUTPUT_DIR = Path("assets/generated")

# Magenta (255, 0, 255) is used as transparent color in these tilesets
MAGENTA_THRESHOLD = 0.9  # Skip tiles that are more than 90% magenta/transparent

WATERMARK = "DawnLike outdoor tileset"


def find_project_root():
    """Find the project root directory by looking for project.godot file."""
    current_dir = Path.cwd()
    for path in [current_dir] + list(current_dir.parents):
        if (path / "project.godot").exists():
            return path
    print("Warning: Could not find project.godot file. Using current directory as project root.")
    return current_dir


def change_to_project_root():
    """Change to the project root directory."""
    project_root = find_project_root()
    os.chdir(project_root)
    print(f"Changed to project root: {project_root}")
    return project_root


def is_tile_empty(tile):
    """
    Check if a tile is mostly magenta (transparency color) or fully transparent.
    Returns True if the tile should be skipped.
    """
    tile_rgba = tile.convert('RGBA')
    pixels = list(tile_rgba.getdata())
    total_pixels = len(pixels)

    # Count pixels that are magenta (255, 0, 255) or fully transparent
    empty_count = 0
    for pixel in pixels:
        r, g, b, a = pixel
        if a == 0:
            empty_count += 1
        elif r >= 250 and g <= 5 and b >= 250:
            empty_count += 1

    empty_ratio = empty_count / total_pixels
    return empty_ratio >= MAGENTA_THRESHOLD


def extract_tiles_from_image(image_path, prefix, max_rows=None):
    """Extract all non-empty 16x16 tiles from an image.

    Args:
        image_path: Path to the source image.
        prefix: Name prefix for extracted tiles.
        max_rows: If set, only extract tiles from rows 0 to max_rows-1.
    """
    print(f"Processing: {image_path}")
    image = Image.open(image_path)
    width, height = image.size
    cols = width // TILE_SIZE
    rows = height // TILE_SIZE

    if max_rows is not None:
        rows = min(rows, max_rows)
        print(f"  Image size: {width}x{height}, Grid: {cols}x{height // TILE_SIZE} (extracting rows 0-{max_rows - 1})")
    else:
        print(f"  Image size: {width}x{height}, Grid: {cols}x{rows}")

    tiles = []
    skipped = 0
    tile_index = 0

    for row in range(rows):
        for col in range(cols):
            left = col * TILE_SIZE
            top = row * TILE_SIZE
            right = left + TILE_SIZE
            bottom = top + TILE_SIZE

            tile = image.crop((left, top, right, bottom))

            if is_tile_empty(tile):
                skipped += 1
                tile_index += 1
                continue

            # Convert to RGBA, replacing magenta with transparency
            tile_rgba = tile.convert('RGBA')
            pixel_data = list(tile_rgba.getdata())
            new_pixels = []
            for pixel in pixel_data:
                r, g, b, a = pixel
                if r >= 250 and g <= 5 and b >= 250:
                    new_pixels.append((0, 0, 0, 0))
                else:
                    new_pixels.append(pixel)
            tile_rgba.putdata(new_pixels)

            sprite_name = f"{prefix}-{tile_index}"
            tiles.append((sprite_name, tile_rgba))
            tile_index += 1

    print(f"  Extracted {len(tiles)} tiles (skipped {skipped} empty/magenta tiles)")
    return tiles


def calculate_optimal_atlas_size(num_sprites):
    """Calculate the optimal atlas size for the given number of sprites."""
    sprites_per_row = math.ceil(math.sqrt(num_sprites))

    atlas_width = sprites_per_row * TILE_SIZE
    atlas_height = math.ceil(num_sprites / sprites_per_row) * TILE_SIZE

    # Round up to next power of 2 for GPU compatibility
    def next_power_of_2(n):
        return 1 << (n - 1).bit_length()

    atlas_width = next_power_of_2(atlas_width)
    atlas_height = next_power_of_2(atlas_height)

    # Ensure minimum atlas size
    MIN_ATLAS_SIZE = 128
    atlas_width = max(atlas_width, MIN_ATLAS_SIZE)
    atlas_height = max(atlas_height, MIN_ATLAS_SIZE)

    return atlas_width, atlas_height, sprites_per_row


def create_atlas(all_tiles):
    """Create the sprite atlas and coordinate JSON."""
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # Add a debug tile (orange)
    debug_tile = Image.new('RGBA', (TILE_SIZE, TILE_SIZE), (255, 165, 0, 255))
    all_tiles.append(("debug", debug_tile))

    atlas_width, atlas_height, sprites_per_row = calculate_optimal_atlas_size(len(all_tiles))

    print(f"Creating outdoor atlas with {len(all_tiles)} sprites")
    print(f"Atlas dimensions: {atlas_width}x{atlas_height} ({sprites_per_row} sprites per row)")

    atlas = Image.new('RGBA', (atlas_width, atlas_height), (0, 0, 0, 0))
    coordinates = {}

    for i, (sprite_name, sprite_image) in enumerate(all_tiles):
        x = (i % sprites_per_row) * TILE_SIZE
        y = (i // sprites_per_row) * TILE_SIZE
        atlas.paste(sprite_image, (x, y))
        coordinates[sprite_name] = [x, y]

    # Add watermark
    draw = ImageDraw.Draw(atlas)
    font = ImageFont.load_default()
    text = WATERMARK
    try:
        bbox = draw.textbbox((0, 0), text, font=font)
        text_w, text_h = bbox[2] - bbox[0], bbox[3] - bbox[1]
    except (AttributeError, ValueError):
        try:
            text_w, text_h = font.getsize(text)
        except AttributeError:
            # Fallback for bitmap fonts that lack both methods
            text_w, text_h = len(text) * 6, 10
    margin = 4
    wx = atlas_width - text_w - margin
    wy = atlas_height - text_h - margin
    for dx in [-1, 0, 1]:
        for dy in [-1, 0, 1]:
            if dx or dy:
                draw.text((wx + dx, wy + dy), text, font=font, fill=(0, 0, 0, 255))
    draw.text((wx, wy), text, font=font, fill=(255, 255, 255, 255))

    atlas_path = OUTPUT_DIR / "outdoor_tiles.png"
    atlas.save(atlas_path, 'PNG')

    json_data = {
        "tileSize": TILE_SIZE,
        "sprites": coordinates
    }
    json_path = OUTPUT_DIR / "outdoor_tiles.json"
    with open(json_path, 'w') as f:
        json.dump(json_data, f, indent=2)

    print(f"Created atlas at {atlas_path}")
    print(f"Created coordinate data at {json_path}")
    return atlas_width, atlas_height, sprites_per_row


def main():
    """Main function to process DawnLike outdoor tilesets."""
    print("DawnLike Outdoor Tile Processor")
    print("=" * 40)

    # Change to project root directory
    change_to_project_root()
    print()

    # Check if DawnLike Objects directory exists
    if not DAWNLIKE_OBJECTS_DIR.exists():
        print(f"Error: DawnLike Objects directory not found: {DAWNLIKE_OBJECTS_DIR}")
        sys.exit(1)

    # Define source files
    ground0 = DAWNLIKE_OBJECTS_DIR / "Ground0.png"
    tree0 = DAWNLIKE_OBJECTS_DIR / "Tree0.png"
    fence = DAWNLIKE_OBJECTS_DIR / "Fence.png"
    floor_img = DAWNLIKE_OBJECTS_DIR / "Floor.png"

    for f in [ground0, tree0, fence, floor_img]:
        if not f.exists():
            print(f"Error: Required file not found: {f}")
            sys.exit(1)

    print("Found all required DawnLike outdoor tile files")
    print()

    # Extract tiles from all source images
    all_tiles = []

    # Ground0.png - grass, dirt, stone ground tiles
    tiles_ground = extract_tiles_from_image(ground0, "ground0")
    all_tiles.extend(tiles_ground)
    print()

    # Tree0.png - trees, bushes, stumps
    tiles_tree = extract_tiles_from_image(tree0, "tree0")
    all_tiles.extend(tiles_tree)
    print()

    # Fence.png - fences, gates
    tiles_fence = extract_tiles_from_image(fence, "fence")
    all_tiles.extend(tiles_fence)
    print()

    # Floor.png - only rows 0-2 (base tiles, not connectivity variants)
    tiles_floor = extract_tiles_from_image(floor_img, "outdoor-floor", max_rows=3)
    all_tiles.extend(tiles_floor)
    print()

    print(f"Total tiles extracted: {len(all_tiles)}")
    print()

    # Create atlas
    if all_tiles:
        result = create_atlas(all_tiles)
        if result:
            print("Atlas generation complete!")
        else:
            print("Atlas generation failed!")
            sys.exit(1)
    else:
        print("No tiles found!")
        sys.exit(1)


if __name__ == "__main__":
    main()
