"""D&D 5e rules engine — pure-function port of GDScript rules_engine.gd.

Every function is stateless: it takes data in, returns a result, and never
mutates the models it receives.  Dice randomness comes from engine.dice so it
can be seeded or mocked in tests.
"""

from __future__ import annotations

from dataclasses import dataclass, field

from orchestrator.engine import dice
from orchestrator.engine.constants import (
    ADVANTAGE_CONDITIONS,
    DISADVANTAGE_CONDITIONS,
    INCAPACITATED_CONDITIONS,
    MOVEMENT_ZERO_CONDITIONS,
    SKILL_ABILITIES,
)
from orchestrator.models.character import CharacterState
from orchestrator.models.enums import (
    Ability,
    ArmorCategory,
    Condition,
    DamageType,
    DndClass,
    Skill,
    CLASS_DATA,
)


# ---------------------------------------------------------------------------
# Result dataclasses
# ---------------------------------------------------------------------------


@dataclass
class RollResult:
    """Outcome of a single d20-based roll."""

    total: int = 0
    natural_roll: int = 0
    modifier: int = 0
    advantage: bool = False
    disadvantage: bool = False
    is_critical_hit: bool = False
    is_critical_miss: bool = False
    description: str = ""

    def __str__(self) -> str:  # pragma: no cover
        return self.description


@dataclass
class AttackResult:
    """Outcome of a full attack (attack roll + damage)."""

    hit: bool = False
    critical: bool = False
    damage: int = 0
    damage_type: DamageType = DamageType.SLASHING
    attack_roll: RollResult = field(default_factory=RollResult)
    attack_description: str = ""
    damage_description: str = ""


@dataclass
class SavingThrowResult:
    """Outcome of a saving throw."""

    success: bool = False
    roll: RollResult = field(default_factory=RollResult)
    dc: int = 0


@dataclass
class AbilityCheckResult:
    """Outcome of an ability/skill check."""

    success: bool = False
    roll: RollResult = field(default_factory=RollResult)
    dc: int = 0


# ---------------------------------------------------------------------------
# Core maths
# ---------------------------------------------------------------------------


def ability_modifier(score: int) -> int:
    """Standard 5e ability modifier: ``(score - 10) // 2`` (floor division)."""
    return (score - 10) // 2


def proficiency_bonus(level: int) -> int:
    """Proficiency bonus by character level: ``2 + (level - 1) // 4``."""
    return 2 + (level - 1) // 4


# ---------------------------------------------------------------------------
# d20 rolls
# ---------------------------------------------------------------------------


def d20_roll(
    advantage: bool = False,
    disadvantage: bool = False,
) -> RollResult:
    """Roll a d20 with optional advantage/disadvantage.

    If both advantage *and* disadvantage apply they cancel out (PHB rule).
    """
    result = RollResult()

    # Cancel each other out
    result.advantage = advantage and not disadvantage
    result.disadvantage = disadvantage and not advantage

    roll1 = dice.d20()

    if result.advantage:
        roll2 = dice.d20()
        result.natural_roll = max(roll1, roll2)
        result.description = f"d20({roll1},{roll2})={result.natural_roll}"
    elif result.disadvantage:
        roll2 = dice.d20()
        result.natural_roll = min(roll1, roll2)
        result.description = f"d20({roll1},{roll2})={result.natural_roll}"
    else:
        result.natural_roll = roll1
        result.description = f"d20({roll1})"

    result.is_critical_hit = result.natural_roll == 20
    result.is_critical_miss = result.natural_roll == 1
    result.total = result.natural_roll
    return result


# ---------------------------------------------------------------------------
# Attack resolution
# ---------------------------------------------------------------------------


def attack_roll(
    attacker_data: CharacterState,
    target_ac: int,
    ability: Ability = Ability.STRENGTH,
    proficient: bool = True,
    advantage: bool = False,
    disadvantage: bool = False,
) -> RollResult:
    """Make an attack roll: d20 + ability mod + proficiency vs AC.

    Natural 1 always misses.  Natural 20 always hits (critical).
    """
    result = d20_roll(advantage, disadvantage)

    # Natural 1 — guaranteed miss
    if result.is_critical_miss:
        result.total = -1
        result.modifier = 0
        result.description += " NATURAL 1"
        return result

    mod = attacker_data.get_modifier(ability)
    prof = attacker_data.get_proficiency_bonus() if proficient else 0
    result.modifier = mod + prof
    result.total = result.natural_roll + result.modifier
    result.description += f"+{result.modifier}"

    if result.modifier != mod:
        result.description += f"(mod{mod}+prof{prof})"

    result.description += f"={result.total} vs AC {target_ac}"

    if result.is_critical_hit:
        result.description += " CRITICAL HIT!"
    elif result.total >= target_ac:
        result.description += " HIT!"
    else:
        result.description += " MISS"

    return result


def damage_roll(
    num_dice: int,
    die_size: int,
    modifier: int = 0,
    critical: bool = False,
) -> int:
    """Roll damage dice.  Critical hits double the number of dice (not modifier).

    Minimum total damage is 0.
    """
    dice_count = num_dice * 2 if critical else num_dice
    rolled = dice.roll(dice_count, die_size)
    return max(0, rolled + modifier)


def format_damage_roll(
    num_dice: int,
    die_size: int,
    roll_total: int,
    modifier: int = 0,
    critical: bool = False,
) -> str:
    """Human-readable description of a damage roll for the combat log."""
    effective_dice = num_dice * 2 if critical else num_dice
    dice_str = f"{effective_dice}d{die_size}"
    if critical:
        dice_str += "(crit)"
    base = roll_total - modifier
    if modifier != 0:
        return f"{dice_str}({base})+{modifier}={roll_total}"
    return f"{dice_str}({base})={roll_total}"


def resolve_attack(
    attacker_data: CharacterState,
    target_ac: int,
    weapon_dice: int,
    weapon_sides: int,
    damage_type: DamageType,
    ability: Ability = Ability.STRENGTH,
    proficient: bool = True,
    advantage: bool = False,
    disadvantage: bool = False,
) -> AttackResult:
    """Full attack resolution: attack roll followed by damage (if hit)."""
    result = AttackResult()
    result.damage_type = damage_type

    result.attack_roll = attack_roll(
        attacker_data, target_ac, ability, proficient, advantage, disadvantage,
    )
    result.critical = result.attack_roll.is_critical_hit
    result.attack_description = result.attack_roll.description

    # Natural 1 — auto miss
    if result.attack_roll.is_critical_miss:
        result.hit = False
        return result

    result.hit = result.attack_roll.is_critical_hit or result.attack_roll.total >= target_ac
    if not result.hit:
        return result

    # Damage
    dmg_mod = attacker_data.get_modifier(ability)
    result.damage = damage_roll(weapon_dice, weapon_sides, dmg_mod, result.critical)
    result.damage_description = format_damage_roll(
        weapon_dice, weapon_sides, result.damage, dmg_mod, result.critical,
    )
    result.damage_description += f" {damage_type.value}"

    return result


# ---------------------------------------------------------------------------
# Saving throws & ability checks
# ---------------------------------------------------------------------------


def saving_throw(
    character_data: CharacterState,
    ability: Ability,
    dc: int,
    advantage: bool = False,
    disadvantage: bool = False,
) -> SavingThrowResult:
    """Make a saving throw: d20 + ability mod + proficiency (if proficient) vs DC.

    STR/DEX saves auto-fail when paralyzed, stunned, or unconscious.
    """
    result = SavingThrowResult(dc=dc)

    # Auto-fail STR/DEX when incapacitated
    if ability in (Ability.STRENGTH, Ability.DEXTERITY):
        for cond in INCAPACITATED_CONDITIONS:
            if cond in character_data.conditions:
                result.success = False
                result.roll = RollResult(description="AUTO-FAIL (incapacitated)")
                return result

    result.roll = d20_roll(advantage, disadvantage)
    mod = character_data.get_modifier(ability)
    prof = (
        character_data.get_proficiency_bonus()
        if ability in character_data.saving_throw_proficiencies
        else 0
    )
    result.roll.modifier = mod + prof
    result.roll.total = result.roll.natural_roll + result.roll.modifier
    result.success = result.roll.total >= dc
    outcome = "SUCCESS" if result.success else "FAILURE"
    result.roll.description += (
        f"+{result.roll.modifier}={result.roll.total} vs DC {dc} — {outcome}"
    )
    return result


def ability_check(
    character_data: CharacterState,
    skill: Skill,
    dc: int,
    advantage: bool = False,
    disadvantage: bool = False,
) -> AbilityCheckResult:
    """Make a skill/ability check: d20 + ability mod + proficiency/expertise vs DC."""
    result = AbilityCheckResult(dc=dc)

    governing_ability: Ability = SKILL_ABILITIES[skill]
    result.roll = d20_roll(advantage, disadvantage)
    mod = character_data.get_modifier(governing_ability)

    prof = 0
    if skill in character_data.skill_expertise:
        prof = character_data.get_proficiency_bonus() * 2
    elif skill in character_data.skill_proficiencies:
        prof = character_data.get_proficiency_bonus()

    result.roll.modifier = mod + prof
    result.roll.total = result.roll.natural_roll + result.roll.modifier
    result.success = result.roll.total >= dc
    outcome = "SUCCESS" if result.success else "FAILURE"
    result.roll.description += (
        f"+{result.roll.modifier}={result.roll.total} vs DC {dc} — {outcome}"
    )
    return result


# ---------------------------------------------------------------------------
# Initiative
# ---------------------------------------------------------------------------


def initiative_roll(character_data: CharacterState) -> int:
    """Roll initiative: 1d20 + DEX modifier + initiative bonus."""
    roll_val = dice.d20()
    dex_mod = character_data.get_modifier(Ability.DEXTERITY)
    return roll_val + dex_mod + character_data.initiative_bonus


# ---------------------------------------------------------------------------
# Armor class
# ---------------------------------------------------------------------------


def calculate_ac(
    character_data: CharacterState,
    armor_base: int = 0,
    armor_type: ArmorCategory = ArmorCategory.LIGHT,
    has_shield: bool = False,
) -> int:
    """Calculate AC from equipment.

    - No armor (armor_base <= 0): 10 + DEX mod
    - Light:  armor_base + DEX mod
    - Medium: armor_base + min(DEX mod, 2)
    - Heavy:  armor_base (no DEX)
    - Shield: +2
    """
    dex_mod = character_data.get_modifier(Ability.DEXTERITY)

    if armor_base <= 0:
        ac = 10 + dex_mod
    elif armor_type == ArmorCategory.LIGHT:
        ac = armor_base + dex_mod
    elif armor_type == ArmorCategory.MEDIUM:
        ac = armor_base + min(dex_mod, 2)
    elif armor_type == ArmorCategory.HEAVY:
        ac = armor_base
    else:
        ac = 10 + dex_mod

    if has_shield:
        ac += 2

    return ac


# ---------------------------------------------------------------------------
# Condition helpers
# ---------------------------------------------------------------------------


def has_advantage_against(target_data: CharacterState) -> bool:
    """True if the target has a condition granting advantage on attacks against it."""
    return any(cond in target_data.conditions for cond in ADVANTAGE_CONDITIONS)


def has_disadvantage_from_conditions(attacker_data: CharacterState) -> bool:
    """True if the attacker has a condition imposing disadvantage on its attacks."""
    return any(cond in attacker_data.conditions for cond in DISADVANTAGE_CONDITIONS)


def apply_condition_speed_modifiers(
    character_data: CharacterState,
    base_speed: int,
) -> int:
    """Apply condition effects to movement speed and return the modified value."""
    speed = base_speed

    # Grappled / restrained → speed 0
    for cond in MOVEMENT_ZERO_CONDITIONS:
        if cond in character_data.conditions:
            speed = 0
            break

    # Prone → halved (costs extra movement)
    if Condition.PRONE in character_data.conditions:
        speed = speed // 2

    return speed


# ---------------------------------------------------------------------------
# HP calculation
# ---------------------------------------------------------------------------


def get_max_hp_for_level(character_data: CharacterState) -> int:
    """Calculate max HP from class hit die and CON modifier.

    Level 1: max hit die + CON mod.
    Levels 2+: average hit die (die/2 + 1) + CON mod each, minimum 1 per level.
    Overall result is at least 1.
    """
    class_info = CLASS_DATA[character_data.dnd_class]
    hit_die: int = class_info.hit_die
    con_mod: int = character_data.get_modifier(Ability.CONSTITUTION)

    # Level 1: max die + CON mod
    hp = hit_die + con_mod

    # Levels 2+
    for _ in range(1, character_data.level):
        hp += max(1, (hit_die // 2) + 1 + con_mod)

    return max(1, hp)
