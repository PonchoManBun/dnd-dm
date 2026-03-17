#!/usr/bin/env python3
"""
Convert 5e-bits/5e-database monster data to our game's dnd_monsters.json format.

Source: 5e-bits/5e-database src/2014/5e-SRD-Monsters.json (334 monsters, MIT license)
Target: game/assets/data/dnd_monsters.json

The 5e-database is the single source of truth. Game-specific fields (appearance,
faction, behavior, hit_particles_color, sight_radius) are derived from monster
type and CR.
"""

import argparse
import json
import re
import sys
from pathlib import Path
from collections import Counter

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_DIR = SCRIPT_DIR.parent

DEFAULT_SOURCE = Path("/tmp/5e-database/src/2014/5e-SRD-Monsters.json")
DEFAULT_TARGET = PROJECT_DIR / "game" / "assets" / "data" / "dnd_monsters.json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Convert 5e-database monsters to game format")
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE,
                        help="Path to 5e-SRD-Monsters.json")
    parser.add_argument("--target", type=Path, default=DEFAULT_TARGET,
                        help="Output path for dnd_monsters.json")
    return parser.parse_args()


def load_source_monsters(source_path: Path) -> list[dict]:
    """Load the 5e-database monsters.json."""
    with open(source_path, "r", encoding="utf-8") as f:
        return json.load(f)


def slug_from_index(index: str) -> str:
    """Convert 5e-database index (hyphen-separated) to our slug (underscore-separated)."""
    return index.replace("-", "_")


def parse_speed(speed_data: dict) -> int:
    """Parse speed from 5e-database format. Returns feet as integer."""
    walk = speed_data.get("walk", "30 ft.")

    # Parse walk speed
    walk_speed = 0
    if walk:
        match = re.search(r"(\d+)", str(walk))
        if match:
            walk_speed = int(match.group(1))

    # If walk speed is 0, try other movement modes (fly, swim, etc.)
    if walk_speed == 0:
        for key in ["fly", "swim", "burrow", "climb"]:
            alt = speed_data.get(key)
            if alt:
                match = re.search(r"(\d+)", str(alt))
                if match:
                    alt_speed = int(match.group(1))
                    if alt_speed > 0:
                        return alt_speed

    return walk_speed


def parse_ac(armor_class: list[dict]) -> tuple[int, str]:
    """Parse armor class value and note from 5e-database format."""
    if not armor_class:
        return 10, ""

    ac_entry = armor_class[0]
    value = ac_entry.get("value", 10)
    ac_type = ac_entry.get("type", "")

    # Build AC note
    if ac_type == "natural":
        note = "natural armor"
    elif ac_type == "armor":
        armor_list = ac_entry.get("armor", [])
        if armor_list:
            names = [a.get("name", "") for a in armor_list]
            note = ", ".join(n for n in names if n).lower()
        else:
            note = ac_entry.get("desc", "")
    elif ac_type == "spell":
        note = "spell"
    elif ac_type == "condition":
        note = ac_entry.get("desc", "condition")
    elif ac_type == "dex":
        # Just DEX-based, typically no note unless there's a desc
        note = ac_entry.get("desc", "")
    else:
        note = ac_entry.get("desc", "")

    return value, note


def parse_damage_dice(dice_str: str) -> tuple[int, int]:
    """Parse damage dice string like '2d6+5' into (dice_count, sides).

    Returns (dice, sides). The modifier is ignored since our game
    computes it from ability scores.
    """
    if not dice_str:
        return 1, 4

    match = re.match(r"(\d+)d(\d+)", dice_str)
    if match:
        return int(match.group(1)), int(match.group(2))
    return 1, 4


def parse_range_from_desc(desc: str) -> int | None:
    """Parse range from action description.

    Examples:
        "range 80/320 ft." -> 16 (80ft / 5ft per tile)
        "range 25/50 ft." -> 5
        "range 150/600 ft." -> 30

    Returns short range in tiles (5ft per tile), or None if no range found.
    """
    match = re.search(r"range\s+(\d+)/\d+\s*ft\.", desc, re.IGNORECASE)
    if match:
        short_range_ft = int(match.group(1))
        return short_range_ft // 5
    return None


def determine_attack_type(desc: str) -> str:
    """Determine if an attack is melee or ranged from its description."""
    desc_lower = desc.lower() if desc else ""
    if "ranged weapon attack" in desc_lower or "ranged spell attack" in desc_lower:
        return "ranged"
    if "melee or ranged" in desc_lower:
        return "melee"  # Default to melee for versatile attacks
    return "melee"


def infer_attack_ability(attack_type: str, monster: dict) -> str:
    """Infer which ability score an attack uses.

    - Melee attacks typically use STR, unless DEX is higher (finesse)
    - Ranged attacks typically use DEX
    """
    if attack_type == "ranged":
        return "dex"

    str_val = monster.get("strength", 10)
    dex_val = monster.get("dexterity", 10)

    # Finesse: if DEX > STR, likely using DEX for melee
    if dex_val > str_val:
        return "dex"
    return "str"


def convert_actions_to_attacks(actions: list[dict], monster: dict) -> list[dict]:
    """Convert 5e-database actions to our attack format.

    Only converts actions that have both attack_bonus and damage fields.
    Skips Multiattack, special actions, etc.
    """
    attacks = []
    seen_names = set()

    for action in actions:
        # Skip if no attack_bonus or no damage
        if "attack_bonus" not in action or not action.get("damage"):
            continue

        name = action.get("name", "Attack")
        if name in seen_names:
            continue
        seen_names.add(name)

        desc = action.get("desc", "")
        attack_type = determine_attack_type(desc)
        ability = infer_attack_ability(attack_type, monster)

        # Get primary damage (first entry)
        primary_damage = action["damage"][0]
        damage_type = primary_damage.get("damage_type", {}).get("index", "bludgeoning")
        damage_dice_str = primary_damage.get("damage_dice", "1d4")
        dice, sides = parse_damage_dice(damage_dice_str)

        attack_data: dict = {
            "name": name,
            "type": attack_type,
            "ability": ability,
            "dice": dice,
            "sides": sides,
            "damage_type": damage_type,
        }

        # Add range for ranged attacks
        if attack_type == "ranged":
            range_tiles = parse_range_from_desc(desc)
            if range_tiles:
                attack_data["range"] = range_tiles
            else:
                attack_data["range"] = 6  # Default 30ft range

        attacks.append(attack_data)

    return attacks


def convert_special_abilities(abilities: list[dict]) -> list[str]:
    """Convert special ability names to lowercase underscore tags."""
    specials = []
    for ability in abilities:
        name = ability.get("name", "")
        # Convert to snake_case tag
        tag = re.sub(r"[^a-zA-Z0-9\s]", "", name)
        tag = re.sub(r"\s+", "_", tag.strip()).lower()
        if tag:
            specials.append(tag)
    return specials


def parse_darkvision(senses: dict) -> int:
    """Parse darkvision distance and convert to tile radius (5ft/tile)."""
    dv = senses.get("darkvision", "")
    if not dv:
        return 8  # Default sight radius for monsters without darkvision
    match = re.search(r"(\d+)", str(dv))
    if match:
        feet = int(match.group(1))
        return feet // 5
    return 8


def derive_faction(monster_type: str) -> str:
    """Derive faction from monster type."""
    monster_type = monster_type.lower()
    if monster_type == "undead":
        return "undead"
    if monster_type in ("beast", "swarm of tiny beasts"):
        return "critters"
    return "monsters"


def derive_behavior(cr: float) -> str:
    """Derive behavior from challenge rating."""
    if cr <= 0:
        return "passive"
    if cr <= 0.25:
        return "aggressive"
    return "aggressive"


def derive_hit_particles_color(monster_type: str) -> str:
    """Derive hit particle color from monster type."""
    monster_type = monster_type.lower()
    if monster_type == "undead":
        return "#88ff88"
    if monster_type in ("beast", "swarm of tiny beasts"):
        return "#ff8844"
    if monster_type == "ooze":
        return "#44ff44"
    if monster_type == "construct":
        return "#cccccc"
    if monster_type == "elemental":
        return "#ffaa22"
    if monster_type == "plant":
        return "#44aa22"
    if monster_type in ("celestial", "fey"):
        return "#ffdd88"
    if monster_type == "fiend":
        return "#cc2222"
    if monster_type == "dragon":
        return "#ff4444"
    return "#ff3333"


def extract_damage_list(raw_list: list) -> list[str]:
    """Extract damage type strings from various source formats.

    The 5e-database uses plain strings for damage_vulnerabilities,
    damage_resistances, and damage_immunities.
    """
    result = []
    for item in raw_list:
        if isinstance(item, str):
            result.append(item)
        elif isinstance(item, dict):
            idx = item.get("index", "")
            if idx:
                result.append(idx)
    return result


def extract_condition_immunities(raw_list: list) -> list[str]:
    """Extract condition immunity indices from 5e-database format.

    condition_immunities are objects with index/name/url.
    """
    result = []
    for item in raw_list:
        if isinstance(item, dict):
            idx = item.get("index", "")
            if idx:
                result.append(idx)
        elif isinstance(item, str):
            result.append(item)
    return result


def convert_monster(source: dict) -> dict:
    """Convert a single 5e-database monster to our format.

    All fields are derived from the 5e-database (single source of truth).
    Game-specific fields are derived from monster type and CR.
    """
    slug = slug_from_index(source["index"])
    monster_type = source.get("type", "humanoid").lower()
    cr = source.get("challenge_rating", 0)

    # Parse AC
    ac_value, ac_note = parse_ac(source.get("armor_class", []))

    # Parse speed
    speed = parse_speed(source.get("speed", {}))

    # Convert attacks from actions
    attacks = convert_actions_to_attacks(source.get("actions", []), source)

    # Convert special abilities
    special = convert_special_abilities(source.get("special_abilities", []))

    # Parse senses for sight radius
    sight_radius = parse_darkvision(source.get("senses", {}))

    # Damage vulnerabilities, resistances, immunities
    vulnerabilities = extract_damage_list(source.get("damage_vulnerabilities", []))
    resistances = extract_damage_list(source.get("damage_resistances", []))
    immunities = extract_damage_list(source.get("damage_immunities", []))
    condition_immunities = extract_condition_immunities(source.get("condition_immunities", []))

    # Build the monster entry
    result: dict = {
        "name": source.get("name", "Unknown"),
        "slug": slug,
        "species": monster_type,
        "size": source.get("size", "Medium"),
        "faction": derive_faction(monster_type),
        "behavior": derive_behavior(cr),
        "appearance": "",
        "cr": cr,
        "str": source.get("strength", 10),
        "dex": source.get("dexterity", 10),
        "con": source.get("constitution", 10),
        "int": source.get("intelligence", 10),
        "wis": source.get("wisdom", 10),
        "cha": source.get("charisma", 10),
        "max_hp": source.get("hit_points", 10),
        "hit_dice": source.get("hit_dice", "1d8"),
        "ac": ac_value,
        "speed": speed,
        "proficiency_bonus": source.get("proficiency_bonus", 2),
        "xp": source.get("xp", 0),
        "sight_radius": sight_radius,
        "hit_particles_color": derive_hit_particles_color(monster_type),
    }

    # Add ac_note only if non-empty
    if ac_note:
        result["ac_note"] = ac_note

    # Add attacks if any
    if attacks:
        result["attacks"] = attacks

    # Add optional list fields only if non-empty
    if vulnerabilities:
        result["vulnerabilities"] = vulnerabilities
    if resistances:
        result["resistances"] = resistances
    if immunities:
        result["immunities"] = immunities
    if condition_immunities:
        result["condition_immunities"] = condition_immunities
    if special:
        result["special"] = special

    return result


def main():
    args = parse_args()

    print(f"Loading source data from {args.source}...")
    source_monsters = load_source_monsters(args.source)
    print(f"  Loaded {len(source_monsters)} monsters from 5e-database")

    # Convert all monsters
    output = {}
    stats = {
        "total": 0,
        "with_attacks": 0,
        "cr_distribution": Counter(),
        "type_distribution": Counter(),
    }

    for source in source_monsters:
        slug = slug_from_index(source["index"])
        monster = convert_monster(source)
        output[slug] = monster

        # Track stats
        stats["total"] += 1
        if monster.get("attacks"):
            stats["with_attacks"] += 1
        stats["cr_distribution"][source.get("challenge_rating", 0)] += 1
        stats["type_distribution"][source.get("type", "unknown")] += 1

    # Sort by slug alphabetically
    sorted_output = dict(sorted(output.items()))

    # Write output
    print(f"\nWriting {len(sorted_output)} monsters to {args.target}...")
    args.target.parent.mkdir(parents=True, exist_ok=True)
    with open(args.target, "w", encoding="utf-8") as f:
        json.dump(sorted_output, f, indent=2, ensure_ascii=False)
    print("  Done!")

    # Print summary
    print("\n" + "=" * 60)
    print("CONVERSION SUMMARY")
    print("=" * 60)
    print(f"Total monsters converted: {stats['total']}")
    print(f"Monsters with attacks:    {stats['with_attacks']}")

    print(f"\nCR Distribution:")
    for cr in sorted(stats["cr_distribution"].keys()):
        count = stats["cr_distribution"][cr]
        bar = "#" * count
        print(f"  CR {cr:>5}: {count:>3} {bar}")

    print(f"\nType Distribution:")
    for monster_type, count in sorted(stats["type_distribution"].items(), key=lambda x: -x[1]):
        bar = "#" * count
        print(f"  {monster_type:<25} {count:>3} {bar}")


if __name__ == "__main__":
    main()
