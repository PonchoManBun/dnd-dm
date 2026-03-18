#!/usr/bin/env python3
"""Forge content validator.

Validates generated JSON content against the formats consumed by the game.

Usage:
    python3 forge/validate.py dungeon path/to/dungeon.json
    python3 forge/validate.py npc path/to/npcs.json
    python3 forge/validate.py quest path/to/quest.json
"""

import argparse
import csv
import json
import sys
from pathlib import Path
from typing import Any

PROJECT_ROOT = Path(__file__).resolve().parent.parent

MONSTERS_PATH = PROJECT_ROOT / "game" / "assets" / "data" / "dnd_monsters.json"
ITEMS_PATH = PROJECT_ROOT / "game" / "assets" / "data" / "items.csv"

VALID_ROOM_TYPES = {"entrance", "combat", "treasure", "trap", "boss", "empty"}
VALID_QUEST_TYPES = {"main_quest", "side_quest", "encounter", "lore"}
VALID_ATTITUDES = {"hostile", "unfriendly", "indifferent", "friendly", "helpful"}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _load_monster_slugs() -> set[str]:
    """Return the set of valid monster slugs from dnd_monsters.json."""
    if not MONSTERS_PATH.exists():
        return set()
    with open(MONSTERS_PATH, "r") as f:
        data = json.load(f)
    return set(data.keys())


def _load_item_slugs() -> set[str]:
    """Return the set of valid item slugs from items.csv.

    Slug = first column (name) lowercased with spaces replaced by underscores.
    """
    if not ITEMS_PATH.exists():
        return set()
    slugs: set[str] = set()
    with open(ITEMS_PATH, "r") as f:
        reader = csv.reader(f)
        header = next(reader, None)  # skip header
        if header is None:
            return slugs
        for row in reader:
            if row:
                name = row[0].strip()
                slug = name.lower().replace(" ", "_")
                slugs.add(slug)
    return slugs


class ValidationResult:
    """Accumulates validation errors."""

    def __init__(self, file_path: str, content_type: str) -> None:
        self.file_path = file_path
        self.content_type = content_type
        self.errors: list[str] = []

    def error(self, msg: str) -> None:
        self.errors.append(msg)

    @property
    def ok(self) -> bool:
        return len(self.errors) == 0

    def report(self) -> None:
        if self.ok:
            print(f"PASS: {self.content_type} validation passed for {self.file_path}")
        else:
            print(f"FAIL: {self.content_type} validation failed for {self.file_path}")
            for i, err in enumerate(self.errors, 1):
                print(f"  [{i}] {err}")
            print(f"  Total errors: {len(self.errors)}")


def _check_type(result: ValidationResult, obj: Any, key: str, expected: type,
                context: str) -> bool:
    """Check that obj[key] exists and has the expected type. Returns True if valid."""
    if key not in obj:
        result.error(f"{context}: missing required field '{key}'")
        return False
    if not isinstance(obj[key], expected):
        result.error(
            f"{context}: field '{key}' should be {expected.__name__}, "
            f"got {type(obj[key]).__name__}"
        )
        return False
    return True


def _check_optional_type(result: ValidationResult, obj: Any, key: str,
                         expected: type, context: str) -> bool:
    """Check that obj[key], if present, has the expected type."""
    if key not in obj:
        return True
    if not isinstance(obj[key], expected):
        result.error(
            f"{context}: field '{key}' should be {expected.__name__}, "
            f"got {type(obj[key]).__name__}"
        )
        return False
    return True


# ---------------------------------------------------------------------------
# Dungeon validation
# ---------------------------------------------------------------------------

def _validate_trap(result: ValidationResult, trap: dict, context: str) -> None:
    """Validate a trap dictionary."""
    _check_type(result, trap, "type", str, context)
    _check_type(result, trap, "dc", int, context)
    _check_type(result, trap, "damage_dice", int, context)
    _check_type(result, trap, "damage_sides", int, context)
    _check_type(result, trap, "damage_type", str, context)


def _validate_choice(result: ValidationResult, choice: dict, context: str) -> None:
    """Validate a choice dictionary."""
    _check_type(result, choice, "text", str, context)
    _check_type(result, choice, "action", str, context)
    _check_optional_type(result, choice, "dc", int, context)


def _validate_on_clear(result: ValidationResult, on_clear: dict, context: str) -> None:
    """Validate an on_clear dictionary."""
    _check_optional_type(result, on_clear, "narrative", str, context)
    _check_optional_type(result, on_clear, "victory", bool, context)


def _rooms_overlap(a: dict, b: dict) -> bool:
    """Check if two rooms overlap (both specified as x, y, w, h)."""
    if a["x"] >= b["x"] + b["w"] or b["x"] >= a["x"] + a["w"]:
        return False
    if a["y"] >= b["y"] + b["h"] or b["y"] >= a["y"] + a["h"]:
        return False
    return True


def validate_dungeon(file_path: str) -> ValidationResult:
    result = ValidationResult(file_path, "dungeon")

    # Load JSON
    try:
        with open(file_path, "r") as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        result.error(f"Invalid JSON: {e}")
        return result
    except FileNotFoundError:
        result.error(f"File not found: {file_path}")
        return result

    if not isinstance(data, dict):
        result.error("Top-level value must be a JSON object")
        return result

    # Top-level required keys
    _check_type(result, data, "name", str, "dungeon")
    _check_type(result, data, "description", str, "dungeon")
    if not _check_type(result, data, "floors", list, "dungeon"):
        return result

    # Load reference data for slug checks
    monster_slugs = _load_monster_slugs()
    item_slugs = _load_item_slugs()

    for fi, floor in enumerate(data["floors"]):
        fctx = f"floors[{fi}]"

        if not isinstance(floor, dict):
            result.error(f"{fctx}: must be a JSON object")
            continue

        # Required floor fields
        _check_type(result, floor, "id", str, fctx)
        _check_type(result, floor, "depth", int, fctx)
        _check_type(result, floor, "name", str, fctx)
        has_width = _check_type(result, floor, "width", int, fctx)
        has_height = _check_type(result, floor, "height", int, fctx)

        floor_w = floor.get("width", 0)
        floor_h = floor.get("height", 0)

        if not _check_type(result, floor, "rooms", list, fctx):
            continue
        _check_type(result, floor, "corridors", list, fctx)

        rooms = floor["rooms"]
        room_ids: set[int] = set()

        for ri, room in enumerate(rooms):
            rctx = f"{fctx}.rooms[{ri}]"

            if not isinstance(room, dict):
                result.error(f"{rctx}: must be a JSON object")
                continue

            # Required room fields
            has_id = _check_type(result, room, "id", int, rctx)
            _check_type(result, room, "name", str, rctx)
            has_x = _check_type(result, room, "x", int, rctx)
            has_y = _check_type(result, room, "y", int, rctx)
            has_w = _check_type(result, room, "w", int, rctx)
            has_h = _check_type(result, room, "h", int, rctx)

            if _check_type(result, room, "type", str, rctx):
                if room["type"] not in VALID_ROOM_TYPES:
                    result.error(
                        f"{rctx}: invalid room type '{room['type']}', "
                        f"must be one of {sorted(VALID_ROOM_TYPES)}"
                    )

            # Optional room fields
            _check_optional_type(result, room, "narrative", str, rctx)
            _check_optional_type(result, room, "stairs_up", bool, rctx)
            _check_optional_type(result, room, "stairs_down", bool, rctx)
            _check_optional_type(result, room, "monsters", list, rctx)
            _check_optional_type(result, room, "items", list, rctx)
            _check_optional_type(result, room, "trap", dict, rctx)
            _check_optional_type(result, room, "choices", list, rctx)
            _check_optional_type(result, room, "on_clear", dict, rctx)

            # Track room IDs
            if has_id:
                rid = room["id"]
                if rid != ri:
                    result.error(
                        f"{rctx}: room id should be {ri} (sequential starting at 0), got {rid}"
                    )
                if rid in room_ids:
                    result.error(f"{rctx}: duplicate room id {rid}")
                room_ids.add(rid)

            # Spatial checks require valid dimensions
            if not (has_x and has_y and has_w and has_h):
                continue

            rx, ry, rw, rh = room["x"], room["y"], room["w"], room["h"]

            # Room must fit within floor bounds
            if has_width and has_height:
                if rx < 0 or ry < 0 or rx + rw > floor_w or ry + rh > floor_h:
                    result.error(
                        f"{rctx}: room ({rx},{ry},{rw},{rh}) extends beyond "
                        f"floor bounds ({floor_w}x{floor_h})"
                    )

            # Stairs size check: rooms with stairs need at least 4x4
            # stairs_up placed at (x+1, y+1), stairs_down at (x+w-2, y+h-2)
            if room.get("stairs_up", False) and (rw < 4 or rh < 4):
                result.error(
                    f"{rctx}: room has stairs_up but is only {rw}x{rh} "
                    f"(needs at least 4x4)"
                )
            if room.get("stairs_down", False) and (rw < 4 or rh < 4):
                result.error(
                    f"{rctx}: room has stairs_down but is only {rw}x{rh} "
                    f"(needs at least 4x4)"
                )

            # Validate monsters
            for mi, monster in enumerate(room.get("monsters", [])):
                mctx = f"{rctx}.monsters[{mi}]"
                if not isinstance(monster, dict):
                    result.error(f"{mctx}: must be a JSON object")
                    continue
                _check_type(result, monster, "slug", str, mctx)
                mx_ok = _check_type(result, monster, "x", int, mctx)
                my_ok = _check_type(result, monster, "y", int, mctx)

                # Slug validation
                if "slug" in monster and monster_slugs:
                    if monster["slug"] not in monster_slugs:
                        result.error(
                            f"{mctx}: unknown monster slug '{monster['slug']}'"
                        )

                # Position within room bounds
                if mx_ok and my_ok:
                    mx, my = monster["x"], monster["y"]
                    if not (rx <= mx < rx + rw and ry <= my < ry + rh):
                        result.error(
                            f"{mctx}: monster at ({mx},{my}) is outside "
                            f"room bounds ({rx},{ry})-({rx+rw-1},{ry+rh-1})"
                        )

            # Validate items
            for ii, item in enumerate(room.get("items", [])):
                ictx = f"{rctx}.items[{ii}]"
                if not isinstance(item, dict):
                    result.error(f"{ictx}: must be a JSON object")
                    continue
                _check_type(result, item, "slug", str, ictx)
                ix_ok = _check_type(result, item, "x", int, ictx)
                iy_ok = _check_type(result, item, "y", int, ictx)
                _check_optional_type(result, item, "quantity", int, ictx)

                # Slug validation
                if "slug" in item and item_slugs:
                    if item["slug"] not in item_slugs:
                        result.error(
                            f"{ictx}: unknown item slug '{item['slug']}'"
                        )

                # Position within room bounds
                if ix_ok and iy_ok:
                    ix, iy = item["x"], item["y"]
                    if not (rx <= ix < rx + rw and ry <= iy < ry + rh):
                        result.error(
                            f"{ictx}: item at ({ix},{iy}) is outside "
                            f"room bounds ({rx},{ry})-({rx+rw-1},{ry+rh-1})"
                        )

            # Validate trap
            if "trap" in room and isinstance(room["trap"], dict) and room["trap"]:
                _validate_trap(result, room["trap"], f"{rctx}.trap")

            # Validate choices
            for ci, choice in enumerate(room.get("choices", [])):
                cctx = f"{rctx}.choices[{ci}]"
                if not isinstance(choice, dict):
                    result.error(f"{cctx}: must be a JSON object")
                    continue
                _validate_choice(result, choice, cctx)

            # Validate on_clear
            if "on_clear" in room and isinstance(room["on_clear"], dict) and room["on_clear"]:
                _validate_on_clear(result, room["on_clear"], f"{rctx}.on_clear")

        # Check first room is entrance with stairs_up
        if rooms:
            first = rooms[0]
            if isinstance(first, dict):
                if first.get("type") != "entrance":
                    result.error(
                        f"{fctx}: first room should have type 'entrance', "
                        f"got '{first.get('type', '<missing>')}'"
                    )
                if not first.get("stairs_up", False):
                    result.error(
                        f"{fctx}: first room should have stairs_up: true"
                    )

        # Check rooms do not overlap
        for i in range(len(rooms)):
            if not isinstance(rooms[i], dict):
                continue
            for j in range(i + 1, len(rooms)):
                if not isinstance(rooms[j], dict):
                    continue
                a, b = rooms[i], rooms[j]
                if all(k in a for k in ("x", "y", "w", "h")) and \
                   all(k in b for k in ("x", "y", "w", "h")):
                    if _rooms_overlap(a, b):
                        result.error(
                            f"{fctx}: rooms[{i}] ({a['x']},{a['y']},{a['w']},{a['h']}) "
                            f"and rooms[{j}] ({b['x']},{b['y']},{b['w']},{b['h']}) overlap"
                        )

        # Validate corridors
        corridors = floor.get("corridors", [])
        if isinstance(corridors, list):
            for ci, corr in enumerate(corridors):
                cctx = f"{fctx}.corridors[{ci}]"
                if not isinstance(corr, dict):
                    result.error(f"{cctx}: must be a JSON object")
                    continue

                from_ok = _check_type(result, corr, "from", int, cctx)
                to_ok = _check_type(result, corr, "to", int, cctx)

                if from_ok and corr["from"] not in room_ids:
                    result.error(
                        f"{cctx}: 'from' references non-existent room id {corr['from']}"
                    )
                if to_ok and corr["to"] not in room_ids:
                    result.error(
                        f"{cctx}: 'to' references non-existent room id {corr['to']}"
                    )

    return result


# ---------------------------------------------------------------------------
# NPC validation
# ---------------------------------------------------------------------------

NPC_REQUIRED_FIELDS = {
    "name": str,
    "role": str,
    "personality": str,
    "knowledge": str,
    "greeting": str,
    "location": str,
}


def validate_npc(file_path: str) -> ValidationResult:
    result = ValidationResult(file_path, "npc")

    try:
        with open(file_path, "r") as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        result.error(f"Invalid JSON: {e}")
        return result
    except FileNotFoundError:
        result.error(f"File not found: {file_path}")
        return result

    if not isinstance(data, dict):
        result.error("Top-level value must be a JSON object (npc_id -> profile)")
        return result

    if not data:
        result.error("File contains no NPC profiles")
        return result

    item_slugs = _load_item_slugs()

    for npc_id, profile in data.items():
        nctx = f"npc[{npc_id}]"

        if not isinstance(profile, dict):
            result.error(f"{nctx}: value must be a JSON object")
            continue

        for field, expected_type in NPC_REQUIRED_FIELDS.items():
            _check_type(result, profile, field, expected_type, nctx)

        # Validate new Phase 2 fields (optional, backward-compatible)
        # attitude_default
        if "attitude_default" in profile:
            if not isinstance(profile["attitude_default"], str):
                result.error(f"{nctx}: 'attitude_default' should be str")
            elif profile["attitude_default"] not in VALID_ATTITUDES:
                result.error(
                    f"{nctx}: invalid attitude_default '{profile['attitude_default']}', "
                    f"must be one of {sorted(VALID_ATTITUDES)}"
                )

        # knowledge_tiers
        if "knowledge_tiers" in profile:
            kt = profile["knowledge_tiers"]
            if not isinstance(kt, dict):
                result.error(f"{nctx}: 'knowledge_tiers' should be a dict")
            else:
                for tier_key in kt:
                    if tier_key not in VALID_ATTITUDES:
                        result.error(
                            f"{nctx}: invalid knowledge_tiers key '{tier_key}', "
                            f"must be one of {sorted(VALID_ATTITUDES)}"
                        )
                    elif not isinstance(kt[tier_key], list):
                        result.error(
                            f"{nctx}: knowledge_tiers['{tier_key}'] should be a list"
                        )

        # bartering_inventory
        if "bartering_inventory" in profile:
            inv = profile["bartering_inventory"]
            if not isinstance(inv, list):
                result.error(f"{nctx}: 'bartering_inventory' should be a list")
            else:
                for ii, item in enumerate(inv):
                    ictx = f"{nctx}.bartering_inventory[{ii}]"
                    if not isinstance(item, dict):
                        result.error(f"{ictx}: must be a dict")
                        continue
                    _check_type(result, item, "slug", str, ictx)
                    if "price_gp" in item:
                        if not isinstance(item["price_gp"], (int, float)):
                            result.error(f"{ictx}: 'price_gp' should be a number")
                    # Validate slug against item registry
                    if "slug" in item and item_slugs:
                        if item["slug"] not in item_slugs:
                            result.error(f"{ictx}: unknown item slug '{item['slug']}'")

        # dialogue_style
        _check_optional_type(result, profile, "dialogue_style", str, nctx)

        # mode_prompts
        if "mode_prompts" in profile:
            mp = profile["mode_prompts"]
            if not isinstance(mp, dict):
                result.error(f"{nctx}: 'mode_prompts' should be a dict")
            else:
                for key, val in mp.items():
                    if not isinstance(val, str):
                        result.error(f"{nctx}: mode_prompts['{key}'] should be a str")

    return result


# ---------------------------------------------------------------------------
# Quest validation
# ---------------------------------------------------------------------------

def validate_quest(file_path: str) -> ValidationResult:
    result = ValidationResult(file_path, "quest")

    try:
        with open(file_path, "r") as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        result.error(f"Invalid JSON: {e}")
        return result
    except FileNotFoundError:
        result.error(f"File not found: {file_path}")
        return result

    if not isinstance(data, dict):
        result.error("Top-level value must be a JSON object")
        return result

    # Required top-level fields
    _check_type(result, data, "quest_id", str, "quest")
    if _check_type(result, data, "type", str, "quest"):
        if data["type"] not in VALID_QUEST_TYPES:
            result.error(
                f"quest: invalid type '{data['type']}', "
                f"must be one of {sorted(VALID_QUEST_TYPES)}"
            )
    _check_type(result, data, "title", str, "quest")
    _check_type(result, data, "description", str, "quest")

    if not _check_type(result, data, "stages", list, "quest"):
        return result

    for si, stage in enumerate(data["stages"]):
        sctx = f"stages[{si}]"
        if not isinstance(stage, dict):
            result.error(f"{sctx}: must be a JSON object")
            continue

        _check_type(result, stage, "id", str, sctx)
        _check_type(result, stage, "title", str, sctx)
        _check_type(result, stage, "description", str, sctx)
        _check_type(result, stage, "trigger", str, sctx)

        if _check_type(result, stage, "objectives", list, sctx):
            for oi, obj in enumerate(stage["objectives"]):
                if not isinstance(obj, str):
                    result.error(
                        f"{sctx}.objectives[{oi}]: must be a string, "
                        f"got {type(obj).__name__}"
                    )

        if _check_type(result, stage, "outcomes", dict, sctx):
            outcomes = stage["outcomes"]
            for outcome_key in ("success", "failure"):
                octx = f"{sctx}.outcomes"
                if outcome_key in outcomes:
                    val = outcomes[outcome_key]
                    if isinstance(val, dict):
                        # Rich format: {next_stage, narrative}
                        _check_optional_type(result, val, "narrative", str, f"{octx}.{outcome_key}")
                    elif not isinstance(val, str):
                        result.error(
                            f"{octx}: field '{outcome_key}' should be str or dict, "
                            f"got {type(val).__name__}"
                        )

    # Optional rewards
    if "rewards" in data:
        if not isinstance(data["rewards"], dict):
            result.error(
                f"quest: 'rewards' should be a dict, got {type(data['rewards']).__name__}"
            )

    return result


# ---------------------------------------------------------------------------
# Tavern / Location validation
# ---------------------------------------------------------------------------

WORLD_TILES_PATH = PROJECT_ROOT / "game" / "assets" / "generated" / "world_tiles.json"
INDOOR_TILES_PATH = PROJECT_ROOT / "game" / "assets" / "generated" / "indoor_tiles.json"
CHARACTER_TILES_PATH = PROJECT_ROOT / "game" / "assets" / "generated" / "character_tiles.json"
OUTDOOR_TILES_PATH = PROJECT_ROOT / "game" / "assets" / "generated" / "outdoor_tiles.json"


def _load_tile_names(path: Path) -> set[str]:
    """Load valid sprite names from a tile atlas JSON."""
    if not path.exists():
        return set()
    with open(path, "r") as f:
        data = json.load(f)
    sprites = data.get("sprites", {})
    return set(sprites.keys())


def _bfs_reachable(layout: list[str], start: tuple[int, int],
                   tile_legend: dict[str, Any], width: int, height: int) -> set[tuple[int, int]]:
    """BFS from start position on walkable tiles. Returns set of reachable (x,y)."""
    visited: set[tuple[int, int]] = set()
    queue: list[tuple[int, int]] = [start]
    visited.add(start)
    directions = [(0, 1), (0, -1), (1, 0), (-1, 0)]

    while queue:
        cx, cy = queue.pop(0)
        for dx, dy in directions:
            nx, ny = cx + dx, cy + dy
            if 0 <= nx < width and 0 <= ny < height and (nx, ny) not in visited:
                ch = layout[ny][nx] if nx < len(layout[ny]) else ""
                legend_entry = tile_legend.get(ch, {})
                walkable = legend_entry.get("walkable", False) if isinstance(legend_entry, dict) else False
                if walkable:
                    visited.add((nx, ny))
                    queue.append((nx, ny))

    return visited


def validate_tavern(file_path: str) -> ValidationResult:
    result = ValidationResult(file_path, "tavern")

    # Load JSON
    try:
        with open(file_path, "r") as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        result.error(f"Invalid JSON: {e}")
        return result
    except FileNotFoundError:
        result.error(f"File not found: {file_path}")
        return result

    if not isinstance(data, dict):
        result.error("Top-level value must be a JSON object")
        return result

    # Required top-level fields
    _check_type(result, data, "name", str, "tavern")
    _check_type(result, data, "location_type", str, "tavern")
    has_width = _check_type(result, data, "width", int, "tavern")
    has_height = _check_type(result, data, "height", int, "tavern")
    _check_type(result, data, "tile_size", int, "tavern")

    if not _check_type(result, data, "layout", list, "tavern"):
        return result
    if not _check_type(result, data, "tile_legend", dict, "tavern"):
        return result

    layout = data["layout"]
    tile_legend = data["tile_legend"]
    width = data.get("width", 0)
    height = data.get("height", 0)

    # Layout dimensions
    if has_height and len(layout) != height:
        result.error(
            f"Layout has {len(layout)} rows but declared height is {height}"
        )

    if has_width:
        for i, row in enumerate(layout):
            if not isinstance(row, str):
                result.error(f"layout[{i}]: must be a string, got {type(row).__name__}")
                continue
            if len(row) != width:
                result.error(
                    f"layout[{i}]: row length {len(row)} != declared width {width}"
                )

    # All chars in layout exist in tile_legend
    used_chars: set[str] = set()
    for y, row in enumerate(layout):
        if not isinstance(row, str):
            continue
        for x, ch in enumerate(row):
            used_chars.add(ch)
            if ch not in tile_legend:
                result.error(
                    f"layout[{y}][{x}]: character '{ch}' not in tile_legend"
                )

    # Validate tile_legend entries
    world_tiles = _load_tile_names(WORLD_TILES_PATH)
    indoor_tiles = _load_tile_names(INDOOR_TILES_PATH)

    for ch, entry in tile_legend.items():
        if not isinstance(entry, dict):
            result.error(f"tile_legend['{ch}']: must be a dict")
            continue
        _check_type(result, entry, "name", str, f"tile_legend['{ch}']")
        if "walkable" not in entry:
            result.error(f"tile_legend['{ch}']: missing 'walkable' field")

        # Validate tile_name references against atlases
        tile_name = entry.get("tile_name")
        atlas = entry.get("atlas", "")
        if tile_name:
            if atlas == "world" and world_tiles and tile_name not in world_tiles:
                result.error(
                    f"tile_legend['{ch}']: tile_name '{tile_name}' not found "
                    f"in world_tiles atlas"
                )
            elif atlas == "indoor" and indoor_tiles and tile_name not in indoor_tiles:
                result.error(
                    f"tile_legend['{ch}']: tile_name '{tile_name}' not found "
                    f"in indoor_tiles atlas"
                )

    # Player spawn
    if _check_type(result, data, "player_spawn", list, "tavern"):
        spawn = data["player_spawn"]
        if len(spawn) != 2:
            result.error(f"player_spawn must have exactly 2 elements [x, y]")
        elif has_width and has_height:
            sx, sy = spawn
            if not (0 <= sx < width and 0 <= sy < height):
                result.error(
                    f"player_spawn [{sx},{sy}] out of bounds ({width}x{height})"
                )
            elif sy < len(layout) and isinstance(layout[sy], str) and sx < len(layout[sy]):
                ch = layout[sy][sx]
                legend = tile_legend.get(ch, {})
                if isinstance(legend, dict) and not legend.get("walkable", False):
                    result.error(
                        f"player_spawn [{sx},{sy}] is on non-walkable tile '{ch}'"
                    )

    # NPC validation
    character_tiles = _load_tile_names(CHARACTER_TILES_PATH)
    if _check_type(result, data, "npcs", list, "tavern"):
        for ni, npc in enumerate(data["npcs"]):
            nctx = f"npcs[{ni}]"
            if not isinstance(npc, dict):
                result.error(f"{nctx}: must be a dict")
                continue
            _check_type(result, npc, "npc_id", str, nctx)
            _check_type(result, npc, "display_name", str, nctx)
            if _check_type(result, npc, "position", list, nctx):
                pos = npc["position"]
                if len(pos) != 2:
                    result.error(f"{nctx}: position must have exactly 2 elements")
                elif has_width and has_height:
                    px, py = pos
                    if not (0 <= px < width and 0 <= py < height):
                        result.error(
                            f"{nctx}: position [{px},{py}] out of bounds"
                        )
            _check_type(result, npc, "sprite_name", str, nctx)
            if "sprite_name" in npc and character_tiles:
                if npc["sprite_name"] not in character_tiles:
                    result.error(
                        f"{nctx}: sprite_name '{npc['sprite_name']}' not found "
                        f"in character_tiles atlas"
                    )

    # At least one entrance door
    has_door = False
    for row in layout:
        if isinstance(row, str) and "D" in row:
            has_door = True
            break
    if not has_door:
        # Check if any tile_legend entry is named "entrance_door"
        door_chars = [ch for ch, e in tile_legend.items()
                      if isinstance(e, dict) and "door" in e.get("name", "").lower()
                      and "entrance" in e.get("name", "").lower()]
        if not door_chars:
            result.error("No entrance door ('D') found in layout")

    # Perimeter enclosure check
    if layout and has_width and has_height and len(layout) == height:
        # Top and bottom rows should be walls/non-walkable
        for row_idx in [0, height - 1]:
            if row_idx < len(layout) and isinstance(layout[row_idx], str):
                for x, ch in enumerate(layout[row_idx]):
                    legend = tile_legend.get(ch, {})
                    walkable = legend.get("walkable", False) if isinstance(legend, dict) else False
                    if walkable and ch != "D":
                        result.error(
                            f"Perimeter breach at [{x},{row_idx}]: "
                            f"walkable tile '{ch}' on border (must be wall or door)"
                        )
        # Left and right columns
        for y in range(height):
            if y >= len(layout) or not isinstance(layout[y], str):
                continue
            for x_idx in [0, width - 1]:
                if x_idx >= len(layout[y]):
                    continue
                ch = layout[y][x_idx]
                legend = tile_legend.get(ch, {})
                walkable = legend.get("walkable", False) if isinstance(legend, dict) else False
                if walkable and ch != "D":
                    result.error(
                        f"Perimeter breach at [{x_idx},{y}]: "
                        f"walkable tile '{ch}' on border (must be wall or door)"
                    )

    # BFS connectivity: player_spawn can reach all NPCs
    if (has_width and has_height and len(layout) == height
            and "player_spawn" in data and isinstance(data["player_spawn"], list)
            and len(data["player_spawn"]) == 2):
        sx, sy = data["player_spawn"]
        if 0 <= sx < width and 0 <= sy < height:
            reachable = _bfs_reachable(layout, (sx, sy), tile_legend, width, height)
            # Check NPC adjacency (NPCs are on non-walkable tiles, so check neighbors)
            for ni, npc in enumerate(data.get("npcs", [])):
                if not isinstance(npc, dict) or "position" not in npc:
                    continue
                pos = npc["position"]
                if len(pos) != 2:
                    continue
                px, py = pos
                # Check if any adjacent walkable tile is reachable
                adjacent_reachable = False
                for dx, dy in [(0, 1), (0, -1), (1, 0), (-1, 0)]:
                    nx, ny = px + dx, py + dy
                    if (nx, ny) in reachable:
                        adjacent_reachable = True
                        break
                if not adjacent_reachable:
                    npc_id = npc.get("npc_id", f"#{ni}")
                    result.error(
                        f"NPC '{npc_id}' at [{px},{py}] is not reachable "
                        f"from player_spawn [{sx},{sy}]"
                    )

    # Optional fields validation
    _check_optional_type(result, data, "atmosphere", dict, "tavern")
    _check_optional_type(result, data, "zones", list, "tavern")
    _check_optional_type(result, data, "entrance_narration", list, "tavern")

    return result


# ---------------------------------------------------------------------------
# Village validation
# ---------------------------------------------------------------------------

INDOOR_FLOOR_NAMES = {"floor", "carpet", "chair", "bed", "bench", "stone_floor",
                      "bookshelf", "long_counter", "shop_counter"}


def _rects_overlap(a: dict, b: dict) -> bool:
    """Check if two rects (x,y,w,h) overlap."""
    if a["x"] >= b["x"] + b["w"] or b["x"] >= a["x"] + a["w"]:
        return False
    if a["y"] >= b["y"] + b["h"] or b["y"] >= a["y"] + a["h"]:
        return False
    return True


def validate_village(file_path: str) -> ValidationResult:
    result = ValidationResult(file_path, "village")

    # Load JSON
    try:
        with open(file_path, "r") as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        result.error(f"Invalid JSON: {e}")
        return result
    except FileNotFoundError:
        result.error(f"File not found: {file_path}")
        return result

    if not isinstance(data, dict):
        result.error("Top-level value must be a JSON object")
        return result

    # Required top-level fields
    _check_type(result, data, "name", str, "village")
    _check_type(result, data, "location_type", str, "village")
    has_width = _check_type(result, data, "width", int, "village")
    has_height = _check_type(result, data, "height", int, "village")
    _check_type(result, data, "tile_size", int, "village")

    if not _check_type(result, data, "layout", list, "village"):
        return result
    if not _check_type(result, data, "tile_legend", dict, "village"):
        return result

    layout = data["layout"]
    tile_legend = data["tile_legend"]
    width = data.get("width", 0)
    height = data.get("height", 0)

    # Layout dimensions
    if has_height and len(layout) != height:
        result.error(
            f"Layout has {len(layout)} rows but declared height is {height}"
        )

    if has_width:
        for i, row in enumerate(layout):
            if not isinstance(row, str):
                result.error(f"layout[{i}]: must be a string, got {type(row).__name__}")
                continue
            if len(row) != width:
                result.error(
                    f"layout[{i}]: row length {len(row)} != declared width {width}"
                )

    # All chars in layout exist in tile_legend
    used_chars: set[str] = set()
    for y, row in enumerate(layout):
        if not isinstance(row, str):
            continue
        for x, ch in enumerate(row):
            used_chars.add(ch)
            if ch not in tile_legend:
                result.error(
                    f"layout[{y}][{x}]: character '{ch}' not in tile_legend"
                )

    # Validate tile_legend entries
    world_tiles = _load_tile_names(WORLD_TILES_PATH)
    indoor_tiles = _load_tile_names(INDOOR_TILES_PATH)
    outdoor_tiles = _load_tile_names(OUTDOOR_TILES_PATH)

    for ch, entry in tile_legend.items():
        if not isinstance(entry, dict):
            result.error(f"tile_legend['{ch}']: must be a dict")
            continue
        _check_type(result, entry, "name", str, f"tile_legend['{ch}']")
        if "walkable" not in entry:
            result.error(f"tile_legend['{ch}']: missing 'walkable' field")

        # Validate tile_name references against atlases
        tile_name = entry.get("tile_name")
        atlas = entry.get("atlas", "")
        if tile_name:
            if atlas == "world" and world_tiles and tile_name not in world_tiles:
                result.error(
                    f"tile_legend['{ch}']: tile_name '{tile_name}' not found "
                    f"in world_tiles atlas"
                )
            elif atlas == "indoor" and indoor_tiles and tile_name not in indoor_tiles:
                result.error(
                    f"tile_legend['{ch}']: tile_name '{tile_name}' not found "
                    f"in indoor_tiles atlas"
                )
            elif atlas == "outdoor" and outdoor_tiles and tile_name not in outdoor_tiles:
                result.error(
                    f"tile_legend['{ch}']: tile_name '{tile_name}' not found "
                    f"in outdoor_tiles atlas"
                )

    # Player spawn
    if _check_type(result, data, "player_spawn", list, "village"):
        spawn = data["player_spawn"]
        if len(spawn) != 2:
            result.error("player_spawn must have exactly 2 elements [x, y]")
        elif has_width and has_height:
            sx, sy = spawn
            if not (0 <= sx < width and 0 <= sy < height):
                result.error(
                    f"player_spawn [{sx},{sy}] out of bounds ({width}x{height})"
                )
            elif sy < len(layout) and isinstance(layout[sy], str) and sx < len(layout[sy]):
                ch = layout[sy][sx]
                legend = tile_legend.get(ch, {})
                if isinstance(legend, dict) and not legend.get("walkable", False):
                    result.error(
                        f"player_spawn [{sx},{sy}] is on non-walkable tile '{ch}'"
                    )

    # NPC validation
    character_tiles = _load_tile_names(CHARACTER_TILES_PATH)
    if _check_type(result, data, "npcs", list, "village"):
        for ni, npc in enumerate(data["npcs"]):
            nctx = f"npcs[{ni}]"
            if not isinstance(npc, dict):
                result.error(f"{nctx}: must be a dict")
                continue
            _check_type(result, npc, "npc_id", str, nctx)
            _check_type(result, npc, "display_name", str, nctx)
            if _check_type(result, npc, "position", list, nctx):
                pos = npc["position"]
                if len(pos) != 2:
                    result.error(f"{nctx}: position must have exactly 2 elements")
                elif has_width and has_height:
                    px, py = pos
                    if not (0 <= px < width and 0 <= py < height):
                        result.error(
                            f"{nctx}: position [{px},{py}] out of bounds"
                        )
            _check_type(result, npc, "sprite_name", str, nctx)
            if "sprite_name" in npc and character_tiles:
                if npc["sprite_name"] not in character_tiles:
                    result.error(
                        f"{nctx}: sprite_name '{npc['sprite_name']}' not found "
                        f"in character_tiles atlas"
                    )

    # --- Village-specific: buildings validation ---
    if _check_type(result, data, "buildings", list, "village"):
        buildings = data["buildings"]
        building_ids: set[str] = set()

        for bi, bldg in enumerate(buildings):
            bctx = f"buildings[{bi}]"
            if not isinstance(bldg, dict):
                result.error(f"{bctx}: must be a dict")
                continue

            _check_type(result, bldg, "id", str, bctx)
            _check_type(result, bldg, "name", str, bctx)
            _check_type(result, bldg, "type", str, bctx)

            # Check for duplicate building IDs
            bid = bldg.get("id", "")
            if bid:
                if bid in building_ids:
                    result.error(f"{bctx}: duplicate building id '{bid}'")
                building_ids.add(bid)

            # Validate rect
            has_rect = _check_type(result, bldg, "rect", dict, bctx)
            if has_rect:
                rect = bldg["rect"]
                has_bx = _check_type(result, rect, "x", int, f"{bctx}.rect")
                has_by = _check_type(result, rect, "y", int, f"{bctx}.rect")
                has_bw = _check_type(result, rect, "w", int, f"{bctx}.rect")
                has_bh = _check_type(result, rect, "h", int, f"{bctx}.rect")

                if has_bx and has_by and has_bw and has_bh and has_width and has_height:
                    bx, by, bw, bh = rect["x"], rect["y"], rect["w"], rect["h"]
                    if bx < 0 or by < 0 or bx + bw > width or by + bh > height:
                        result.error(
                            f"{bctx}: rect ({bx},{by},{bw},{bh}) extends beyond "
                            f"map bounds ({width}x{height})"
                        )

            # Validate door_positions
            if _check_type(result, bldg, "door_positions", list, bctx):
                for di, dpos in enumerate(bldg["door_positions"]):
                    dctx = f"{bctx}.door_positions[{di}]"
                    if not isinstance(dpos, list) or len(dpos) != 2:
                        result.error(f"{dctx}: must be [x, y] array")
                        continue
                    dx, dy = dpos
                    if has_width and has_height:
                        if not (0 <= dx < width and 0 <= dy < height):
                            result.error(f"{dctx}: [{dx},{dy}] out of map bounds")

                    # Check door is on building perimeter
                    if has_rect:
                        rect = bldg["rect"]
                        bx, by = rect.get("x", 0), rect.get("y", 0)
                        bw, bh = rect.get("w", 0), rect.get("h", 0)
                        on_top = (dy == by and bx <= dx < bx + bw)
                        on_bottom = (dy == by + bh - 1 and bx <= dx < bx + bw)
                        on_left = (dx == bx and by <= dy < by + bh)
                        on_right = (dx == bx + bw - 1 and by <= dy < by + bh)
                        # Also allow door just outside the rect (on the edge row/col)
                        on_outside_bottom = (dy == by + bh and bx <= dx < bx + bw)
                        on_outside_top = (dy == by - 1 and bx <= dx < bx + bw)
                        on_outside_left = (dx == bx - 1 and by <= dy < by + bh)
                        on_outside_right = (dx == bx + bw and by <= dy < by + bh)
                        on_perimeter = (on_top or on_bottom or on_left or on_right or
                                        on_outside_bottom or on_outside_top or
                                        on_outside_left or on_outside_right)
                        if not on_perimeter:
                            result.error(
                                f"{dctx}: door at [{dx},{dy}] is not on the "
                                f"perimeter of building rect ({bx},{by},{bw},{bh})"
                            )

        # Check buildings don't overlap
        for i in range(len(buildings)):
            if not isinstance(buildings[i], dict) or "rect" not in buildings[i]:
                continue
            for j in range(i + 1, len(buildings)):
                if not isinstance(buildings[j], dict) or "rect" not in buildings[j]:
                    continue
                ra, rb = buildings[i]["rect"], buildings[j]["rect"]
                if (all(k in ra for k in ("x", "y", "w", "h")) and
                        all(k in rb for k in ("x", "y", "w", "h"))):
                    if _rects_overlap(ra, rb):
                        result.error(
                            f"buildings[{i}] ({ra['x']},{ra['y']},{ra['w']},{ra['h']}) "
                            f"and buildings[{j}] ({rb['x']},{rb['y']},{rb['w']},{rb['h']}) overlap"
                        )

    # --- Village-specific: exits validation ---
    if _check_type(result, data, "exits", list, "village"):
        for ei, ex in enumerate(data["exits"]):
            ectx = f"exits[{ei}]"
            if not isinstance(ex, dict):
                result.error(f"{ectx}: must be a dict")
                continue
            _check_type(result, ex, "destination", str, ectx)
            if _check_type(result, ex, "position", list, ectx):
                epos = ex["position"]
                if len(epos) != 2:
                    result.error(f"{ectx}: position must have exactly 2 elements")
                elif has_width and has_height:
                    epx, epy = epos
                    if not (0 <= epx < width and 0 <= epy < height):
                        result.error(
                            f"{ectx}: position [{epx},{epy}] out of map bounds"
                        )

    # --- Village perimeter check (relaxed) ---
    # Village edges can have outdoor walkable tiles (grass, paths) but not indoor floors
    if layout and has_width and has_height and len(layout) == height:
        for row_idx in [0, height - 1]:
            if row_idx < len(layout) and isinstance(layout[row_idx], str):
                for x, ch in enumerate(layout[row_idx]):
                    legend = tile_legend.get(ch, {})
                    if not isinstance(legend, dict):
                        continue
                    tile_name_str = legend.get("name", "").lower()
                    # Indoor floor tiles on the perimeter are not allowed
                    if tile_name_str in INDOOR_FLOOR_NAMES:
                        result.error(
                            f"Perimeter breach at [{x},{row_idx}]: "
                            f"indoor tile '{ch}' ({tile_name_str}) on village border"
                        )
        for y in range(height):
            if y >= len(layout) or not isinstance(layout[y], str):
                continue
            for x_idx in [0, width - 1]:
                if x_idx >= len(layout[y]):
                    continue
                ch = layout[y][x_idx]
                legend = tile_legend.get(ch, {})
                if not isinstance(legend, dict):
                    continue
                tile_name_str = legend.get("name", "").lower()
                if tile_name_str in INDOOR_FLOOR_NAMES:
                    result.error(
                        f"Perimeter breach at [{x_idx},{y}]: "
                        f"indoor tile '{ch}' ({tile_name_str}) on village border"
                    )

    # --- BFS connectivity: player can reach all building doors ---
    if (has_width and has_height and len(layout) == height
            and "player_spawn" in data and isinstance(data["player_spawn"], list)
            and len(data["player_spawn"]) == 2):
        sx, sy = data["player_spawn"]
        if 0 <= sx < width and 0 <= sy < height:
            reachable = _bfs_reachable(layout, (sx, sy), tile_legend, width, height)

            # Check NPC adjacency (NPCs are on non-walkable tiles, so check neighbors)
            for ni, npc in enumerate(data.get("npcs", [])):
                if not isinstance(npc, dict) or "position" not in npc:
                    continue
                pos = npc["position"]
                if len(pos) != 2:
                    continue
                px, py = pos
                adjacent_reachable = False
                for dx, dy in [(0, 1), (0, -1), (1, 0), (-1, 0)]:
                    nx, ny = px + dx, py + dy
                    if (nx, ny) in reachable:
                        adjacent_reachable = True
                        break
                if not adjacent_reachable:
                    npc_id = npc.get("npc_id", f"#{ni}")
                    result.error(
                        f"NPC '{npc_id}' at [{px},{py}] is not reachable "
                        f"from player_spawn [{sx},{sy}]"
                    )

            # Check all building doors are reachable
            for bi, bldg in enumerate(data.get("buildings", [])):
                if not isinstance(bldg, dict):
                    continue
                bid = bldg.get("id", f"#{bi}")
                for di, dpos in enumerate(bldg.get("door_positions", [])):
                    if not isinstance(dpos, list) or len(dpos) != 2:
                        continue
                    dx, dy = dpos
                    # Door itself should be reachable, or an adjacent tile should be
                    door_reachable = (dx, dy) in reachable
                    if not door_reachable:
                        for ddx, ddy in [(0, 1), (0, -1), (1, 0), (-1, 0)]:
                            nxx, nyy = dx + ddx, dy + ddy
                            if (nxx, nyy) in reachable:
                                door_reachable = True
                                break
                    if not door_reachable:
                        result.error(
                            f"Building '{bid}' door at [{dx},{dy}] is not reachable "
                            f"from player_spawn [{sx},{sy}]"
                        )

    # Optional fields validation
    _check_optional_type(result, data, "atmosphere", dict, "village")
    _check_optional_type(result, data, "entrance_narration", list, "village")

    return result


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

VALIDATORS = {
    "dungeon": validate_dungeon,
    "npc": validate_npc,
    "quest": validate_quest,
    "tavern": validate_tavern,
    "village": validate_village,
}


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate Forge-generated content against game formats."
    )
    subparsers = parser.add_subparsers(dest="content_type", required=True)

    for name in VALIDATORS:
        sp = subparsers.add_parser(name, help=f"Validate a {name} JSON file")
        sp.add_argument("file", help="Path to the JSON file to validate")

    args = parser.parse_args()

    validator = VALIDATORS[args.content_type]
    result = validator(args.file)
    result.report()

    return 0 if result.ok else 1


if __name__ == "__main__":
    sys.exit(main())
