#!/usr/bin/env python3
"""
Script to process IndoorRPG tilesets into an indoor tiles atlas.
Extracts all non-transparent/non-magenta 16x16 tiles and combines them
into a single atlas PNG with a coordinate JSON file.
"""

import os
import sys
import json
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

# Configuration
TILE_SIZE = 16
INDOOR_DIR = Path("art/IndoorRPG")
OUTPUT_DIR = Path("assets/generated")

# Magenta (255, 0, 255) is used as transparent color in these tilesets
MAGENTA_THRESHOLD = 0.9  # Skip tiles that are more than 90% magenta/transparent

WATERMARK = "IndoorRPG tileset"


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


def extract_tiles_from_image(image_path, prefix):
    """Extract all non-empty 16x16 tiles from an image."""
    print(f"Processing: {image_path}")
    image = Image.open(image_path)
    width, height = image.size
    cols = width // TILE_SIZE
    rows = height // TILE_SIZE
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

    print(f"Creating indoor atlas with {len(all_tiles)} sprites")
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
    except AttributeError:
        text_w, text_h = font.getsize(text)
    margin = 4
    wx = atlas_width - text_w - margin
    wy = atlas_height - text_h - margin
    for dx in [-1, 0, 1]:
        for dy in [-1, 0, 1]:
            if dx or dy:
                draw.text((wx + dx, wy + dy), text, font=font, fill=(0, 0, 0, 255))
    draw.text((wx, wy), text, font=font, fill=(255, 255, 255, 255))

    atlas_path = OUTPUT_DIR / "indoor_tiles.png"
    atlas.save(atlas_path, 'PNG')

    json_data = {
        "tileSize": TILE_SIZE,
        "sprites": coordinates
    }
    json_path = OUTPUT_DIR / "indoor_tiles.json"
    with open(json_path, 'w') as f:
        json.dump(json_data, f, indent=2)

    print(f"Created atlas at {atlas_path}")
    print(f"Created coordinate data at {json_path}")
    return True


def main():
    """Main function to process IndoorRPG tilesets."""
    print("IndoorRPG Tile Processor")
    print("=" * 40)

    # Change to project root directory
    change_to_project_root()
    print()

    # Check if IndoorRPG directory exists
    if not INDOOR_DIR.exists():
        print(f"Error: IndoorRPG directory not found: {INDOOR_DIR}")
        sys.exit(1)

    # Define source files
    main_tileset = INDOOR_DIR / "tilesetformattedupdate1.png"
    extra_tileset = INDOOR_DIR / "16x16extratiles.png"

    for f in [main_tileset, extra_tileset]:
        if not f.exists():
            print(f"Error: Required file not found: {f}")
            sys.exit(1)

    print(f"Found all required IndoorRPG tile files")
    print()

    # Extract tiles from both source images
    all_tiles = []

    tiles_main = extract_tiles_from_image(main_tileset, "indoor")
    all_tiles.extend(tiles_main)
    print()

    tiles_extra = extract_tiles_from_image(extra_tileset, "indoor-extra")
    all_tiles.extend(tiles_extra)
    print()

    print(f"Total tiles extracted: {len(all_tiles)}")
    print()

    # Create atlas
    if all_tiles:
        success = create_atlas(all_tiles)
        if success:
            print("Atlas generation complete!")
        else:
            print("Atlas generation failed!")
            sys.exit(1)
    else:
        print("No tiles found!")
        sys.exit(1)


if __name__ == "__main__":
    main()
