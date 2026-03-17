"""Main SRD data loader — loads and caches 5e monsters, spells, equipment, magic items.

All data is loaded lazily on first access and cached at module level.
"""

from __future__ import annotations

import json
import logging
from pathlib import Path
from typing import Any

from orchestrator.data.spell_data import SpellInfo, parse_spell
from orchestrator.data.equipment_data import (
    EquipmentInfo,
    MagicItemInfo,
    parse_equipment,
    parse_magic_item,
)

logger = logging.getLogger(__name__)

# Paths (relative to this file)
_DATA_DIR = Path(__file__).parent
_MONSTERS_PATH = _DATA_DIR.parent.parent / "game" / "assets" / "data" / "dnd_monsters.json"
_SPELLS_PATH = _DATA_DIR / "srd_spells.json"
_EQUIPMENT_PATH = _DATA_DIR / "srd_equipment.json"
_MAGIC_ITEMS_PATH = _DATA_DIR / "srd_magic_items.json"

# Module-level caches
_monsters_cache: dict[str, dict[str, Any]] | None = None
_spells_cache: dict[str, SpellInfo] | None = None
_equipment_cache: dict[str, EquipmentInfo] | None = None
_magic_items_cache: dict[str, MagicItemInfo] | None = None


# ---------------------------------------------------------------------------
# Loaders
# ---------------------------------------------------------------------------


def load_srd_monsters() -> dict[str, dict[str, Any]]:
    """Load monster data from dnd_monsters.json (keyed by slug)."""
    global _monsters_cache
    if _monsters_cache is not None:
        return _monsters_cache

    try:
        with open(_MONSTERS_PATH, "r", encoding="utf-8") as f:
            raw = json.load(f)
    except FileNotFoundError:
        logger.warning("Monster data not found at %s", _MONSTERS_PATH)
        _monsters_cache = {}
        return _monsters_cache

    # The monsters file is already a dict keyed by slug
    if isinstance(raw, dict):
        _monsters_cache = raw
    else:
        # If it were a list, key by slug/index
        _monsters_cache = {m.get("slug", m.get("index", "")): m for m in raw}

    logger.info("Loaded %d monsters", len(_monsters_cache))
    return _monsters_cache


def load_srd_spells() -> dict[str, SpellInfo]:
    """Load and parse all SRD spells, keyed by index/slug."""
    global _spells_cache
    if _spells_cache is not None:
        return _spells_cache

    try:
        with open(_SPELLS_PATH, "r", encoding="utf-8") as f:
            raw_list = json.load(f)
    except FileNotFoundError:
        logger.warning("Spell data not found at %s", _SPELLS_PATH)
        _spells_cache = {}
        return _spells_cache

    _spells_cache = {}
    for entry in raw_list:
        spell = parse_spell(entry)
        _spells_cache[spell.index] = spell

    logger.info("Loaded %d spells", len(_spells_cache))
    return _spells_cache


def load_srd_equipment() -> dict[str, EquipmentInfo]:
    """Load and parse all SRD equipment, keyed by index/slug."""
    global _equipment_cache
    if _equipment_cache is not None:
        return _equipment_cache

    try:
        with open(_EQUIPMENT_PATH, "r", encoding="utf-8") as f:
            raw_list = json.load(f)
    except FileNotFoundError:
        logger.warning("Equipment data not found at %s", _EQUIPMENT_PATH)
        _equipment_cache = {}
        return _equipment_cache

    _equipment_cache = {}
    for entry in raw_list:
        item = parse_equipment(entry)
        _equipment_cache[item.index] = item

    logger.info("Loaded %d equipment items", len(_equipment_cache))
    return _equipment_cache


def load_srd_magic_items() -> dict[str, MagicItemInfo]:
    """Load and parse all SRD magic items, keyed by index/slug."""
    global _magic_items_cache
    if _magic_items_cache is not None:
        return _magic_items_cache

    try:
        with open(_MAGIC_ITEMS_PATH, "r", encoding="utf-8") as f:
            raw_list = json.load(f)
    except FileNotFoundError:
        logger.warning("Magic item data not found at %s", _MAGIC_ITEMS_PATH)
        _magic_items_cache = {}
        return _magic_items_cache

    _magic_items_cache = {}
    for entry in raw_list:
        item = parse_magic_item(entry)
        _magic_items_cache[item.index] = item

    logger.info("Loaded %d magic items", len(_magic_items_cache))
    return _magic_items_cache


# ---------------------------------------------------------------------------
# Single-item lookups
# ---------------------------------------------------------------------------


def get_monster(slug: str) -> dict[str, Any] | None:
    """Look up a single monster by slug."""
    return load_srd_monsters().get(slug)


def get_spell(slug: str) -> SpellInfo | None:
    """Look up a single spell by index/slug."""
    return load_srd_spells().get(slug)


def get_equipment(slug: str) -> EquipmentInfo | None:
    """Look up a single equipment item by index/slug."""
    return load_srd_equipment().get(slug)


def get_magic_item(slug: str) -> MagicItemInfo | None:
    """Look up a single magic item by index/slug."""
    return load_srd_magic_items().get(slug)


# ---------------------------------------------------------------------------
# Filtered searches
# ---------------------------------------------------------------------------


def search_monsters(
    *,
    cr: float | None = None,
    type: str | None = None,
    name_contains: str | None = None,
) -> list[dict[str, Any]]:
    """Search monsters with optional filters.

    Args:
        cr: Filter by exact challenge rating.
        type: Filter by species/type (case-insensitive).
        name_contains: Filter by substring in name (case-insensitive).
    """
    results = []
    for monster in load_srd_monsters().values():
        if cr is not None and monster.get("cr") != cr:
            continue
        if type is not None and monster.get("species", "").lower() != type.lower():
            continue
        if name_contains is not None and name_contains.lower() not in monster.get("name", "").lower():
            continue
        results.append(monster)
    return results


def search_spells(
    *,
    level: int | None = None,
    school: str | None = None,
    class_name: str | None = None,
    name_contains: str | None = None,
) -> list[SpellInfo]:
    """Search spells with optional filters.

    Args:
        level: Filter by spell level (0 = cantrip).
        school: Filter by school name (case-insensitive).
        class_name: Filter by class that can cast it (case-insensitive).
        name_contains: Filter by substring in name (case-insensitive).
    """
    results = []
    for spell in load_srd_spells().values():
        if level is not None and spell.level != level:
            continue
        if school is not None and spell.school.lower() != school.lower():
            continue
        if class_name is not None:
            if not any(c.lower() == class_name.lower() for c in spell.classes):
                continue
        if name_contains is not None and name_contains.lower() not in spell.name.lower():
            continue
        results.append(spell)
    return results


def search_equipment(
    *,
    category: str | None = None,
    name_contains: str | None = None,
) -> list[EquipmentInfo]:
    """Search equipment with optional filters.

    Args:
        category: Filter by equipment category (case-insensitive).
        name_contains: Filter by substring in name (case-insensitive).
    """
    results = []
    for item in load_srd_equipment().values():
        if category is not None and item.category.lower() != category.lower():
            continue
        if name_contains is not None and name_contains.lower() not in item.name.lower():
            continue
        results.append(item)
    return results


def search_magic_items(
    *,
    rarity: str | None = None,
    category: str | None = None,
    name_contains: str | None = None,
) -> list[MagicItemInfo]:
    """Search magic items with optional filters.

    Args:
        rarity: Filter by rarity (case-insensitive).
        category: Filter by equipment category (case-insensitive).
        name_contains: Filter by substring in name (case-insensitive).
    """
    results = []
    for item in load_srd_magic_items().values():
        if rarity is not None and item.rarity.lower() != rarity.lower():
            continue
        if category is not None and item.category.lower() != category.lower():
            continue
        if name_contains is not None and name_contains.lower() not in item.name.lower():
            continue
        results.append(item)
    return results


# ---------------------------------------------------------------------------
# Cache management (for testing)
# ---------------------------------------------------------------------------


def clear_caches() -> None:
    """Clear all data caches. Primarily for testing."""
    global _monsters_cache, _spells_cache, _equipment_cache, _magic_items_cache
    _monsters_cache = None
    _spells_cache = None
    _equipment_cache = None
    _magic_items_cache = None
