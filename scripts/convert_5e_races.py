#!/usr/bin/env python3
"""
Convert 5e-bits/5e-database race data to our game's races.json format.

Source: 5e-bits/5e-database src/2014/5e-SRD-Races.json (9 races, MIT license)
Target: game/assets/data/races.json
"""

import argparse
import json
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_DIR = SCRIPT_DIR.parent

DEFAULT_SOURCE = Path("/tmp/5e-database/src/2014/5e-SRD-Races.json")
DEFAULT_TARGET = PROJECT_DIR / "game" / "assets" / "data" / "races.json"

# SRD race descriptions
DESCRIPTIONS: dict[str, str] = {
    "dwarf": "Bold and hardy, dwarves are known as skilled warriors and craftsmen.",
    "elf": "Graceful and long-lived, elves are attuned to magic and nature.",
    "halfling": "Small but brave, halflings are resourceful and lucky.",
    "human": "Versatile and ambitious, humans are the most common race.",
    "dragonborn": "Born of dragons, dragonborn walk proudly through a world that greets them with fearful incomprehension.",
    "gnome": "Curious and inventive, gnomes delight in discovery and creation.",
    "half-elf": "Walking in two worlds but truly belonging to neither, half-elves combine the best qualities of their parents.",
    "half-orc": "Fierce and enduring, half-orcs combine human versatility with orcish might.",
    "tiefling": "To be greeted with stares and whispers, to suffer violence and insult — such is the lot of the tiefling.",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Convert 5e-database races to game format")
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE,
                        help="Path to 5e-SRD-Races.json")
    parser.add_argument("--target", type=Path, default=DEFAULT_TARGET,
                        help="Output path for races.json")
    return parser.parse_args()


def convert_race(source: dict) -> dict:
    """Convert a single 5e-database race to our format."""
    idx = source["index"]

    # Parse ability bonuses
    ability_bonuses = {}
    for bonus in source.get("ability_bonuses", []):
        ability = bonus["ability_score"]["index"]
        ability_bonuses[ability] = bonus["bonus"]

    # Parse traits
    traits = [t["name"] for t in source.get("traits", [])]

    # Use underscore key for consistency (half-elf -> half_elf)
    key = idx.replace("-", "_")

    return key, {
        "name": source["name"],
        "description": DESCRIPTIONS.get(idx, source["name"]),
        "ability_bonuses": ability_bonuses,
        "speed": source.get("speed", 30),
        "size": source.get("size", "Medium"),
        "traits": traits,
    }


def main():
    args = parse_args()

    print(f"Loading source data from {args.source}...")
    with open(args.source, "r", encoding="utf-8") as f:
        source_races = json.load(f)
    print(f"  Loaded {len(source_races)} races")

    output = {}
    for source in source_races:
        key, data = convert_race(source)
        output[key] = data
        bonuses_str = ", ".join(f"{k}+{v}" for k, v in data["ability_bonuses"].items())
        print(f"  {key}: speed={data['speed']}, size={data['size']}, bonuses=[{bonuses_str}], "
              f"traits={data['traits']}")

    args.target.parent.mkdir(parents=True, exist_ok=True)
    with open(args.target, "w", encoding="utf-8") as f:
        json.dump(output, f, indent=2, ensure_ascii=False)

    print(f"\nWrote {len(output)} races to {args.target}")


if __name__ == "__main__":
    main()
