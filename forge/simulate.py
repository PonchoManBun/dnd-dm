#!/usr/bin/env python3
"""Headless dungeon simulation and playability validator.

Builds the dungeon grid exactly like DungeonLoader, validates connectivity,
encounter balance, spatial placement, loot economy, and runs Monte Carlo
combat simulations with a standard D&D party.

Usage:
    python3 forge/simulate.py path/to/dungeon.json [options]
    python3 forge/simulate.py path/to/dungeon.json --level 3 --runs 200
    python3 forge/simulate.py path/to/dungeon.json --json --seed 42
    python3 forge/simulate.py path/to/dungeon.json --render preview.png
"""

import argparse
import csv
import json
import math
import random
import sys
from collections import deque
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

# ---------------------------------------------------------------------------
# Constants & Paths
# ---------------------------------------------------------------------------

PROJECT_ROOT = Path(__file__).resolve().parent.parent
MONSTERS_PATH = PROJECT_ROOT / "game" / "assets" / "data" / "dnd_monsters.json"
ITEMS_PATH = PROJECT_ROOT / "game" / "assets" / "data" / "items.csv"
TILE_ATLAS_PATH = PROJECT_ROOT / "game" / "assets" / "generated" / "world_tiles.png"
TILE_MAP_PATH = PROJECT_ROOT / "game" / "assets" / "generated" / "world_tiles.json"

WALL = 0
FLOOR = 1

AREA_NONE = 0
AREA_ROOM = 1
AREA_CORRIDOR = 2

# XP thresholds per character level (Easy, Medium, Hard, Deadly)
XP_THRESHOLDS: dict[int, tuple[int, int, int, int]] = {
    1:  (25, 50, 75, 100),
    2:  (50, 100, 150, 200),
    3:  (75, 150, 225, 400),
    4:  (125, 250, 375, 500),
    5:  (250, 500, 750, 1100),
    6:  (300, 600, 900, 1400),
    7:  (350, 750, 1100, 1700),
    8:  (450, 900, 1400, 2100),
    9:  (550, 1100, 1600, 2400),
    10: (600, 1200, 1900, 2800),
}

# CR -> XP from SRD
CR_XP: dict[float, int] = {
    0: 10, 0.125: 25, 0.25: 50, 0.5: 100,
    1: 200, 2: 450, 3: 700, 4: 1100,
    5: 1800, 6: 2300, 7: 2900, 8: 3900,
    9: 5000, 10: 5900, 11: 7200, 12: 8400,
}

# Encounter multiplier breakpoints: (min_count, multiplier)
ENCOUNTER_MULTIPLIERS: list[tuple[int, float]] = [
    (15, 4.0), (11, 3.0), (7, 2.5), (3, 2.0), (2, 1.5), (1, 1.0),
]

DIFFICULTY_LABELS = ["Easy", "Medium", "Hard", "Deadly"]

# Loot expectations per room type: (min_items, max_items)
LOOT_EXPECTATIONS: dict[str, tuple[int, int]] = {
    "entrance": (0, 1),
    "combat": (1, 2),
    "treasure": (2, 4),
    "trap": (0, 2),
    "boss": (2, 3),
    "empty": (0, 0),
}


# ---------------------------------------------------------------------------
# Data Loading
# ---------------------------------------------------------------------------

def load_monster_registry() -> dict[str, dict]:
    """Load full monster data from dnd_monsters.json."""
    if not MONSTERS_PATH.exists():
        return {}
    with open(MONSTERS_PATH, "r") as f:
        return json.load(f)


def load_item_slugs() -> set[str]:
    """Return valid item slugs from items.csv."""
    if not ITEMS_PATH.exists():
        return set()
    slugs: set[str] = set()
    with open(ITEMS_PATH, "r") as f:
        reader = csv.reader(f)
        next(reader, None)
        for row in reader:
            if row:
                slugs.add(row[0].strip().lower().replace(" ", "_"))
    return slugs


def _ability_mod(score: int) -> int:
    return (score - 10) // 2


def _encounter_multiplier(count: int) -> float:
    for min_count, mult in ENCOUNTER_MULTIPLIERS:
        if count >= min_count:
            return mult
    return 1.0


def _party_thresholds(level: int, party_size: int) -> tuple[int, int, int, int]:
    base = XP_THRESHOLDS.get(level, XP_THRESHOLDS[1])
    return tuple(v * party_size for v in base)  # type: ignore


def _rate_difficulty(adjusted_xp: int, thresholds: tuple[int, int, int, int]) -> str:
    easy, medium, hard, deadly = thresholds
    if adjusted_xp >= deadly:
        return "Deadly"
    if adjusted_xp >= hard:
        return "Hard"
    if adjusted_xp >= medium:
        return "Medium"
    return "Easy"


# ---------------------------------------------------------------------------
# Grid Simulation (mirrors DungeonLoader exactly)
# ---------------------------------------------------------------------------

class FloorGrid:
    """Simulates the dungeon grid as built by DungeonLoader._carve_room/corridor."""

    def __init__(self, width: int, height: int) -> None:
        self.width = width
        self.height = height
        # terrain[x][y] — column-major like Godot
        self.terrain: list[list[int]] = [[WALL] * height for _ in range(width)]
        self.area_type: list[list[int]] = [[AREA_NONE] * height for _ in range(width)]
        self.room_ids: list[list[int]] = [[-1] * height for _ in range(width)]
        self.entities: dict[tuple[int, int], list[dict]] = {}
        self.connection_points: dict[int, set[tuple[int, int]]] = {}

    def _in_bounds(self, x: int, y: int) -> bool:
        return 0 <= x < self.width and 0 <= y < self.height

    def carve_room(self, room: dict) -> None:
        rx, ry, rw, rh = room["x"], room["y"], room["w"], room["h"]
        rid = room["id"]
        for x in range(rx, rx + rw):
            for y in range(ry, ry + rh):
                if self._in_bounds(x, y):
                    self.terrain[x][y] = FLOOR
                    self.area_type[x][y] = AREA_ROOM
                    self.room_ids[x][y] = rid

    def carve_corridor(self, from_room: dict, to_room: dict) -> None:
        """L-shaped corridor — mirrors dungeon_loader.gd:142-170 exactly."""
        # Centers use integer division (GDScript default for int / int)
        from_cx = from_room["x"] + from_room["w"] // 2
        from_cy = from_room["y"] + from_room["h"] // 2
        to_cx = to_room["x"] + to_room["w"] // 2
        to_cy = to_room["y"] + to_room["h"] // 2

        # Horizontal walk: from_cx to to_cx (exclusive of to_cx) at y=from_cy
        x = from_cx
        x_dir = 1 if to_cx > from_cx else -1
        while x != to_cx:
            if self._in_bounds(x, from_cy):
                if self.terrain[x][from_cy] == WALL:
                    self.terrain[x][from_cy] = FLOOR
                    self.area_type[x][from_cy] = AREA_CORRIDOR
                    # Track connection points: first corridor cell inside a room
                    rid = self.room_ids[x][from_cy]
                    if rid >= 0:
                        self.connection_points.setdefault(rid, set()).add((x, from_cy))
            x += x_dir

        # Vertical walk: from_cy to to_cy (inclusive — while y != to_cy + y_dir)
        y = from_cy
        y_dir = 1 if to_cy > from_cy else -1
        while y != to_cy + y_dir:
            if self._in_bounds(to_cx, y):
                if self.terrain[to_cx][y] == WALL:
                    self.terrain[to_cx][y] = FLOOR
                    self.area_type[to_cx][y] = AREA_CORRIDOR
                    rid = self.room_ids[to_cx][y]
                    if rid >= 0:
                        self.connection_points.setdefault(rid, set()).add((to_cx, y))
            y += y_dir

    def place_entity(self, x: int, y: int, entity: dict) -> None:
        self.entities.setdefault((x, y), []).append(entity)

    def walkable_cells_in_room(self, room: dict) -> list[tuple[int, int]]:
        """All FLOOR cells within the room bounds."""
        cells = []
        rx, ry, rw, rh = room["x"], room["y"], room["w"], room["h"]
        for x in range(rx, rx + rw):
            for y in range(ry, ry + rh):
                if self._in_bounds(x, y) and self.terrain[x][y] == FLOOR:
                    cells.append((x, y))
        return cells


def build_floor_grid(floor_data: dict, rooms_by_id: dict[int, dict]) -> FloorGrid:
    """Build a FloorGrid from floor JSON data."""
    grid = FloorGrid(floor_data["width"], floor_data["height"])

    # Carve rooms
    for room in floor_data["rooms"]:
        grid.carve_room(room)

    # Carve corridors
    for corr in floor_data.get("corridors", []):
        from_room = rooms_by_id.get(corr["from"])
        to_room = rooms_by_id.get(corr["to"])
        if from_room and to_room:
            grid.carve_corridor(from_room, to_room)

    # Place entities
    for room in floor_data["rooms"]:
        # Stairs
        if room.get("stairs_up"):
            pos = (room["x"] + 1, room["y"] + 1)
            grid.place_entity(*pos, {"type": "stairs_up"})
        if room.get("stairs_down"):
            pos = (room["x"] + room["w"] - 2, room["y"] + room["h"] - 2)
            grid.place_entity(*pos, {"type": "stairs_down"})
        # Monsters
        for m in room.get("monsters", []):
            grid.place_entity(m["x"], m["y"], {"type": "monster", "slug": m["slug"]})
        # Items
        for item in room.get("items", []):
            grid.place_entity(item["x"], item["y"], {
                "type": "item", "slug": item["slug"],
                "quantity": item.get("quantity", 1)
            })

    return grid


# ---------------------------------------------------------------------------
# Connectivity Validation
# ---------------------------------------------------------------------------

def validate_connectivity(grid: FloorGrid, floor_data: dict) -> list[str]:
    """BFS from stairs_up, verify all rooms and stairs_down reachable."""
    errors: list[str] = []
    rooms = floor_data["rooms"]
    if not rooms:
        errors.append("No rooms on floor")
        return errors

    # Find start position (stairs_up in first room)
    first = rooms[0]
    start = (first["x"] + 1, first["y"] + 1)
    if not grid._in_bounds(*start) or grid.terrain[start[0]][start[1]] != FLOOR:
        errors.append(f"Stairs_up position {start} is not walkable")
        return errors

    # BFS
    visited: set[tuple[int, int]] = set()
    queue: deque[tuple[int, int]] = deque([start])
    visited.add(start)
    while queue:
        cx, cy = queue.popleft()
        for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
            nx, ny = cx + dx, cy + dy
            if (nx, ny) not in visited and grid._in_bounds(nx, ny) and grid.terrain[nx][ny] == FLOOR:
                visited.add((nx, ny))
                queue.append((nx, ny))

    # Check every room has at least one reachable cell
    for room in rooms:
        rx, ry, rw, rh = room["x"], room["y"], room["w"], room["h"]
        found = False
        for x in range(rx, rx + rw):
            for y in range(ry, ry + rh):
                if (x, y) in visited:
                    found = True
                    break
            if found:
                break
        if not found:
            errors.append(f"Room {room['id']} ({room['name']}) is unreachable from entrance")

    # Check stairs_down reachable
    for room in rooms:
        if room.get("stairs_down"):
            sd_pos = (room["x"] + room["w"] - 2, room["y"] + room["h"] - 2)
            if sd_pos not in visited:
                errors.append(f"stairs_down at {sd_pos} in room {room['id']} is unreachable")

    return errors


def validate_cross_floor(data: dict) -> list[str]:
    """Verify floor N has stairs_down when floor N+1 exists."""
    errors: list[str] = []
    floors = data["floors"]
    for i in range(len(floors) - 1):
        has_down = any(r.get("stairs_down") for r in floors[i]["rooms"])
        if not has_down:
            errors.append(f"Floor {i} has no stairs_down but floor {i+1} exists")
    for i in range(1, len(floors)):
        has_up = any(r.get("stairs_up") for r in floors[i]["rooms"])
        if not has_up:
            errors.append(f"Floor {i} has no stairs_up but floor {i-1} exists")
    return errors


# ---------------------------------------------------------------------------
# Encounter Balance
# ---------------------------------------------------------------------------

@dataclass
class EncounterRating:
    room_id: int
    room_name: str
    room_type: str
    monster_slugs: list[str]
    raw_xp: int
    adjusted_xp: int
    difficulty: str
    warnings: list[str] = field(default_factory=list)


def rate_encounters(
    floor_data: dict,
    monster_registry: dict[str, dict],
    level: int,
    party_size: int,
) -> list[EncounterRating]:
    """Rate each room's encounter difficulty."""
    thresholds = _party_thresholds(level, party_size)
    ratings: list[EncounterRating] = []

    for room in floor_data["rooms"]:
        monsters = room.get("monsters", [])
        if not monsters:
            ratings.append(EncounterRating(
                room_id=room["id"], room_name=room["name"],
                room_type=room["type"], monster_slugs=[], raw_xp=0,
                adjusted_xp=0, difficulty="Safe",
            ))
            continue

        slugs = [m["slug"] for m in monsters]
        raw_xp = 0
        for slug in slugs:
            mdata = monster_registry.get(slug, {})
            raw_xp += mdata.get("xp", 0)

        mult = _encounter_multiplier(len(monsters))
        adjusted_xp = int(raw_xp * mult)
        difficulty = _rate_difficulty(adjusted_xp, thresholds)

        warnings: list[str] = []

        # CR violation checks
        for m in monsters:
            mdata = monster_registry.get(m["slug"], {})
            cr = mdata.get("cr", 0)
            if level <= 1 and cr >= 2:
                warnings.append(f"{m['slug']} (CR {cr}) vs level 1 party — extremely dangerous")

        # Entrance room with monsters (non-Taskmaster is a warning)
        if room["type"] == "entrance" and monsters:
            warnings.append(f"Entrance room has {len(monsters)} monster(s)")

        # Boss below Medium
        if room["type"] == "boss" and difficulty in ("Easy", "Safe"):
            warnings.append(f"Boss room rated {difficulty} — should be at least Medium")

        # Exceeds Deadly
        if adjusted_xp > thresholds[3] * 1.5:
            warnings.append(f"Exceeds 1.5x Deadly threshold ({adjusted_xp} vs {int(thresholds[3]*1.5)})")

        ratings.append(EncounterRating(
            room_id=room["id"], room_name=room["name"],
            room_type=room["type"], monster_slugs=slugs,
            raw_xp=raw_xp, adjusted_xp=adjusted_xp,
            difficulty=difficulty, warnings=warnings,
        ))

    return ratings


# ---------------------------------------------------------------------------
# Tactical Spatial Validation
# ---------------------------------------------------------------------------

def validate_placement(
    grid: FloorGrid,
    floor_data: dict,
    monster_registry: dict[str, dict],
) -> list[str]:
    """Check monster placement against spacing rules."""
    warnings: list[str] = []

    for room in floor_data["rooms"]:
        monsters = room.get("monsters", [])
        if not monsters:
            continue

        rid = room["id"]
        conn_pts = grid.connection_points.get(rid, set())
        is_boss_room = room["type"] == "boss"

        for mi, m in enumerate(monsters):
            mx, my = m["x"], m["y"]

            if not conn_pts:
                continue

            # Manhattan distance to nearest connection point
            min_dist = min(abs(mx - cx) + abs(my - cy) for cx, cy in conn_pts)

            # Base rule: any monster >= 2 tiles from corridor entry
            if min_dist < 2:
                warnings.append(
                    f"Room {rid} ({room['name']}): {m['slug']}[{mi}] at ({mx},{my}) "
                    f"is {min_dist} tile(s) from corridor entry — minimum 2"
                )
                continue

            mdata = monster_registry.get(m["slug"], {})
            attacks = mdata.get("attacks", [])
            attack_types = {a.get("type", "melee") for a in attacks}

            if is_boss_room and min_dist < 5:
                warnings.append(
                    f"Room {rid} ({room['name']}): {m['slug']}[{mi}] is {min_dist} tiles "
                    f"from entry — boss room minimum is 5"
                )
            elif "ranged" in attack_types and min_dist < 4:
                warnings.append(
                    f"Room {rid} ({room['name']}): {m['slug']}[{mi}] (ranged) is {min_dist} tiles "
                    f"from entry — ranged minimum is 4"
                )
            elif attack_types <= {"melee"} and min_dist < 3:
                warnings.append(
                    f"Room {rid} ({room['name']}): {m['slug']}[{mi}] (melee) is {min_dist} tiles "
                    f"from entry — melee minimum is 3"
                )

        # Check room has enough walkable tiles
        walkable = grid.walkable_cells_in_room(room)
        entity_count = len(monsters) + len(room.get("items", []))
        if entity_count > len(walkable):
            warnings.append(
                f"Room {rid}: {entity_count} entities but only {len(walkable)} walkable tiles"
            )

    return warnings


# ---------------------------------------------------------------------------
# Loot Economy
# ---------------------------------------------------------------------------

def validate_loot(floor_data: dict) -> list[str]:
    """Check loot counts per room type."""
    warnings: list[str] = []

    for room in floor_data["rooms"]:
        rtype = room["type"]
        items = room.get("items", [])
        item_count = len(items)
        expected = LOOT_EXPECTATIONS.get(rtype, (0, 99))

        if item_count < expected[0]:
            warnings.append(
                f"Room {room['id']} ({room['name']}, {rtype}): "
                f"has {item_count} item(s), expected at least {expected[0]}"
            )

        if rtype == "combat" and item_count == 0:
            warnings.append(
                f"Room {room['id']} ({room['name']}): combat room with zero loot"
            )

        if rtype == "boss" and not room.get("on_clear"):
            warnings.append(
                f"Room {room['id']} ({room['name']}): boss room missing on_clear"
            )

    return warnings


# ---------------------------------------------------------------------------
# Monte Carlo Combat Simulation
# ---------------------------------------------------------------------------

@dataclass
class Combatant:
    name: str
    hp: int
    max_hp: int
    ac: int
    attack_mod: int
    damage_dice: int
    damage_sides: int
    damage_mod: int
    dex_mod: int
    is_party: bool
    alive: bool = True

    def roll_attack(self, rng: random.Random) -> tuple[int, bool, bool]:
        """Roll d20 + mod. Returns (total, is_crit, is_fumble)."""
        roll = rng.randint(1, 20)
        return roll + self.attack_mod, roll == 20, roll == 1

    def roll_damage(self, rng: random.Random, crit: bool = False) -> int:
        dice_count = self.damage_dice * (2 if crit else 1)
        total = sum(rng.randint(1, self.damage_sides) for _ in range(dice_count))
        return total + self.damage_mod


def _make_party(level: int, party_size: int) -> list[Combatant]:
    """Create a standard D&D party at the given level."""
    prof = 2 + (level - 1) // 4

    # Ability scores: point-buy archetypes
    templates = [
        # Fighter: STR 16, DEX 12, CON 14
        ("Fighter", 16, 12, 14, 10 + (level - 1) * 6 + 2, 16, 1, 8, "str"),
        # Rogue: DEX 16, CON 12, STR 10
        ("Rogue", 10, 16, 12, 8 + (level - 1) * 5 + 1, 14, 1, 6, "dex"),
        # Cleric: STR 14, WIS 16, CON 14
        ("Cleric", 14, 10, 14, 8 + (level - 1) * 5 + 2, 16, 1, 6, "str"),
        # Wizard: INT 16, DEX 14, CON 12
        ("Wizard", 10, 14, 12, 6 + (level - 1) * 4 + 1, 12, 1, 10, "dex"),
    ]

    party = []
    for i in range(party_size):
        t = templates[i % len(templates)]
        name, str_s, dex_s, con_s, hp, ac, dice, sides, atk_ability = t
        if i >= len(templates):
            name = f"{name} {i // len(templates) + 1}"

        atk_score = str_s if atk_ability == "str" else dex_s
        atk_mod = _ability_mod(atk_score)

        party.append(Combatant(
            name=name, hp=hp, max_hp=hp, ac=ac,
            attack_mod=atk_mod + prof,
            damage_dice=dice, damage_sides=sides, damage_mod=atk_mod,
            dex_mod=_ability_mod(dex_s), is_party=True,
        ))
    return party


def _make_monsters(
    room: dict, monster_registry: dict[str, dict]
) -> list[Combatant]:
    """Create monster combatants from room data."""
    combatants = []
    for m in room.get("monsters", []):
        mdata = monster_registry.get(m["slug"], {})
        if not mdata:
            continue

        attacks = mdata.get("attacks", [])
        if attacks:
            atk = attacks[0]
            ability = atk.get("ability", "str")
            atk_score = mdata.get(ability, 10)
            atk_mod = _ability_mod(atk_score)
            prof = mdata.get("proficiency_bonus", 2)
            combatants.append(Combatant(
                name=mdata["name"],
                hp=mdata.get("max_hp", 10),
                max_hp=mdata.get("max_hp", 10),
                ac=mdata.get("ac", 10),
                attack_mod=atk_mod + prof,
                damage_dice=atk.get("dice", 1),
                damage_sides=atk.get("sides", 4),
                damage_mod=atk_mod,
                dex_mod=_ability_mod(mdata.get("dex", 10)),
                is_party=False,
            ))
        else:
            # Fallback for monsters with no attacks defined
            combatants.append(Combatant(
                name=mdata.get("name", m["slug"]),
                hp=mdata.get("max_hp", 10),
                max_hp=mdata.get("max_hp", 10),
                ac=mdata.get("ac", 10),
                attack_mod=2, damage_dice=1, damage_sides=4, damage_mod=0,
                dex_mod=0, is_party=False,
            ))
    return combatants


def simulate_combat(
    party: list[Combatant],
    monsters: list[Combatant],
    rng: random.Random,
    max_rounds: int = 50,
) -> dict:
    """Simulate a single combat encounter. Returns stats dict."""
    all_combatants = party + monsters

    # Roll initiative
    init_order = [(c, rng.randint(1, 20) + c.dex_mod) for c in all_combatants]
    init_order.sort(key=lambda x: -x[1])

    rounds = 0
    for _ in range(max_rounds):
        rounds += 1
        for combatant, _ in init_order:
            if not combatant.alive:
                continue

            # Pick nearest living enemy
            enemies = [c for c in all_combatants if c.alive and c.is_party != combatant.is_party]
            if not enemies:
                break
            target = enemies[0]  # simplified: pick first alive enemy

            total, is_crit, is_fumble = combatant.roll_attack(rng)
            if is_fumble:
                continue
            if is_crit or total >= target.ac:
                dmg = combatant.roll_damage(rng, crit=is_crit)
                target.hp -= dmg
                if target.hp <= 0:
                    target.alive = False

        # Check if combat is over
        party_alive = any(c.alive for c in party)
        monsters_alive = any(c.alive for c in monsters)
        if not party_alive or not monsters_alive:
            break

    party_survived = any(c.alive for c in party)
    party_deaths = sum(1 for c in party if not c.alive)
    hp_remaining = sum(max(c.hp, 0) for c in party if c.alive)
    hp_max = sum(c.max_hp for c in party)

    return {
        "survived": party_survived,
        "deaths": party_deaths,
        "hp_remaining": hp_remaining,
        "hp_max": hp_max,
        "hp_pct": hp_remaining / hp_max if hp_max > 0 else 0,
        "rounds": rounds,
    }


@dataclass
class DungeonRunResult:
    survived: bool
    party_deaths: int
    hp_remaining_pct: float
    tpk_room_key: str | None  # "F{fi}R{rid} (name)" where TPK happened
    room_results: dict[str, dict]  # "floor_room" -> combat stats


def simulate_dungeon_run(
    data: dict,
    monster_registry: dict[str, dict],
    level: int,
    party_size: int,
    rng: random.Random,
) -> DungeonRunResult:
    """Simulate a full dungeon walkthrough with a fresh party."""
    party = _make_party(level, party_size)
    room_results: dict[str, dict] = {}

    for fi, floor_data in enumerate(data["floors"]):
        for room in floor_data["rooms"]:
            room_key = f"F{fi}R{room['id']}"
            room_label = f"{room_key} ({room['name']})"

            if room["type"] in ("combat", "boss"):
                monsters = _make_monsters(room, monster_registry)
                if monsters:
                    result = simulate_combat(party, monsters, rng)
                    room_results[room_key] = result

                    if not result["survived"]:
                        return DungeonRunResult(
                            survived=False,
                            party_deaths=party_size,
                            hp_remaining_pct=0,
                            tpk_room_key=room_label,
                            room_results=room_results,
                        )

            elif room["type"] == "trap" and room.get("trap"):
                trap = room["trap"]
                dc = trap.get("dc", 12)
                dice = trap.get("damage_dice", 1)
                sides = trap.get("damage_sides", 6)
                for c in party:
                    if not c.alive:
                        continue
                    save = rng.randint(1, 20) + c.dex_mod
                    if save < dc:
                        dmg = sum(rng.randint(1, sides) for _ in range(dice))
                        c.hp -= dmg
                        if c.hp <= 0:
                            c.alive = False
                if not any(c.alive for c in party):
                    return DungeonRunResult(
                        survived=False, party_deaths=party_size,
                        hp_remaining_pct=0, tpk_room_key=room_label,
                        room_results=room_results,
                    )

            # Between rooms: use basic healing on lowest HP member
            alive_members = [c for c in party if c.alive]
            if alive_members:
                lowest = min(alive_members, key=lambda c: c.hp / c.max_hp)
                if lowest.hp < lowest.max_hp * 0.5:
                    heal = rng.randint(1, 8) + 2  # ~cure wounds
                    lowest.hp = min(lowest.hp + heal, lowest.max_hp)

    hp_remaining = sum(max(c.hp, 0) for c in party if c.alive)
    hp_max = sum(c.max_hp for c in party)
    deaths = sum(1 for c in party if not c.alive)

    return DungeonRunResult(
        survived=True,
        party_deaths=deaths,
        hp_remaining_pct=hp_remaining / hp_max if hp_max > 0 else 0,
        tpk_room_key=None,
        room_results=room_results,
    )


@dataclass
class SimulationStats:
    runs: int
    survival_rate: float
    avg_hp_pct: float
    avg_deaths: float
    tpk_rooms: dict[str, int]  # room_key -> tpk count
    deadliest_room: str
    deadliest_tpk_rate: float


def run_monte_carlo(
    data: dict,
    monster_registry: dict[str, dict],
    level: int,
    party_size: int,
    runs: int,
    seed: int | None = None,
) -> SimulationStats:
    """Run N dungeon simulations and aggregate stats."""
    rng = random.Random(seed)
    survived_count = 0
    total_hp_pct = 0.0
    total_deaths = 0
    tpk_rooms: dict[str, int] = {}

    for _ in range(runs):
        result = simulate_dungeon_run(data, monster_registry, level, party_size, rng)
        if result.survived:
            survived_count += 1
        total_hp_pct += result.hp_remaining_pct
        total_deaths += result.party_deaths
        if result.tpk_room_key is not None:
            tpk_rooms[result.tpk_room_key] = tpk_rooms.get(result.tpk_room_key, 0) + 1

    deadliest = max(tpk_rooms, key=tpk_rooms.get) if tpk_rooms else "None"
    deadliest_rate = tpk_rooms.get(deadliest, 0) / runs if tpk_rooms else 0

    return SimulationStats(
        runs=runs,
        survival_rate=survived_count / runs,
        avg_hp_pct=total_hp_pct / runs,
        avg_deaths=total_deaths / runs,
        tpk_rooms=tpk_rooms,
        deadliest_room=deadliest,
        deadliest_tpk_rate=deadliest_rate,
    )


# ---------------------------------------------------------------------------
# ASCII Map Visualization
# ---------------------------------------------------------------------------

def render_ascii(grid: FloorGrid) -> str:
    """Render the floor grid as ASCII art."""
    lines = []
    for y in range(grid.height):
        row = []
        for x in range(grid.width):
            entities = grid.entities.get((x, y), [])
            # Priority: stairs > monster > item > terrain
            if any(e["type"] == "stairs_up" for e in entities):
                row.append("<")
            elif any(e["type"] == "stairs_down" for e in entities):
                row.append(">")
            elif any(e["type"] == "monster" for e in entities):
                row.append("M")
            elif any(e["type"] == "item" for e in entities):
                row.append("I")
            elif grid.terrain[x][y] == FLOOR:
                if grid.area_type[x][y] == AREA_CORRIDOR:
                    row.append("-")
                else:
                    row.append(".")
            else:
                row.append("#")
        lines.append("".join(row))
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Pixel-Accurate Map Rendering (matches Godot's MapRenderer)
# ---------------------------------------------------------------------------

def _load_tile_atlas() -> tuple[Any, dict[str, tuple[int, int]], int] | None:
    """Load the tile atlas image and coordinate map.

    Returns (atlas_image, tile_coords, tile_size) or None if unavailable.
    """
    if not TILE_ATLAS_PATH.exists() or not TILE_MAP_PATH.exists():
        return None
    try:
        from PIL import Image
    except ImportError:
        return None

    atlas = Image.open(TILE_ATLAS_PATH).convert("RGBA")
    with open(TILE_MAP_PATH, "r") as f:
        tile_data = json.load(f)

    tile_size = tile_data.get("tileSize", 16)
    sprites = tile_data.get("sprites", {})
    # Convert pixel coords to grid coords for cropping
    tile_coords: dict[str, tuple[int, int]] = {}
    for name, coords in sprites.items():
        tile_coords[name] = (coords[0], coords[1])

    return atlas, tile_coords, tile_size


def _get_wall_tile_name(grid: FloorGrid, x: int, y: int) -> str:
    """Replicate MapRenderer.get_wall_tile() wall selection logic exactly."""
    def is_wall(nx: int, ny: int) -> bool:
        if not grid._in_bounds(nx, ny):
            return False
        return grid.terrain[nx][ny] == WALL

    n = is_wall(x, y - 1)
    s = is_wall(x, y + 1)
    e = is_wall(x + 1, y)
    w = is_wall(x - 1, y)

    # Exact match of dungeon_loader.gd get_wall_tile logic
    if n and s and e and w:
        return "wall-5-nsew"
    elif n and s and e and not w:
        return "wall-5-nse"
    elif n and s and not e and w:
        return "wall-5-nsw"
    elif n and not s and e and w:
        return "wall-5-new"
    elif not n and s and e and w:
        return "wall-5-sew"
    elif n and s and not e and not w:
        return "wall-5-ns"
    elif not n and not s and e and w:
        return "wall-5-ew"
    elif n and e and not s and not w:
        return "wall-5-ne"
    elif n and w and not s and not e:
        return "wall-5-nw"
    elif s and e and not n and not w:
        return "wall-5-se"
    elif s and w and not n and not e:
        return "wall-5-sw"
    elif not n and not s and not w and e:
        return "wall-5-ew"
    elif not n and not s and w and not e:
        return "wall-5-ew"
    elif n and not s and not e and not w:
        return "wall-5-n"
    elif not n and s and not e and not w:
        return "wall-5-ns"
    else:
        return "wall-5-lone"


# Entity marker colors for overlay (no sprite sheets for monsters/items in headless mode)
_ENTITY_COLORS = {
    "monster": (220, 50, 50, 220),    # red
    "item": (50, 180, 255, 220),      # blue
    "stairs_up": (50, 220, 50, 220),  # green
    "stairs_down": (220, 180, 50, 220),  # yellow
}


def render_pixel_map(
    grids: list[FloorGrid],
    floor_names: list[str],
    output_path: str,
) -> str | None:
    """Render all floors as a pixel-accurate PNG using the game's tile atlas.

    Produces a vertical stack of floor images with labels.
    Returns the output path on success, or an error message.
    """
    atlas_data = _load_tile_atlas()
    if atlas_data is None:
        return "Could not load tile atlas (missing world_tiles.png/json or Pillow)"

    from PIL import Image, ImageDraw, ImageFont

    atlas, tile_coords, tile_size = atlas_data

    def get_tile(name: str) -> Image.Image:
        """Extract a tile from the atlas by name."""
        if name not in tile_coords:
            name = "debug"
        if name not in tile_coords:
            # Fallback: solid color tile
            return Image.new("RGBA", (tile_size, tile_size), (255, 0, 255, 255))
        px, py = tile_coords[name]
        return atlas.crop((px, py, px + tile_size, py + tile_size))

    # Header height for floor labels
    header_h = 20
    padding = 4

    # Calculate total image size
    total_width = 0
    total_height = 0
    floor_dims: list[tuple[int, int]] = []
    for grid in grids:
        w = grid.width * tile_size
        h = grid.height * tile_size + header_h
        floor_dims.append((w, h))
        total_width = max(total_width, w + padding * 2)
        total_height += h + padding

    total_height += padding  # bottom padding

    # Create the output image
    img = Image.new("RGBA", (total_width, total_height), (30, 25, 35, 255))
    draw = ImageDraw.Draw(img)

    y_offset = padding
    for fi, (grid, floor_name) in enumerate(zip(grids, floor_names)):
        fw, fh = floor_dims[fi]

        # Draw floor label
        draw.text((padding + 2, y_offset + 2), f"Floor {fi}: {floor_name}", fill=(200, 200, 200, 255))
        y_offset += header_h

        # Draw tiles
        for gx in range(grid.width):
            for gy in range(grid.height):
                px = padding + gx * tile_size
                py = y_offset + gy * tile_size

                if grid.terrain[gx][gy] == FLOOR:
                    tile = get_tile("floor-7-nsew")
                    img.paste(tile, (px, py), tile)
                else:
                    # Wall — use contextual tile selection
                    wall_name = _get_wall_tile_name(grid, gx, gy)
                    tile = get_tile(wall_name)
                    img.paste(tile, (px, py), tile)

                # Obstacles (stairs)
                entities = grid.entities.get((gx, gy), [])
                for ent in entities:
                    etype = ent["type"]
                    if etype == "stairs_up":
                        tile = get_tile("tile-28")
                        img.paste(tile, (px, py), tile)
                    elif etype == "stairs_down":
                        tile = get_tile("tile-31")
                        img.paste(tile, (px, py), tile)
                    elif etype in ("monster", "item"):
                        # Draw colored marker (no sprite sheets in headless)
                        color = _ENTITY_COLORS.get(etype, (255, 255, 255, 200))
                        marker_size = tile_size // 2
                        offset = (tile_size - marker_size) // 2
                        draw.ellipse(
                            [px + offset, py + offset,
                             px + offset + marker_size, py + offset + marker_size],
                            fill=color, outline=(255, 255, 255, 180),
                        )

        y_offset += grid.height * tile_size + padding

    # Add legend at the bottom
    legend_y = y_offset
    legend_items = [
        ("Monster", _ENTITY_COLORS["monster"]),
        ("Item", _ENTITY_COLORS["item"]),
        ("Stairs Up", _ENTITY_COLORS["stairs_up"]),
        ("Stairs Down", _ENTITY_COLORS["stairs_down"]),
    ]
    lx = padding + 2
    for label, color in legend_items:
        draw.ellipse([lx, legend_y + 2, lx + 10, legend_y + 12], fill=color)
        draw.text((lx + 14, legend_y + 1), label, fill=(180, 180, 180, 255))
        lx += len(label) * 7 + 24

    # Expand image to fit legend
    if legend_y + 18 > total_height:
        new_img = Image.new("RGBA", (total_width, legend_y + 20), (30, 25, 35, 255))
        new_img.paste(img, (0, 0))
        img = new_img

    img.save(output_path)
    return None


# ---------------------------------------------------------------------------
# Report Generation
# ---------------------------------------------------------------------------

def generate_report(
    data: dict,
    monster_registry: dict[str, dict],
    level: int,
    party_size: int,
    runs: int,
    seed: int | None,
    as_json: bool = False,
) -> tuple[str, int]:
    """Generate full simulation report. Returns (report_text, exit_code)."""
    all_errors: list[str] = []
    all_warnings: list[str] = []
    floor_reports: list[dict] = []
    grids: list[FloorGrid] = []

    # Cross-floor validation
    cross_errors = validate_cross_floor(data)
    all_errors.extend(cross_errors)

    for fi, floor_data in enumerate(data["floors"]):
        rooms_by_id = {r["id"]: r for r in floor_data["rooms"]}
        grid = build_floor_grid(floor_data, rooms_by_id)
        grids.append(grid)

        # Connectivity
        conn_errors = validate_connectivity(grid, floor_data)
        all_errors.extend([f"Floor {fi}: {e}" for e in conn_errors])

        # Encounter balance
        ratings = rate_encounters(floor_data, monster_registry, level, party_size)
        for r in ratings:
            all_warnings.extend([f"Floor {fi}: {w}" for w in r.warnings])

        # Spatial placement
        placement_warnings = validate_placement(grid, floor_data, monster_registry)
        all_warnings.extend([f"Floor {fi}: {w}" for w in placement_warnings])

        # Loot
        loot_warnings = validate_loot(floor_data)
        all_warnings.extend([f"Floor {fi}: {w}" for w in loot_warnings])

        floor_reports.append({
            "floor_index": fi,
            "floor_name": floor_data.get("name", f"Floor {fi}"),
            "dimensions": f"{floor_data['width']}x{floor_data['height']}",
            "rooms": len(floor_data["rooms"]),
            "connectivity_errors": conn_errors,
            "encounter_ratings": ratings,
            "placement_warnings": placement_warnings,
            "loot_warnings": loot_warnings,
            "ascii_map": render_ascii(grid),
        })

    # Monte Carlo simulation
    sim_stats = run_monte_carlo(data, monster_registry, level, party_size, runs, seed)

    # Determine verdict
    has_errors = len(all_errors) > 0
    low_survival = sim_stats.survival_rate < 0.5
    verdict = "ISSUES FOUND" if (has_errors or low_survival) else "PLAYABLE"
    exit_code = 1 if verdict == "ISSUES FOUND" else 0

    if as_json:
        json_report = {
            "dungeon_name": data.get("name", "Unknown"),
            "verdict": verdict,
            "errors": all_errors,
            "warnings": all_warnings,
            "floors": [
                {
                    "name": fr["floor_name"],
                    "dimensions": fr["dimensions"],
                    "rooms": fr["rooms"],
                    "connectivity_errors": fr["connectivity_errors"],
                    "encounters": [
                        {
                            "room_id": r.room_id,
                            "room_name": r.room_name,
                            "room_type": r.room_type,
                            "monsters": r.monster_slugs,
                            "raw_xp": r.raw_xp,
                            "adjusted_xp": r.adjusted_xp,
                            "difficulty": r.difficulty,
                            "warnings": r.warnings,
                        }
                        for r in fr["encounter_ratings"]
                    ],
                    "placement_warnings": fr["placement_warnings"],
                    "loot_warnings": fr["loot_warnings"],
                }
                for fr in floor_reports
            ],
            "simulation": {
                "runs": sim_stats.runs,
                "party_level": level,
                "party_size": party_size,
                "survival_rate": round(sim_stats.survival_rate, 3),
                "avg_hp_remaining_pct": round(sim_stats.avg_hp_pct, 3),
                "avg_deaths": round(sim_stats.avg_deaths, 2),
                "deadliest_room": sim_stats.deadliest_room,
                "deadliest_tpk_rate": round(sim_stats.deadliest_tpk_rate, 3),
                "tpk_by_room": {k: v for k, v in sim_stats.tpk_rooms.items()},
            },
        }
        return json.dumps(json_report, indent=2), exit_code

    # Human-readable report
    lines: list[str] = []
    lines.append(f"=== DUNGEON SIMULATION: {data.get('name', 'Unknown')} ===")
    lines.append(f"Party: {party_size}x Level {level} | Runs: {runs}")
    lines.append("")

    for fr in floor_reports:
        lines.append(f"--- Floor {fr['floor_index']}: {fr['floor_name']} ({fr['dimensions']}) ---")
        lines.append("")
        # ASCII map (indented)
        for map_line in fr["ascii_map"].split("\n"):
            lines.append(f"  {map_line}")
        lines.append("")

        # Connectivity
        if fr["connectivity_errors"]:
            lines.append(f"  CONNECTIVITY: FAIL")
            for e in fr["connectivity_errors"]:
                lines.append(f"    ERROR: {e}")
        else:
            lines.append(f"  CONNECTIVITY: OK (all {fr['rooms']} rooms reachable from entrance)")

        # Encounters
        lines.append("  ENCOUNTERS:")
        for r in fr["encounter_ratings"]:
            if r.monster_slugs:
                slug_counts: dict[str, int] = {}
                for s in r.monster_slugs:
                    slug_counts[s] = slug_counts.get(s, 0) + 1
                slug_str = ", ".join(f"{c}x {s}" for s, c in slug_counts.items())
                lines.append(
                    f"    Room {r.room_id} ({r.room_name}): "
                    f"{slug_str} = {r.raw_xp} XP "
                    f"(x{_encounter_multiplier(len(r.monster_slugs))} = {r.adjusted_xp} adj) "
                    f"-> {r.difficulty}"
                )
            else:
                lines.append(f"    Room {r.room_id} ({r.room_name}): {r.difficulty}")
            for w in r.warnings:
                lines.append(f"      WARNING: {w}")

        # Placement
        if fr["placement_warnings"]:
            lines.append(f"  PLACEMENT: {len(fr['placement_warnings'])} warning(s)")
            for w in fr["placement_warnings"]:
                lines.append(f"    {w}")
        else:
            lines.append("  PLACEMENT: OK")

        # Loot
        if fr["loot_warnings"]:
            lines.append(f"  LOOT: {len(fr['loot_warnings'])} warning(s)")
            for w in fr["loot_warnings"]:
                lines.append(f"    {w}")
        else:
            lines.append("  LOOT: OK")

        lines.append("")

    # Simulation results
    lines.append(f"COMBAT SIMULATION ({sim_stats.runs} runs, party: {party_size}x Level {level}):")
    lines.append(f"  Survival rate: {sim_stats.survival_rate:.0%}")
    lines.append(f"  Average HP remaining: {sim_stats.avg_hp_pct:.0%}")
    lines.append(f"  Average deaths per run: {sim_stats.avg_deaths:.1f}")
    lines.append(f"  Deadliest room: {sim_stats.deadliest_room} — {sim_stats.deadliest_tpk_rate:.0%} TPK rate")
    if sim_stats.tpk_rooms:
        lines.append("  TPK breakdown:")
        for room_key, count in sorted(sim_stats.tpk_rooms.items(), key=lambda x: -x[1]):
            lines.append(f"    {room_key}: {count}/{sim_stats.runs} ({count/sim_stats.runs:.0%})")
    lines.append("")

    # Errors/warnings summary
    if all_errors:
        lines.append(f"ERRORS ({len(all_errors)}):")
        for e in all_errors:
            lines.append(f"  {e}")
        lines.append("")

    if all_warnings:
        lines.append(f"WARNINGS ({len(all_warnings)}):")
        for w in all_warnings:
            lines.append(f"  {w}")
        lines.append("")

    lines.append(f"VERDICT: {verdict} ({len(all_errors)} errors, {len(all_warnings)} warnings)")

    return "\n".join(lines), exit_code


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main() -> int:
    parser = argparse.ArgumentParser(
        description="Headless dungeon simulation and playability validator."
    )
    parser.add_argument("file", help="Path to the dungeon JSON file")
    parser.add_argument("--level", type=int, default=1, help="Party level (default: 1)")
    parser.add_argument("--party-size", type=int, default=4, help="Party size (default: 4)")
    parser.add_argument("--runs", type=int, default=100, help="Monte Carlo iterations (default: 100)")
    parser.add_argument("--json", action="store_true", help="JSON output mode")
    parser.add_argument("--seed", type=int, default=None, help="Random seed for reproducibility")
    parser.add_argument("--render", type=str, default=None,
                        metavar="FILE.png",
                        help="Render pixel-accurate map preview to PNG (uses game tile atlas)")

    args = parser.parse_args()

    # Load dungeon
    try:
        with open(args.file, "r") as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        print(f"ERROR: Invalid JSON: {e}", file=sys.stderr)
        return 1
    except FileNotFoundError:
        print(f"ERROR: File not found: {args.file}", file=sys.stderr)
        return 1

    if not isinstance(data, dict) or "floors" not in data:
        print("ERROR: Invalid dungeon format (missing 'floors')", file=sys.stderr)
        return 1

    # Load monster registry
    monster_registry = load_monster_registry()
    if not monster_registry:
        print("WARNING: Could not load monster registry — combat simulation will be limited",
              file=sys.stderr)

    report, exit_code = generate_report(
        data, monster_registry,
        level=args.level,
        party_size=args.party_size,
        runs=args.runs,
        seed=args.seed,
        as_json=args.json,
    )

    print(report)

    # Render pixel map if requested
    if args.render:
        grids = []
        floor_names = []
        for floor_data in data["floors"]:
            rooms_by_id = {r["id"]: r for r in floor_data["rooms"]}
            grids.append(build_floor_grid(floor_data, rooms_by_id))
            floor_names.append(floor_data.get("name", f"Floor {len(grids)-1}"))

        err = render_pixel_map(grids, floor_names, args.render)
        if err:
            print(f"Render error: {err}", file=sys.stderr)
        else:
            print(f"Map preview saved to: {args.render}")

    return exit_code


if __name__ == "__main__":
    sys.exit(main())
