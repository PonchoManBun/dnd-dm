"""Tests for SRD data loading, parsing, search, and API endpoints."""

from __future__ import annotations

import pytest
from httpx import ASGITransport, AsyncClient

from orchestrator.data.srd_data import (
    clear_caches,
    get_equipment,
    get_magic_item,
    get_monster,
    get_spell,
    load_srd_equipment,
    load_srd_magic_items,
    load_srd_monsters,
    load_srd_spells,
    search_equipment,
    search_magic_items,
    search_monsters,
    search_spells,
)
from orchestrator.data.spell_data import SpellInfo, parse_spell
from orchestrator.data.equipment_data import (
    EquipmentInfo,
    MagicItemInfo,
    parse_equipment,
    parse_magic_item,
)
from orchestrator.main import app


@pytest.fixture(autouse=True)
def _clear_caches():
    """Clear data caches before each test for isolation."""
    clear_caches()
    yield
    clear_caches()


# ---------------------------------------------------------------------------
# Loading tests
# ---------------------------------------------------------------------------


class TestLoadMonsters:
    def test_loads_monsters_dict(self):
        monsters = load_srd_monsters()
        assert isinstance(monsters, dict)
        assert len(monsters) > 0

    def test_monster_has_expected_fields(self):
        monsters = load_srd_monsters()
        # Pick any monster
        slug = next(iter(monsters))
        monster = monsters[slug]
        assert "name" in monster
        assert "cr" in monster
        assert "max_hp" in monster

    def test_caching_returns_same_object(self):
        first = load_srd_monsters()
        second = load_srd_monsters()
        assert first is second


class TestLoadSpells:
    def test_loads_spells_dict(self):
        spells = load_srd_spells()
        assert isinstance(spells, dict)
        assert len(spells) > 0

    def test_spell_values_are_spellinfo(self):
        spells = load_srd_spells()
        first = next(iter(spells.values()))
        assert isinstance(first, SpellInfo)

    def test_caching_returns_same_object(self):
        first = load_srd_spells()
        second = load_srd_spells()
        assert first is second


class TestLoadEquipment:
    def test_loads_equipment_dict(self):
        equipment = load_srd_equipment()
        assert isinstance(equipment, dict)
        assert len(equipment) > 0

    def test_equipment_values_are_equipmentinfo(self):
        equipment = load_srd_equipment()
        first = next(iter(equipment.values()))
        assert isinstance(first, EquipmentInfo)


class TestLoadMagicItems:
    def test_loads_magic_items_dict(self):
        items = load_srd_magic_items()
        assert isinstance(items, dict)
        assert len(items) > 0

    def test_magic_item_values_are_magiciteminfo(self):
        items = load_srd_magic_items()
        first = next(iter(items.values()))
        assert isinstance(first, MagicItemInfo)


# ---------------------------------------------------------------------------
# Parsing tests
# ---------------------------------------------------------------------------


class TestParseSpell:
    def test_parse_fireball(self):
        raw = {
            "index": "fireball",
            "name": "Fireball",
            "level": 3,
            "school": {"index": "evocation", "name": "Evocation"},
            "casting_time": "1 action",
            "range": "150 feet",
            "duration": "Instantaneous",
            "concentration": False,
            "desc": ["A bright streak flashes from your pointing finger."],
            "classes": [{"index": "sorcerer", "name": "Sorcerer"}, {"index": "wizard", "name": "Wizard"}],
            "damage": {
                "damage_type": {"index": "fire", "name": "Fire"},
                "damage_at_slot_level": {"3": "8d6", "4": "9d6"},
            },
        }
        spell = parse_spell(raw)
        assert spell.index == "fireball"
        assert spell.name == "Fireball"
        assert spell.level == 3
        assert spell.school == "Evocation"
        assert spell.concentration is False
        assert "Sorcerer" in spell.classes
        assert "Wizard" in spell.classes
        assert spell.damage_type == "Fire"
        assert spell.damage_dice == "8d6"

    def test_parse_cantrip_no_damage(self):
        raw = {
            "index": "light",
            "name": "Light",
            "level": 0,
            "school": {"index": "evocation", "name": "Evocation"},
            "casting_time": "1 action",
            "range": "Touch",
            "duration": "1 hour",
            "concentration": False,
            "desc": ["You touch one object."],
            "classes": [{"index": "cleric", "name": "Cleric"}],
        }
        spell = parse_spell(raw)
        assert spell.level == 0
        assert spell.damage_type is None
        assert spell.damage_dice is None

    def test_spell_summary(self):
        raw = {
            "index": "shield",
            "name": "Shield",
            "level": 1,
            "school": {"index": "abjuration", "name": "Abjuration"},
            "casting_time": "1 reaction",
            "range": "Self",
            "duration": "1 round",
            "concentration": False,
            "desc": ["An invisible barrier of magical force appears."],
            "classes": [{"index": "wizard", "name": "Wizard"}],
        }
        spell = parse_spell(raw)
        summary = spell.summary()
        assert "Shield" in summary
        assert "Level 1" in summary
        assert "Abjuration" in summary


class TestParseEquipment:
    def test_parse_weapon(self):
        raw = {
            "index": "longsword",
            "name": "Longsword",
            "equipment_category": {"index": "weapon", "name": "Weapon"},
            "cost": {"quantity": 15, "unit": "gp"},
            "weight": 3,
            "damage": {
                "damage_dice": "1d8",
                "damage_type": {"index": "slashing", "name": "Slashing"},
            },
            "properties": [{"index": "versatile", "name": "Versatile"}],
        }
        equip = parse_equipment(raw)
        assert equip.index == "longsword"
        assert equip.name == "Longsword"
        assert equip.category == "Weapon"
        assert equip.cost_gp == 15.0
        assert equip.weight == 3
        assert equip.damage_dice == "1d8"
        assert equip.damage_type == "Slashing"
        assert "Versatile" in equip.properties

    def test_parse_armor(self):
        raw = {
            "index": "chain-mail",
            "name": "Chain Mail",
            "equipment_category": {"index": "armor", "name": "Armor"},
            "cost": {"quantity": 75, "unit": "gp"},
            "weight": 55,
            "armor_class": {"base": 16, "dex_bonus": False},
            "armor_category": "Heavy",
        }
        equip = parse_equipment(raw)
        assert equip.armor_class == 16
        assert equip.damage_dice is None

    def test_cost_conversion_sp(self):
        raw = {
            "index": "club",
            "name": "Club",
            "equipment_category": {"index": "weapon", "name": "Weapon"},
            "cost": {"quantity": 1, "unit": "sp"},
            "weight": 2,
        }
        equip = parse_equipment(raw)
        assert equip.cost_gp == pytest.approx(0.1)

    def test_equipment_summary(self):
        raw = {
            "index": "dagger",
            "name": "Dagger",
            "equipment_category": {"index": "weapon", "name": "Weapon"},
            "cost": {"quantity": 2, "unit": "gp"},
            "weight": 1,
            "damage": {
                "damage_dice": "1d4",
                "damage_type": {"index": "piercing", "name": "Piercing"},
            },
            "properties": [],
        }
        equip = parse_equipment(raw)
        summary = equip.summary()
        assert "Dagger" in summary
        assert "1d4" in summary


class TestParseMagicItem:
    def test_parse_magic_item(self):
        raw = {
            "index": "adamantine-armor",
            "name": "Adamantine Armor",
            "equipment_category": {"index": "armor", "name": "Armor"},
            "rarity": {"name": "Uncommon"},
            "desc": ["This suit of armor is reinforced with adamantine."],
        }
        item = parse_magic_item(raw)
        assert item.index == "adamantine-armor"
        assert item.name == "Adamantine Armor"
        assert item.rarity == "Uncommon"
        assert item.category == "Armor"
        assert "adamantine" in item.description.lower()


# ---------------------------------------------------------------------------
# Lookup tests
# ---------------------------------------------------------------------------


class TestGetBySlug:
    def test_get_monster_found(self):
        monster = get_monster("goblin")
        assert monster is not None
        assert monster["name"] == "Goblin"

    def test_get_monster_not_found(self):
        assert get_monster("nonexistent-monster-xyz") is None

    def test_get_spell_found(self):
        spell = get_spell("acid-arrow")
        assert spell is not None
        assert spell.name == "Acid Arrow"

    def test_get_spell_not_found(self):
        assert get_spell("nonexistent-spell-xyz") is None

    def test_get_equipment_found(self):
        equip = get_equipment("club")
        assert equip is not None
        assert equip.name == "Club"

    def test_get_equipment_not_found(self):
        assert get_equipment("nonexistent-equip-xyz") is None

    def test_get_magic_item_found(self):
        item = get_magic_item("adamantine-armor")
        assert item is not None
        assert item.name == "Adamantine Armor"

    def test_get_magic_item_not_found(self):
        assert get_magic_item("nonexistent-magic-xyz") is None


# ---------------------------------------------------------------------------
# Search tests
# ---------------------------------------------------------------------------


class TestSearchMonsters:
    def test_search_by_cr(self):
        results = search_monsters(cr=0.25)
        assert len(results) > 0
        for m in results:
            assert m["cr"] == 0.25

    def test_search_by_type(self):
        results = search_monsters(type="undead")
        assert len(results) > 0
        for m in results:
            assert m["species"].lower() == "undead"

    def test_search_by_name(self):
        results = search_monsters(name_contains="goblin")
        assert len(results) >= 1
        assert any("Goblin" in m["name"] for m in results)

    def test_search_no_results(self):
        results = search_monsters(cr=999)
        assert results == []


class TestSearchSpells:
    def test_search_by_level(self):
        results = search_spells(level=0)
        assert len(results) > 0
        for s in results:
            assert s.level == 0

    def test_search_by_school(self):
        results = search_spells(school="evocation")
        assert len(results) > 0
        for s in results:
            assert s.school.lower() == "evocation"

    def test_search_by_class(self):
        results = search_spells(class_name="wizard")
        assert len(results) > 0
        for s in results:
            assert any(c.lower() == "wizard" for c in s.classes)

    def test_search_by_name(self):
        results = search_spells(name_contains="fire")
        assert len(results) >= 1

    def test_search_combined_filters(self):
        results = search_spells(level=0, class_name="wizard")
        assert len(results) > 0
        for s in results:
            assert s.level == 0
            assert any(c.lower() == "wizard" for c in s.classes)


class TestSearchEquipment:
    def test_search_by_category(self):
        results = search_equipment(category="weapon")
        assert len(results) > 0
        for e in results:
            assert e.category.lower() == "weapon"

    def test_search_by_name(self):
        results = search_equipment(name_contains="sword")
        assert len(results) >= 1


class TestSearchMagicItems:
    def test_search_by_rarity(self):
        results = search_magic_items(rarity="uncommon")
        assert len(results) > 0
        for m in results:
            assert m.rarity.lower() == "uncommon"

    def test_search_by_name(self):
        results = search_magic_items(name_contains="armor")
        assert len(results) >= 1


# ---------------------------------------------------------------------------
# API endpoint tests
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_api_get_monster():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/srd/monsters/goblin")
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "Goblin"


@pytest.mark.asyncio
async def test_api_get_monster_not_found():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/srd/monsters/nonexistent-xyz")
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_api_search_monsters():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/srd/monsters", params={"cr": 0.25})
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    assert len(data) > 0


@pytest.mark.asyncio
async def test_api_get_spell():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/srd/spells/acid-arrow")
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "Acid Arrow"
    assert data["level"] == 2


@pytest.mark.asyncio
async def test_api_search_spells():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/srd/spells", params={"level": 0})
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    assert len(data) > 0
    for spell in data:
        assert spell["level"] == 0


@pytest.mark.asyncio
async def test_api_get_equipment():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/srd/equipment/club")
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "Club"


@pytest.mark.asyncio
async def test_api_search_equipment():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/srd/equipment", params={"category": "weapon"})
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    assert len(data) > 0


@pytest.mark.asyncio
async def test_api_get_magic_item():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/srd/magic-items/adamantine-armor")
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "Adamantine Armor"


@pytest.mark.asyncio
async def test_api_search_magic_items():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/srd/magic-items", params={"rarity": "uncommon"})
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    assert len(data) > 0


@pytest.mark.asyncio
async def test_api_spell_not_found():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/srd/spells/nonexistent-xyz")
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_api_search_spells_by_class():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/srd/spells", params={"class": "wizard"})
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    assert len(data) > 0
    for spell in data:
        assert "Wizard" in spell["classes"]
