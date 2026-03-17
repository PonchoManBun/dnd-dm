"""SRD data lookup API routes — monsters, spells, equipment, magic items."""

from __future__ import annotations

from typing import Any

from fastapi import APIRouter, HTTPException, Query

from orchestrator.data.srd_data import (
    get_equipment,
    get_magic_item,
    get_monster,
    get_spell,
    search_equipment,
    search_magic_items,
    search_monsters,
    search_spells,
)

router = APIRouter(prefix="/srd", tags=["srd"])


# ---------------------------------------------------------------------------
# Monsters
# ---------------------------------------------------------------------------


@router.get("/monsters")
async def list_monsters(
    cr: float | None = Query(None, description="Filter by challenge rating"),
    type: str | None = Query(None, description="Filter by creature type"),
    name: str | None = Query(None, description="Filter by name substring"),
) -> list[dict[str, Any]]:
    """Search monsters with optional filters."""
    return search_monsters(cr=cr, type=type, name_contains=name)


@router.get("/monsters/{slug}")
async def get_monster_by_slug(slug: str) -> dict[str, Any]:
    """Get a single monster by slug."""
    monster = get_monster(slug)
    if monster is None:
        raise HTTPException(status_code=404, detail=f"Monster '{slug}' not found")
    return monster


# ---------------------------------------------------------------------------
# Spells
# ---------------------------------------------------------------------------


@router.get("/spells")
async def list_spells(
    level: int | None = Query(None, description="Filter by spell level (0=cantrip)"),
    school: str | None = Query(None, description="Filter by school"),
    class_name: str | None = Query(None, alias="class", description="Filter by class"),
    name: str | None = Query(None, description="Filter by name substring"),
) -> list[dict[str, Any]]:
    """Search spells with optional filters."""
    results = search_spells(
        level=level, school=school, class_name=class_name, name_contains=name
    )
    return [_spell_to_dict(s) for s in results]


@router.get("/spells/{slug}")
async def get_spell_by_slug(slug: str) -> dict[str, Any]:
    """Get a single spell by index/slug."""
    spell = get_spell(slug)
    if spell is None:
        raise HTTPException(status_code=404, detail=f"Spell '{slug}' not found")
    return _spell_to_dict(spell)


def _spell_to_dict(spell) -> dict[str, Any]:
    """Convert SpellInfo to a JSON-serializable dict."""
    return {
        "index": spell.index,
        "name": spell.name,
        "level": spell.level,
        "school": spell.school,
        "casting_time": spell.casting_time,
        "range": spell.range,
        "duration": spell.duration,
        "concentration": spell.concentration,
        "description": spell.description,
        "classes": spell.classes,
        "damage_type": spell.damage_type,
        "damage_dice": spell.damage_dice,
    }


# ---------------------------------------------------------------------------
# Equipment
# ---------------------------------------------------------------------------


@router.get("/equipment")
async def list_equipment(
    category: str | None = Query(None, description="Filter by category"),
    name: str | None = Query(None, description="Filter by name substring"),
) -> list[dict[str, Any]]:
    """Search equipment with optional filters."""
    results = search_equipment(category=category, name_contains=name)
    return [_equipment_to_dict(e) for e in results]


@router.get("/equipment/{slug}")
async def get_equipment_by_slug(slug: str) -> dict[str, Any]:
    """Get a single equipment item by index/slug."""
    item = get_equipment(slug)
    if item is None:
        raise HTTPException(status_code=404, detail=f"Equipment '{slug}' not found")
    return _equipment_to_dict(item)


def _equipment_to_dict(item) -> dict[str, Any]:
    """Convert EquipmentInfo to a JSON-serializable dict."""
    return {
        "index": item.index,
        "name": item.name,
        "category": item.category,
        "cost_gp": item.cost_gp,
        "weight": item.weight,
        "description": item.description,
        "damage_dice": item.damage_dice,
        "damage_type": item.damage_type,
        "armor_class": item.armor_class,
        "properties": item.properties,
    }


# ---------------------------------------------------------------------------
# Magic Items
# ---------------------------------------------------------------------------


@router.get("/magic-items")
async def list_magic_items(
    rarity: str | None = Query(None, description="Filter by rarity"),
    category: str | None = Query(None, description="Filter by category"),
    name: str | None = Query(None, description="Filter by name substring"),
) -> list[dict[str, Any]]:
    """Search magic items with optional filters."""
    results = search_magic_items(rarity=rarity, category=category, name_contains=name)
    return [_magic_item_to_dict(m) for m in results]


@router.get("/magic-items/{slug}")
async def get_magic_item_by_slug(slug: str) -> dict[str, Any]:
    """Get a single magic item by index/slug."""
    item = get_magic_item(slug)
    if item is None:
        raise HTTPException(status_code=404, detail=f"Magic item '{slug}' not found")
    return _magic_item_to_dict(item)


def _magic_item_to_dict(item) -> dict[str, Any]:
    """Convert MagicItemInfo to a JSON-serializable dict."""
    return {
        "index": item.index,
        "name": item.name,
        "category": item.category,
        "rarity": item.rarity,
        "description": item.description,
    }
