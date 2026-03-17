#!/usr/bin/env python3
"""
Convert 5e-bits/5e-database class data to our game's classes.json format.

Source: 5e-bits/5e-database src/2014/5e-SRD-Classes.json (12 classes, MIT license)
Target: game/assets/data/classes.json
"""

import argparse
import json
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_DIR = SCRIPT_DIR.parent

DEFAULT_SOURCE = Path("/tmp/5e-database/src/2014/5e-SRD-Classes.json")
DEFAULT_TARGET = PROJECT_DIR / "game" / "assets" / "data" / "classes.json"

# SRD class descriptions
DESCRIPTIONS: dict[str, str] = {
    "barbarian": "A fierce warrior of primitive background who can enter a battle rage.",
    "bard": "An inspiring magician whose power echoes the music of creation.",
    "cleric": "A priestly champion who wields divine magic in service of a higher power.",
    "druid": "A priest of the Old Faith, wielding the powers of nature and adopting animal forms.",
    "fighter": "A master of martial combat, skilled with a variety of weapons and armor.",
    "monk": "A master of martial arts, harnessing the power of the body in pursuit of perfection.",
    "paladin": "A holy warrior bound to a sacred oath, combining martial prowess with divine magic.",
    "ranger": "A warrior who combats threats on the edges of civilization.",
    "rogue": "A scoundrel who uses stealth and trickery to overcome obstacles and enemies.",
    "sorcerer": "A spellcaster who draws on inherent magic from a gift or bloodline.",
    "warlock": "A wielder of magic derived from a bargain with an extraplanar entity.",
    "wizard": "A scholarly magic-user capable of manipulating the structures of reality.",
}

# Primary ability for each class (not in 5e-database, derived from SRD)
PRIMARY_ABILITY: dict[str, str] = {
    "barbarian": "str",
    "bard": "cha",
    "cleric": "wis",
    "druid": "wis",
    "fighter": "str",
    "monk": "dex",
    "paladin": "str",
    "ranger": "dex",
    "rogue": "dex",
    "sorcerer": "cha",
    "warlock": "cha",
    "wizard": "int",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Convert 5e-database classes to game format")
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE,
                        help="Path to 5e-SRD-Classes.json")
    parser.add_argument("--target", type=Path, default=DEFAULT_TARGET,
                        help="Output path for classes.json")
    return parser.parse_args()


def parse_armor_proficiencies(proficiencies: list[dict]) -> list[str]:
    """Extract armor proficiency categories from class proficiencies."""
    armor = []
    for p in proficiencies:
        idx = p.get("index", "")
        if idx == "all-armor":
            return ["light", "medium", "heavy"]
        if idx == "light-armor":
            armor.append("light")
        elif idx == "medium-armor":
            armor.append("medium")
        elif idx == "heavy-armor":
            armor.append("heavy")
    return armor


def has_shield_proficiency(proficiencies: list[dict]) -> bool:
    return any(p.get("index") == "shields" for p in proficiencies)


def parse_skill_choices(proficiency_choices: list[dict]) -> tuple[int, list[str]]:
    """Extract skill choice count and options from proficiency_choices."""
    for choice in proficiency_choices:
        options = choice.get("from", {}).get("options", [])
        skill_opts = []
        for opt in options:
            idx = opt.get("item", {}).get("index", "")
            if idx.startswith("skill-"):
                skill_opts.append(idx.removeprefix("skill-").replace("-", "_"))
        if skill_opts:
            return choice.get("choose", 2), skill_opts
    return 2, []


def convert_class(source: dict) -> dict:
    """Convert a single 5e-database class to our format."""
    idx = source["index"]
    saves = [s["index"] for s in source.get("saving_throws", [])]

    profs = source.get("proficiencies", [])
    armor = parse_armor_proficiencies(profs)
    if has_shield_proficiency(profs):
        armor.append("shields")

    num_skills, skill_choices = parse_skill_choices(source.get("proficiency_choices", []))

    return {
        "name": source["name"],
        "description": DESCRIPTIONS.get(idx, source["name"]),
        "hit_die": source["hit_die"],
        "primary_ability": PRIMARY_ABILITY.get(idx, "str"),
        "saving_throws": saves,
        "armor_proficiencies": armor,
        "num_skills": num_skills,
        "skill_choices": skill_choices,
    }


def main():
    args = parse_args()

    print(f"Loading source data from {args.source}...")
    with open(args.source, "r", encoding="utf-8") as f:
        source_classes = json.load(f)
    print(f"  Loaded {len(source_classes)} classes")

    output = {}
    for source in source_classes:
        idx = source["index"]
        output[idx] = convert_class(source)
        print(f"  {idx}: hit_die=d{source['hit_die']}, saves={output[idx]['saving_throws']}, "
              f"skills={output[idx]['num_skills']} from {len(output[idx]['skill_choices'])} choices")

    args.target.parent.mkdir(parents=True, exist_ok=True)
    with open(args.target, "w", encoding="utf-8") as f:
        json.dump(output, f, indent=2, ensure_ascii=False)

    print(f"\nWrote {len(output)} classes to {args.target}")


if __name__ == "__main__":
    main()
