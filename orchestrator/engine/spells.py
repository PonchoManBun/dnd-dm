"""Spell lookup and resolution for D&D 5e damage spells.

Loads spells from srd_spells.json and resolves damage for:
- Spell-attack spells (attack roll vs AC, e.g. Acid Arrow)
- Saving-throw spells (target saves for half/none, e.g. Fireball)
- Auto-hit spells (no attack or save, e.g. Magic Missile)
- Cantrips (level 0, scale by character level)

Every function is stateless — takes data in, returns a result.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from orchestrator.engine import dice
from orchestrator.engine.rules import (
    AttackResult,
    RollResult,
    SavingThrowResult,
    attack_roll,
    d20_roll,
    damage_roll,
    saving_throw,
)
from orchestrator.models.character import CharacterState
from orchestrator.models.enums import (
    Ability,
    DamageType,
    DC_ABILITY_INDEX,
    SPELLCASTING_ABILITY,
)

# ---------------------------------------------------------------------------
# Spell data cache (loaded once on first access)
# ---------------------------------------------------------------------------

_SPELL_DATA: list[dict[str, Any]] | None = None
_SPELL_INDEX: dict[str, dict[str, Any]] | None = None


def _load_spells() -> None:
    """Load srd_spells.json into the module-level cache."""
    global _SPELL_DATA, _SPELL_INDEX
    path = Path(__file__).resolve().parent.parent / "data" / "srd_spells.json"
    with open(path, "r") as f:
        _SPELL_DATA = json.load(f)
    _SPELL_INDEX = {}
    for spell in _SPELL_DATA:
        # Index by both the slug ("fireball") and display name ("Fireball")
        _SPELL_INDEX[spell["index"]] = spell
        _SPELL_INDEX[spell["name"].lower()] = spell


def get_spell(name: str) -> dict[str, Any] | None:
    """Look up a spell by name or index (case-insensitive).

    Returns the raw spell dict from srd_spells.json, or None if not found.
    """
    if _SPELL_INDEX is None:
        _load_spells()
    assert _SPELL_INDEX is not None
    return _SPELL_INDEX.get(name.lower())


# ---------------------------------------------------------------------------
# Dice-string parser
# ---------------------------------------------------------------------------

_DICE_RE = re.compile(r"(\d+)d(\d+)(?:\s*\+\s*(\d+))?")


def parse_dice_string(dice_str: str) -> tuple[int, int, int]:
    """Parse a dice string like '8d6' or '1d4 + 1' into (num, sides, bonus)."""
    m = _DICE_RE.match(dice_str.strip())
    if not m:
        return (0, 0, 0)
    num = int(m.group(1))
    sides = int(m.group(2))
    bonus = int(m.group(3)) if m.group(3) else 0
    return (num, sides, bonus)


# ---------------------------------------------------------------------------
# Result dataclass
# ---------------------------------------------------------------------------


@dataclass
class SpellResult:
    """Outcome of casting a damage spell."""

    spell_name: str = ""
    spell_level: int = 0
    slot_used: int = 0
    damage: int = 0
    damage_type: str = ""
    hit: bool = False
    critical: bool = False
    save_made: bool = False
    auto_hit: bool = False
    description: str = ""
    attack_result: AttackResult | None = None
    save_result: SavingThrowResult | None = None


# ---------------------------------------------------------------------------
# Cantrip damage lookup
# ---------------------------------------------------------------------------


def _cantrip_dice_string(spell: dict[str, Any], caster_level: int) -> str:
    """Return the damage dice string for a cantrip based on caster level.

    Cantrips use ``damage.damage_at_character_level`` with threshold keys
    like 1, 5, 11, 17.  We pick the highest threshold <= caster_level.
    """
    dmg = spell.get("damage", {})
    char_level_map = dmg.get("damage_at_character_level", {})
    if not char_level_map:
        return "0d0"

    best_key = "1"
    for lvl_str in sorted(char_level_map.keys(), key=int):
        if int(lvl_str) <= caster_level:
            best_key = lvl_str
    return char_level_map[best_key]


def _slot_dice_string(spell: dict[str, Any], slot_level: int) -> str:
    """Return the damage dice string for a leveled spell cast at *slot_level*.

    Leveled spells use ``damage.damage_at_slot_level``.  Falls back to the
    spell's base level if the requested slot_level key is missing.
    """
    dmg = spell.get("damage", {})
    slot_map = dmg.get("damage_at_slot_level", {})
    if not slot_map:
        return "0d0"

    # Try exact slot level, then fall back to spell's base level
    return slot_map.get(str(slot_level), slot_map.get(str(spell["level"]), "0d0"))


# ---------------------------------------------------------------------------
# Spell DC calculation
# ---------------------------------------------------------------------------


def spell_save_dc(caster: CharacterState) -> int:
    """Calculate the caster's spell save DC: 8 + prof + spellcasting mod."""
    ability = SPELLCASTING_ABILITY.get(caster.dnd_class, Ability.INTELLIGENCE)
    return 8 + caster.get_proficiency_bonus() + caster.get_modifier(ability)


def spell_attack_modifier(caster: CharacterState) -> int:
    """Calculate the caster's spell attack modifier: prof + spellcasting mod."""
    ability = SPELLCASTING_ABILITY.get(caster.dnd_class, Ability.INTELLIGENCE)
    return caster.get_proficiency_bonus() + caster.get_modifier(ability)


# ---------------------------------------------------------------------------
# Main resolution
# ---------------------------------------------------------------------------


def resolve_spell(
    caster: CharacterState,
    spell_name: str,
    *,
    slot_level: int | None = None,
    target_ac: int = 13,
    target_save_modifier: int = 0,
) -> SpellResult:
    """Resolve a damage spell cast by *caster* against a target.

    Parameters
    ----------
    caster:
        The character casting the spell.
    spell_name:
        Name or index of the spell (looked up in srd_spells.json).
    slot_level:
        Spell slot level to use.  ``None`` means use the spell's base level.
        Cantrips (level 0) ignore this.
    target_ac:
        Target's AC (used for spell attack rolls).
    target_save_modifier:
        Target's flat saving throw modifier (simplified; full CharacterState
        save resolution comes in a later phase).

    Returns
    -------
    SpellResult with all relevant data filled in.
    """
    result = SpellResult()

    # --- Look up spell ---
    spell = get_spell(spell_name)
    if spell is None:
        result.description = f"Unknown spell: {spell_name}"
        return result

    result.spell_name = spell["name"]
    result.spell_level = spell["level"]

    # --- Determine slot level ---
    is_cantrip = spell["level"] == 0
    if is_cantrip:
        result.slot_used = 0
    else:
        result.slot_used = slot_level if slot_level is not None else spell["level"]
        # Can't cast with a slot lower than the spell's level
        if result.slot_used < spell["level"]:
            result.slot_used = spell["level"]

    # --- Check the spell has damage data ---
    if "damage" not in spell:
        result.description = f"{spell['name']} is not a damage spell."
        return result

    # --- Determine damage type ---
    dmg_info = spell["damage"]
    dmg_type_info = dmg_info.get("damage_type", {})
    result.damage_type = dmg_type_info.get("name", "unknown")

    # --- Get the dice string ---
    if is_cantrip:
        dice_str = _cantrip_dice_string(spell, caster.level)
    else:
        dice_str = _slot_dice_string(spell, result.slot_used)

    num_dice, die_sides, flat_bonus = parse_dice_string(dice_str)

    # --- Resolve based on spell delivery method ---

    if "attack_type" in spell:
        # Spell attack roll (ranged or melee)
        atk_mod = spell_attack_modifier(caster)
        roll_res = d20_roll()
        roll_res.modifier = atk_mod
        roll_res.total = roll_res.natural_roll + atk_mod
        roll_res.description += f"+{atk_mod}={roll_res.total} vs AC {target_ac}"

        result.critical = roll_res.is_critical_hit

        if roll_res.is_critical_miss:
            result.hit = False
            roll_res.description += " MISS (natural 1)"
        elif roll_res.is_critical_hit or roll_res.total >= target_ac:
            result.hit = True
            roll_res.description += " HIT!" if not roll_res.is_critical_hit else " CRITICAL HIT!"
        else:
            result.hit = False
            roll_res.description += " MISS"

        # Build a minimal AttackResult for the log
        atk_result = AttackResult()
        atk_result.attack_roll = roll_res
        atk_result.hit = result.hit
        atk_result.critical = result.critical
        atk_result.attack_description = roll_res.description
        result.attack_result = atk_result

        if result.hit:
            effective_dice = num_dice * 2 if result.critical else num_dice
            result.damage = max(0, dice.roll(effective_dice, die_sides) + flat_bonus)
            crit_tag = " (critical)" if result.critical else ""
            result.description = (
                f"{spell['name']}: {roll_res.description} | "
                f"{effective_dice}d{die_sides}"
                + (f"+{flat_bonus}" if flat_bonus else "")
                + f"={result.damage} {result.damage_type} damage{crit_tag}"
            )
        else:
            result.damage = 0
            result.description = f"{spell['name']}: {roll_res.description}"

    elif "dc" in spell:
        # Saving throw spell
        dc_info = spell["dc"]
        dc_type_index = dc_info.get("dc_type", {}).get("index", "dex")
        dc_success = dc_info.get("dc_success", "half")

        dc_val = spell_save_dc(caster)

        # Simplified target save: d20 + target_save_modifier vs DC
        save_roll = d20_roll()
        save_roll.modifier = target_save_modifier
        save_roll.total = save_roll.natural_roll + target_save_modifier
        save_succeeded = save_roll.total >= dc_val
        result.save_made = save_succeeded

        save_ability_name = DC_ABILITY_INDEX.get(dc_type_index, Ability.DEXTERITY).value.upper()[:3]
        outcome_str = "SUCCESS" if save_succeeded else "FAILURE"
        save_roll.description += (
            f"+{target_save_modifier}={save_roll.total} vs DC {dc_val} ({save_ability_name}) — {outcome_str}"
        )

        # Roll full damage
        full_damage = max(0, dice.roll(num_dice, die_sides) + flat_bonus)

        if save_succeeded:
            if dc_success == "half":
                result.damage = full_damage // 2
            else:
                # "none" means no damage on success
                result.damage = 0
        else:
            result.damage = full_damage

        save_desc = f"Save {save_roll.description}"
        dmg_desc = f"{num_dice}d{die_sides}"
        if flat_bonus:
            dmg_desc += f"+{flat_bonus}"

        if save_succeeded and dc_success == "half":
            dmg_desc += f"={full_damage} (halved to {result.damage})"
        elif save_succeeded and dc_success == "none":
            dmg_desc += f"={full_damage} (saved, no damage)"
        else:
            dmg_desc += f"={result.damage}"

        result.hit = result.damage > 0
        result.description = (
            f"{spell['name']}: {save_desc} | "
            f"{dmg_desc} {result.damage_type} damage"
        )

    else:
        # Auto-hit spell (e.g. Magic Missile) — no attack roll, no save
        result.auto_hit = True
        result.hit = True
        result.damage = max(0, dice.roll(num_dice, die_sides) + flat_bonus)

        dmg_desc = f"{num_dice}d{die_sides}"
        if flat_bonus:
            dmg_desc += f"+{flat_bonus}"
        dmg_desc += f"={result.damage}"

        result.description = (
            f"{spell['name']}: auto-hit | "
            f"{dmg_desc} {result.damage_type} damage"
        )

    return result
