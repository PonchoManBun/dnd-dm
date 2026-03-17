"""Comprehensive tests for the D&D 5e rules engine.

Tests cover all ported functions from GDScript rules_engine.gd.
Dice rolls are patched where determinism is required.
"""

from __future__ import annotations

from unittest.mock import patch

import pytest

from orchestrator.engine import dice
from orchestrator.engine.rules import (
    AbilityCheckResult,
    AttackResult,
    RollResult,
    SavingThrowResult,
    ability_check,
    ability_modifier,
    apply_condition_speed_modifiers,
    attack_roll,
    calculate_ac,
    d20_roll,
    damage_roll,
    format_damage_roll,
    get_max_hp_for_level,
    has_advantage_against,
    has_disadvantage_from_conditions,
    initiative_roll,
    proficiency_bonus,
    resolve_attack,
    saving_throw,
)
from orchestrator.models.character import AbilityScores, CharacterState
from orchestrator.models.enums import (
    Ability,
    ArmorCategory,
    Condition,
    DamageType,
    DndClass,
    Skill,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _make_character(**overrides) -> CharacterState:
    """Create a CharacterState with sensible defaults, applying overrides."""
    defaults = dict(
        name="Test Hero",
        level=1,
        ability_scores=AbilityScores(
            strength=16,   # +3
            dexterity=14,  # +2
            constitution=12,  # +1
            intelligence=10,  # 0
            wisdom=8,      # -1
            charisma=13,   # +1
        ),
        saving_throw_proficiencies=[Ability.STRENGTH, Ability.CONSTITUTION],
        skill_proficiencies=[Skill.ATHLETICS, Skill.PERCEPTION],
        skill_expertise=[],
        conditions=[],
        speed_feet=30,
        initiative_bonus=0,
        dnd_class=DndClass.FIGHTER,
    )
    defaults.update(overrides)
    return CharacterState(**defaults)


# ===================================================================
# ability_modifier
# ===================================================================


class TestAbilityModifier:
    def test_score_10_gives_0(self):
        assert ability_modifier(10) == 0

    def test_score_8_gives_negative_1(self):
        assert ability_modifier(8) == -1

    def test_score_15_gives_2(self):
        assert ability_modifier(15) == 2

    def test_score_20_gives_5(self):
        assert ability_modifier(20) == 5

    def test_score_1_gives_negative_5(self):
        assert ability_modifier(1) == -5

    def test_score_11_gives_0(self):
        assert ability_modifier(11) == 0

    def test_score_9_gives_negative_1(self):
        assert ability_modifier(9) == -1

    def test_score_30_gives_10(self):
        """Monsters can have scores up to 30."""
        assert ability_modifier(30) == 10


# ===================================================================
# proficiency_bonus
# ===================================================================


class TestProficiencyBonus:
    def test_level_1(self):
        assert proficiency_bonus(1) == 2

    def test_level_4(self):
        assert proficiency_bonus(4) == 2

    def test_level_5(self):
        assert proficiency_bonus(5) == 3

    def test_level_8(self):
        assert proficiency_bonus(8) == 3

    def test_level_9(self):
        assert proficiency_bonus(9) == 4

    def test_level_12(self):
        assert proficiency_bonus(12) == 4

    def test_level_13(self):
        assert proficiency_bonus(13) == 5

    def test_level_16(self):
        assert proficiency_bonus(16) == 5

    def test_level_17(self):
        assert proficiency_bonus(17) == 6

    def test_level_20(self):
        assert proficiency_bonus(20) == 6


# ===================================================================
# d20_roll
# ===================================================================


class TestD20Roll:
    def test_returns_roll_result(self):
        result = d20_roll()
        assert isinstance(result, RollResult)

    def test_range(self):
        """Smoke test: 100 rolls should all be 1-20."""
        for _ in range(100):
            result = d20_roll()
            assert 1 <= result.natural_roll <= 20
            assert result.total == result.natural_roll  # no modifier yet

    def test_critical_hit_on_20(self):
        with patch.object(dice, "d20", return_value=20):
            result = d20_roll()
        assert result.is_critical_hit
        assert not result.is_critical_miss
        assert result.natural_roll == 20

    def test_critical_miss_on_1(self):
        with patch.object(dice, "d20", return_value=1):
            result = d20_roll()
        assert result.is_critical_miss
        assert not result.is_critical_hit
        assert result.natural_roll == 1

    def test_advantage_takes_higher(self):
        """With advantage, should take the higher of two rolls."""
        rolls = iter([5, 15])
        with patch.object(dice, "d20", side_effect=rolls):
            result = d20_roll(advantage=True)
        assert result.natural_roll == 15
        assert result.advantage is True
        assert result.disadvantage is False

    def test_disadvantage_takes_lower(self):
        """With disadvantage, should take the lower of two rolls."""
        rolls = iter([5, 15])
        with patch.object(dice, "d20", side_effect=rolls):
            result = d20_roll(disadvantage=True)
        assert result.natural_roll == 5
        assert result.disadvantage is True
        assert result.advantage is False

    def test_advantage_and_disadvantage_cancel(self):
        """When both apply, they cancel — single roll."""
        with patch.object(dice, "d20", return_value=12):
            result = d20_roll(advantage=True, disadvantage=True)
        assert result.natural_roll == 12
        assert result.advantage is False
        assert result.disadvantage is False

    def test_description_contains_roll(self):
        with patch.object(dice, "d20", return_value=14):
            result = d20_roll()
        assert "14" in result.description


# ===================================================================
# attack_roll
# ===================================================================


class TestAttackRoll:
    def test_nat20_always_hits(self):
        """Natural 20 always hits, even against impossible AC."""
        char = _make_character(ability_scores=AbilityScores(strength=1))
        with patch.object(dice, "d20", return_value=20):
            result = attack_roll(char, target_ac=99, ability=Ability.STRENGTH)
        assert result.is_critical_hit
        assert "CRITICAL HIT" in result.description

    def test_nat1_always_misses(self):
        """Natural 1 always misses, even against AC 0."""
        char = _make_character(ability_scores=AbilityScores(strength=30))
        with patch.object(dice, "d20", return_value=1):
            result = attack_roll(char, target_ac=0, ability=Ability.STRENGTH)
        assert result.is_critical_miss
        assert result.total == -1
        assert "NATURAL 1" in result.description

    def test_hit_with_modifier(self):
        """Roll + modifier meets AC → hit."""
        char = _make_character()  # STR 16 (+3), level 1 prof +2
        # d20=10, +3+2=15 vs AC 15 → hit
        with patch.object(dice, "d20", return_value=10):
            result = attack_roll(char, target_ac=15, ability=Ability.STRENGTH)
        assert result.total == 15
        assert "HIT" in result.description

    def test_miss_when_below_ac(self):
        """Roll + modifier below AC → miss."""
        char = _make_character()
        # d20=5, +3+2=10 vs AC 15 → miss
        with patch.object(dice, "d20", return_value=5):
            result = attack_roll(char, target_ac=15, ability=Ability.STRENGTH)
        assert result.total == 10
        assert "MISS" in result.description

    def test_no_proficiency(self):
        """When not proficient, prof bonus is not added."""
        char = _make_character()  # STR 16 (+3)
        with patch.object(dice, "d20", return_value=10):
            result = attack_roll(
                char, target_ac=10, ability=Ability.STRENGTH, proficient=False,
            )
        assert result.modifier == 3  # only ability mod, no prof


# ===================================================================
# damage_roll
# ===================================================================


class TestDamageRoll:
    def test_basic_damage(self):
        """Simple 1d8+3 damage, non-critical."""
        with patch.object(dice, "roll", return_value=5):
            dmg = damage_roll(1, 8, modifier=3)
        assert dmg == 8  # 5 + 3

    def test_critical_doubles_dice(self):
        """Critical hit doubles dice count but not modifier."""
        with patch.object(dice, "roll", return_value=10) as mock_roll:
            dmg = damage_roll(1, 8, modifier=3, critical=True)
        # Should call roll(2, 8) — doubled dice
        mock_roll.assert_called_once_with(2, 8)
        assert dmg == 13  # 10 + 3

    def test_minimum_zero(self):
        """Damage cannot go below 0."""
        with patch.object(dice, "roll", return_value=1):
            dmg = damage_roll(1, 4, modifier=-5)
        assert dmg == 0  # max(0, 1 + (-5)) = 0

    def test_multi_dice(self):
        """2d6+4 damage."""
        with patch.object(dice, "roll", return_value=7):
            dmg = damage_roll(2, 6, modifier=4)
        assert dmg == 11  # 7 + 4


# ===================================================================
# format_damage_roll
# ===================================================================


class TestFormatDamageRoll:
    def test_with_modifier(self):
        desc = format_damage_roll(1, 8, roll_total=8, modifier=3)
        assert desc == "1d8(5)+3=8"

    def test_without_modifier(self):
        desc = format_damage_roll(1, 8, roll_total=5, modifier=0)
        assert desc == "1d8(5)=5"

    def test_critical(self):
        desc = format_damage_roll(1, 8, roll_total=13, modifier=3, critical=True)
        assert "2d8(crit)" in desc


# ===================================================================
# resolve_attack
# ===================================================================


class TestResolveAttack:
    def test_hit_deals_damage(self):
        char = _make_character()
        with patch.object(dice, "d20", return_value=15), \
             patch.object(dice, "roll", return_value=6):
            result = resolve_attack(
                char, target_ac=10, weapon_dice=1, weapon_sides=8,
                damage_type=DamageType.SLASHING, ability=Ability.STRENGTH,
            )
        assert result.hit is True
        assert result.damage > 0
        assert result.damage_type == DamageType.SLASHING
        assert "slashing" in result.damage_description

    def test_miss_no_damage(self):
        char = _make_character()
        with patch.object(dice, "d20", return_value=2):
            result = resolve_attack(
                char, target_ac=25, weapon_dice=1, weapon_sides=8,
                damage_type=DamageType.PIERCING, ability=Ability.STRENGTH,
            )
        assert result.hit is False
        assert result.damage == 0

    def test_nat1_miss(self):
        char = _make_character()
        with patch.object(dice, "d20", return_value=1):
            result = resolve_attack(
                char, target_ac=5, weapon_dice=1, weapon_sides=8,
                damage_type=DamageType.SLASHING, ability=Ability.STRENGTH,
            )
        assert result.hit is False

    def test_critical_doubles_damage_dice(self):
        char = _make_character()
        with patch.object(dice, "d20", return_value=20), \
             patch.object(dice, "roll", return_value=12) as mock_roll:
            result = resolve_attack(
                char, target_ac=25, weapon_dice=1, weapon_sides=8,
                damage_type=DamageType.SLASHING, ability=Ability.STRENGTH,
            )
        assert result.hit is True
        assert result.critical is True
        # damage_roll should have been called with doubled dice
        mock_roll.assert_called_once_with(2, 8)


# ===================================================================
# saving_throw
# ===================================================================


class TestSavingThrow:
    def test_success(self):
        char = _make_character()
        # STR save: mod +3, prof +2 = +5. Roll 10 → 15 vs DC 15 → success.
        with patch.object(dice, "d20", return_value=10):
            result = saving_throw(char, Ability.STRENGTH, dc=15)
        assert result.success is True
        assert result.roll.total == 15

    def test_failure(self):
        char = _make_character()
        # STR save: mod +3, prof +2 = +5. Roll 5 → 10 vs DC 15 → fail.
        with patch.object(dice, "d20", return_value=5):
            result = saving_throw(char, Ability.STRENGTH, dc=15)
        assert result.success is False
        assert result.roll.total == 10

    def test_non_proficient_save(self):
        char = _make_character()
        # WIS save: not proficient. mod -1. Roll 10 → 9 vs DC 10 → fail.
        with patch.object(dice, "d20", return_value=10):
            result = saving_throw(char, Ability.WISDOM, dc=10)
        assert result.roll.modifier == -1  # no prof, just mod
        assert result.roll.total == 9
        assert result.success is False

    def test_auto_fail_str_when_paralyzed(self):
        char = _make_character(conditions=[Condition.PARALYZED])
        result = saving_throw(char, Ability.STRENGTH, dc=1)
        assert result.success is False
        assert "AUTO-FAIL" in result.roll.description

    def test_auto_fail_dex_when_stunned(self):
        char = _make_character(conditions=[Condition.STUNNED])
        result = saving_throw(char, Ability.DEXTERITY, dc=1)
        assert result.success is False
        assert "AUTO-FAIL" in result.roll.description

    def test_auto_fail_dex_when_unconscious(self):
        char = _make_character(conditions=[Condition.UNCONSCIOUS])
        result = saving_throw(char, Ability.DEXTERITY, dc=1)
        assert result.success is False

    def test_non_str_dex_save_not_auto_fail_when_paralyzed(self):
        """WIS/INT/CON/CHA saves don't auto-fail from paralyzed."""
        char = _make_character(conditions=[Condition.PARALYZED])
        with patch.object(dice, "d20", return_value=20):
            result = saving_throw(char, Ability.WISDOM, dc=10)
        assert result.success is True

    def test_description_contains_dc(self):
        char = _make_character()
        with patch.object(dice, "d20", return_value=10):
            result = saving_throw(char, Ability.STRENGTH, dc=12)
        assert "DC 12" in result.roll.description


# ===================================================================
# ability_check
# ===================================================================


class TestAbilityCheck:
    def test_proficient_adds_bonus(self):
        char = _make_character()  # prof in Athletics, STR +3, prof +2
        with patch.object(dice, "d20", return_value=10):
            result = ability_check(char, Skill.ATHLETICS, dc=15)
        assert result.roll.modifier == 5  # +3 STR + 2 prof
        assert result.roll.total == 15
        assert result.success is True

    def test_non_proficient_no_bonus(self):
        char = _make_character()  # not prof in Arcana, INT +0
        with patch.object(dice, "d20", return_value=10):
            result = ability_check(char, Skill.ARCANA, dc=11)
        assert result.roll.modifier == 0  # INT 10 = +0, no prof
        assert result.roll.total == 10
        assert result.success is False

    def test_expertise_doubles_proficiency(self):
        char = _make_character(
            skill_proficiencies=[Skill.ATHLETICS, Skill.STEALTH],
            skill_expertise=[Skill.STEALTH],
            ability_scores=AbilityScores(dexterity=14),  # +2
        )
        with patch.object(dice, "d20", return_value=10):
            result = ability_check(char, Skill.STEALTH, dc=10)
        # DEX +2, expertise = prof*2 = 4 → modifier = 6
        assert result.roll.modifier == 6
        assert result.roll.total == 16
        assert result.success is True

    def test_uses_correct_governing_ability(self):
        """Perception uses WIS, Athletics uses STR."""
        char = _make_character()  # WIS 8 (-1), prof in Perception, prof +2
        with patch.object(dice, "d20", return_value=10):
            result = ability_check(char, Skill.PERCEPTION, dc=10)
        # WIS -1 + prof 2 = +1
        assert result.roll.modifier == 1
        assert result.roll.total == 11

    def test_description_shows_outcome(self):
        char = _make_character()
        with patch.object(dice, "d20", return_value=10):
            result = ability_check(char, Skill.ATHLETICS, dc=20)
        assert "FAILURE" in result.roll.description


# ===================================================================
# initiative_roll
# ===================================================================


class TestInitiativeRoll:
    def test_basic_initiative(self):
        char = _make_character()  # DEX 14 (+2), initiative_bonus 0
        with patch.object(dice, "d20", return_value=10):
            result = initiative_roll(char)
        assert result == 12  # 10 + 2

    def test_with_initiative_bonus(self):
        char = _make_character(initiative_bonus=3)  # DEX +2
        with patch.object(dice, "d20", return_value=10):
            result = initiative_roll(char)
        assert result == 15  # 10 + 2 + 3

    def test_negative_dex_mod(self):
        char = _make_character(
            ability_scores=AbilityScores(dexterity=8),  # -1
        )
        with patch.object(dice, "d20", return_value=10):
            result = initiative_roll(char)
        assert result == 9  # 10 + (-1)


# ===================================================================
# calculate_ac
# ===================================================================


class TestCalculateAC:
    def test_no_armor(self):
        """No armor: 10 + DEX mod."""
        char = _make_character()  # DEX 14 (+2)
        assert calculate_ac(char, armor_base=0) == 12

    def test_light_armor(self):
        """Light armor: base + DEX mod."""
        char = _make_character()  # DEX +2
        assert calculate_ac(char, armor_base=11, armor_type=ArmorCategory.LIGHT) == 13

    def test_medium_armor(self):
        """Medium armor: base + min(DEX mod, 2)."""
        char = _make_character(
            ability_scores=AbilityScores(dexterity=18),  # +4
        )
        assert calculate_ac(char, armor_base=14, armor_type=ArmorCategory.MEDIUM) == 16

    def test_medium_armor_low_dex(self):
        """Medium armor with low DEX — uses full DEX mod since it's <= 2."""
        char = _make_character(
            ability_scores=AbilityScores(dexterity=12),  # +1
        )
        assert calculate_ac(char, armor_base=14, armor_type=ArmorCategory.MEDIUM) == 15

    def test_heavy_armor(self):
        """Heavy armor: base only, no DEX."""
        char = _make_character()  # DEX +2, should be ignored
        assert calculate_ac(char, armor_base=18, armor_type=ArmorCategory.HEAVY) == 18

    def test_shield_adds_2(self):
        """Shield adds +2 to any AC calculation."""
        char = _make_character()  # DEX +2
        assert calculate_ac(char, armor_base=0, has_shield=True) == 14  # 10+2+2

    def test_heavy_armor_with_shield(self):
        char = _make_character()
        assert calculate_ac(
            char, armor_base=18, armor_type=ArmorCategory.HEAVY, has_shield=True,
        ) == 20

    def test_negative_dex_with_no_armor(self):
        char = _make_character(ability_scores=AbilityScores(dexterity=6))  # -2
        assert calculate_ac(char, armor_base=0) == 8  # 10 + (-2)


# ===================================================================
# Condition helpers
# ===================================================================


class TestConditionHelpers:
    def test_advantage_against_blinded(self):
        target = _make_character(conditions=[Condition.BLINDED])
        assert has_advantage_against(target) is True

    def test_advantage_against_paralyzed(self):
        target = _make_character(conditions=[Condition.PARALYZED])
        assert has_advantage_against(target) is True

    def test_advantage_against_stunned(self):
        target = _make_character(conditions=[Condition.STUNNED])
        assert has_advantage_against(target) is True

    def test_advantage_against_unconscious(self):
        target = _make_character(conditions=[Condition.UNCONSCIOUS])
        assert has_advantage_against(target) is True

    def test_advantage_against_restrained(self):
        target = _make_character(conditions=[Condition.RESTRAINED])
        assert has_advantage_against(target) is True

    def test_advantage_against_prone(self):
        target = _make_character(conditions=[Condition.PRONE])
        assert has_advantage_against(target) is True

    def test_no_advantage_when_no_conditions(self):
        target = _make_character(conditions=[])
        assert has_advantage_against(target) is False

    def test_no_advantage_against_charmed(self):
        """Charmed does not grant advantage."""
        target = _make_character(conditions=[Condition.CHARMED])
        assert has_advantage_against(target) is False

    def test_disadvantage_from_blinded(self):
        attacker = _make_character(conditions=[Condition.BLINDED])
        assert has_disadvantage_from_conditions(attacker) is True

    def test_disadvantage_from_frightened(self):
        attacker = _make_character(conditions=[Condition.FRIGHTENED])
        assert has_disadvantage_from_conditions(attacker) is True

    def test_disadvantage_from_poisoned(self):
        attacker = _make_character(conditions=[Condition.POISONED])
        assert has_disadvantage_from_conditions(attacker) is True

    def test_disadvantage_from_restrained(self):
        attacker = _make_character(conditions=[Condition.RESTRAINED])
        assert has_disadvantage_from_conditions(attacker) is True

    def test_disadvantage_from_prone(self):
        attacker = _make_character(conditions=[Condition.PRONE])
        assert has_disadvantage_from_conditions(attacker) is True

    def test_no_disadvantage_when_no_conditions(self):
        attacker = _make_character(conditions=[])
        assert has_disadvantage_from_conditions(attacker) is False


# ===================================================================
# apply_condition_speed_modifiers
# ===================================================================


class TestConditionSpeed:
    def test_no_conditions_keeps_speed(self):
        char = _make_character()
        assert apply_condition_speed_modifiers(char, 30) == 30

    def test_grappled_zeroes_speed(self):
        char = _make_character(conditions=[Condition.GRAPPLED])
        assert apply_condition_speed_modifiers(char, 30) == 0

    def test_restrained_zeroes_speed(self):
        char = _make_character(conditions=[Condition.RESTRAINED])
        assert apply_condition_speed_modifiers(char, 30) == 0

    def test_prone_halves_speed(self):
        char = _make_character(conditions=[Condition.PRONE])
        assert apply_condition_speed_modifiers(char, 30) == 15

    def test_grappled_and_prone(self):
        """Grappled sets to 0 first, prone halves 0 → still 0."""
        char = _make_character(conditions=[Condition.GRAPPLED, Condition.PRONE])
        assert apply_condition_speed_modifiers(char, 30) == 0

    def test_prone_odd_speed(self):
        """Odd base speed floors when halved."""
        char = _make_character(conditions=[Condition.PRONE])
        assert apply_condition_speed_modifiers(char, 25) == 12  # 25 // 2


# ===================================================================
# get_max_hp_for_level
# ===================================================================


class TestGetMaxHpForLevel:
    def test_fighter_level_1(self):
        """Fighter: d10, CON +1 → 10 + 1 = 11."""
        char = _make_character(
            dnd_class=DndClass.FIGHTER, level=1,
            ability_scores=AbilityScores(constitution=12),  # +1
        )
        assert get_max_hp_for_level(char) == 11

    def test_wizard_level_1(self):
        """Wizard: d6, CON +0 → 6."""
        char = _make_character(
            dnd_class=DndClass.WIZARD, level=1,
            ability_scores=AbilityScores(constitution=10),  # +0
        )
        assert get_max_hp_for_level(char) == 6

    def test_fighter_level_2(self):
        """Fighter: d10, CON +1.  L1=11, L2=11+(5+1+1)=18."""
        char = _make_character(
            dnd_class=DndClass.FIGHTER, level=2,
            ability_scores=AbilityScores(constitution=12),  # +1
        )
        # L1: 10+1=11.  L2: avg = 10//2+1=6, +1=7, total=11+7=18
        assert get_max_hp_for_level(char) == 18

    def test_fighter_level_5(self):
        """Fighter d10, CON +1.  L1=11, L2-5: 4*(6+1)=28, total=39."""
        char = _make_character(
            dnd_class=DndClass.FIGHTER, level=5,
            ability_scores=AbilityScores(constitution=12),  # +1
        )
        # L1: 11.  L2-5: 4 * (10//2+1+1) = 4*7 = 28.  Total: 39
        assert get_max_hp_for_level(char) == 39

    def test_minimum_1_hp(self):
        """Even with terrible CON, HP is at least 1."""
        char = _make_character(
            dnd_class=DndClass.WIZARD, level=1,
            ability_scores=AbilityScores(constitution=1),  # -5
        )
        # d6 + (-5) = 1 (min 1)
        assert get_max_hp_for_level(char) == 1

    def test_per_level_minimum_1(self):
        """Each level after 1st contributes at least 1 HP."""
        char = _make_character(
            dnd_class=DndClass.WIZARD, level=2,
            ability_scores=AbilityScores(constitution=1),  # -5
        )
        # L1: max(1, 6 + (-5)) = max(1, 1) = 1
        # L2: max(1, 6//2+1+(-5)) = max(1, -1) = 1
        # total = max(1, 1+1) = 2
        assert get_max_hp_for_level(char) == 2

    def test_rogue_level_3(self):
        """Rogue d8, CON +2.  L1=10, L2-3: 2*(5+2)=14, total=24."""
        char = _make_character(
            dnd_class=DndClass.ROGUE, level=3,
            ability_scores=AbilityScores(constitution=14),  # +2
        )
        # L1: 8+2=10.  L2-3: 2*(8//2+1+2) = 2*7 = 14.  Total: 24
        assert get_max_hp_for_level(char) == 24


# ===================================================================
# Dice module
# ===================================================================


class TestDice:
    def test_roll_range(self):
        """100 rolls of 1d6 should all be 1-6."""
        for _ in range(100):
            r = dice.roll(1, 6)
            assert 1 <= r <= 6

    def test_roll_multiple_dice(self):
        """2d6 should be 2-12."""
        for _ in range(100):
            r = dice.roll(2, 6)
            assert 2 <= r <= 12

    def test_d20_range(self):
        for _ in range(100):
            r = dice.d20()
            assert 1 <= r <= 20

    def test_roll_4d6_drop_lowest_range(self):
        """4d6 drop lowest should be 3-18."""
        for _ in range(100):
            r = dice.roll_4d6_drop_lowest()
            assert 3 <= r <= 18


# ===================================================================
# Integration: result dataclass structure
# ===================================================================


class TestResultDataclasses:
    def test_roll_result_defaults(self):
        r = RollResult()
        assert r.total == 0
        assert r.is_critical_hit is False
        assert r.description == ""

    def test_attack_result_defaults(self):
        a = AttackResult()
        assert a.hit is False
        assert a.damage == 0
        assert a.damage_type == DamageType.SLASHING

    def test_saving_throw_result_defaults(self):
        s = SavingThrowResult()
        assert s.success is False
        assert s.dc == 0

    def test_ability_check_result_defaults(self):
        c = AbilityCheckResult()
        assert c.success is False
        assert c.dc == 0
