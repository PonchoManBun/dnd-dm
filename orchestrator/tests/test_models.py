"""Tests for orchestrator Pydantic models."""

from __future__ import annotations

import json
import tempfile
from pathlib import Path

import pytest

from orchestrator.models import (
    Ability,
    AbilityScores,
    ActionType,
    ArmorCategory,
    CharacterState,
    CombatantState,
    CombatState,
    Condition,
    DmArchetype,
    DmResponse,
    DndClass,
    EquipmentSlot,
    GameState,
    ItemState,
    LocationState,
    NarrativeState,
    PlayerAction,
    Race,
    Skill,
    StateDelta,
    load_game_state,
    save_game_state,
    SKILL_ABILITIES,
    XP_THRESHOLDS,
    RACE_DATA,
    CLASS_DATA,
)


# ---------------------------------------------------------------------------
# CharacterState — defaults
# ---------------------------------------------------------------------------


class TestCharacterDefaults:
    def test_default_ability_scores(self) -> None:
        char = CharacterState()
        assert char.ability_scores.strength == 10
        assert char.ability_scores.dexterity == 10
        assert char.ability_scores.constitution == 10
        assert char.ability_scores.intelligence == 10
        assert char.ability_scores.wisdom == 10
        assert char.ability_scores.charisma == 10

    def test_default_identity(self) -> None:
        char = CharacterState()
        assert char.name == ""
        assert char.race == Race.HUMAN
        assert char.dnd_class == DndClass.FIGHTER
        assert char.level == 1
        assert char.experience_points == 0

    def test_default_hp(self) -> None:
        char = CharacterState()
        assert char.max_hp == 10
        assert char.current_hp == 10
        assert char.temp_hp == 0
        assert char.hit_dice_remaining == 1

    def test_default_combat(self) -> None:
        char = CharacterState()
        assert char.base_ac == 10
        assert char.speed_feet == 30
        assert char.initiative_bonus == 0

    def test_default_proficiencies_empty(self) -> None:
        char = CharacterState()
        assert char.saving_throw_proficiencies == []
        assert char.skill_proficiencies == []
        assert char.skill_expertise == []
        assert char.armor_proficiencies == []
        assert char.weapon_proficiencies == []
        assert char.conditions == []

    def test_default_flavour(self) -> None:
        char = CharacterState()
        assert char.alignment == ""
        assert char.backstory == ""


# ---------------------------------------------------------------------------
# CharacterState — full data and methods
# ---------------------------------------------------------------------------


class TestCharacterMethods:
    @pytest.fixture()
    def fighter(self) -> CharacterState:
        return CharacterState(
            name="Bruenor",
            race=Race.DWARF,
            dnd_class=DndClass.FIGHTER,
            level=5,
            experience_points=6500,
            ability_scores=AbilityScores(
                strength=16,
                dexterity=12,
                constitution=14,
                intelligence=8,
                wisdom=13,
                charisma=10,
            ),
            max_hp=44,
            current_hp=44,
            hit_dice_remaining=5,
            base_ac=18,
            speed_feet=25,
            saving_throw_proficiencies=[Ability.STRENGTH, Ability.CONSTITUTION],
            skill_proficiencies=[Skill.ATHLETICS, Skill.PERCEPTION],
            armor_proficiencies=[
                ArmorCategory.LIGHT,
                ArmorCategory.MEDIUM,
                ArmorCategory.HEAVY,
                ArmorCategory.SHIELDS,
            ],
            weapon_proficiencies=["simple", "martial"],
            alignment="Lawful Good",
            backstory="A dwarf from Mithral Hall.",
        )

    def test_get_modifier_strength(self, fighter: CharacterState) -> None:
        # STR 16 -> modifier +3
        assert fighter.get_modifier(Ability.STRENGTH) == 3

    def test_get_modifier_intelligence(self, fighter: CharacterState) -> None:
        # INT 8 -> modifier -1
        assert fighter.get_modifier(Ability.INTELLIGENCE) == -1

    def test_get_modifier_10(self, fighter: CharacterState) -> None:
        # CHA 10 -> modifier 0
        assert fighter.get_modifier(Ability.CHARISMA) == 0

    def test_get_modifier_odd(self, fighter: CharacterState) -> None:
        # WIS 13 -> modifier +1
        assert fighter.get_modifier(Ability.WISDOM) == 1

    def test_get_proficiency_bonus_level_5(self, fighter: CharacterState) -> None:
        # Level 5 -> proficiency bonus +3
        assert fighter.get_proficiency_bonus() == 3

    def test_get_proficiency_bonus_level_1(self) -> None:
        char = CharacterState(level=1)
        assert char.get_proficiency_bonus() == 2

    def test_get_proficiency_bonus_level_9(self) -> None:
        char = CharacterState(level=9)
        assert char.get_proficiency_bonus() == 4

    def test_get_proficiency_bonus_level_17(self) -> None:
        char = CharacterState(level=17)
        assert char.get_proficiency_bonus() == 6

    def test_get_ability_score(self, fighter: CharacterState) -> None:
        assert fighter.get_ability_score(Ability.STRENGTH) == 16
        assert fighter.get_ability_score(Ability.DEXTERITY) == 12

    def test_set_ability_score(self, fighter: CharacterState) -> None:
        fighter.set_ability_score(Ability.STRENGTH, 20)
        assert fighter.get_ability_score(Ability.STRENGTH) == 20
        assert fighter.get_modifier(Ability.STRENGTH) == 5


# ---------------------------------------------------------------------------
# GameState — round-trip JSON serialization
# ---------------------------------------------------------------------------


class TestGameStateSerialization:
    def _make_full_state(self) -> GameState:
        return GameState(
            version=1,
            timestamp=1700000000.0,
            character=CharacterState(
                name="Elara",
                race=Race.ELF,
                dnd_class=DndClass.WIZARD,
                level=3,
                ability_scores=AbilityScores(
                    strength=8,
                    dexterity=14,
                    constitution=12,
                    intelligence=18,
                    wisdom=10,
                    charisma=11,
                ),
                max_hp=18,
                current_hp=14,
                skill_proficiencies=[Skill.ARCANA, Skill.INVESTIGATION],
                conditions=[Condition.POISONED],
            ),
            location=LocationState(
                location_id="tavern_main",
                location_name="The Welcome Wench",
                position_x=5,
                position_y=3,
                map_type="tavern",
            ),
            narrative=NarrativeState(
                dm_archetype=DmArchetype.STORYTELLER,
                current_narration="The barkeep eyes you warily.",
                current_choices=["Order a drink", "Ask about the cellar"],
                turn_number=4,
            ),
            combat=CombatState(
                active=True,
                combatants=[
                    CombatantState(
                        combatant_id="player_1",
                        name="Elara",
                        is_player=True,
                        current_hp=14,
                        max_hp=18,
                        armor_class=12,
                        initiative=15,
                    ),
                    CombatantState(
                        combatant_id="goblin_1",
                        name="Goblin",
                        is_player=False,
                        current_hp=7,
                        max_hp=7,
                        armor_class=15,
                        initiative=8,
                        conditions=[Condition.FRIGHTENED],
                    ),
                ],
                current_turn_index=0,
                round_number=2,
            ),
            inventory=[
                ItemState(slug="potion_healing", name="Potion of Healing", quantity=2, weight=0.5),
                ItemState(slug="torch", name="Torch", quantity=5, weight=1.0),
            ],
            equipment={
                EquipmentSlot.MAIN_HAND: ItemState(slug="quarterstaff", name="Quarterstaff", weight=4.0),
            },
        )

    def test_json_round_trip(self) -> None:
        state = self._make_full_state()
        json_str = state.model_dump_json()
        restored = GameState.model_validate_json(json_str)

        assert restored.version == state.version
        assert restored.character.name == "Elara"
        assert restored.character.race == Race.ELF
        assert restored.character.dnd_class == DndClass.WIZARD
        assert restored.character.get_modifier(Ability.INTELLIGENCE) == 4
        assert restored.location.location_name == "The Welcome Wench"
        assert restored.narrative.dm_archetype == DmArchetype.STORYTELLER
        assert restored.narrative.current_choices == ["Order a drink", "Ask about the cellar"]
        assert restored.combat is not None
        assert restored.combat.active is True
        assert len(restored.combat.combatants) == 2
        assert restored.combat.combatants[1].conditions == [Condition.FRIGHTENED]
        assert len(restored.inventory) == 2
        assert restored.inventory[0].slug == "potion_healing"
        assert EquipmentSlot.MAIN_HAND in restored.equipment
        assert restored.equipment[EquipmentSlot.MAIN_HAND] is not None
        assert restored.equipment[EquipmentSlot.MAIN_HAND].slug == "quarterstaff"

    def test_save_and_load(self, tmp_path: Path) -> None:
        state = self._make_full_state()
        save_path = tmp_path / "test_save.json"
        save_game_state(state, save_path)
        loaded = load_game_state(save_path)

        assert loaded.character.name == state.character.name
        assert loaded.character.level == state.character.level
        assert loaded.combat is not None
        assert loaded.combat.round_number == 2
        assert len(loaded.inventory) == 2

    def test_no_combat_serialization(self) -> None:
        state = GameState(combat=None)
        json_str = state.model_dump_json()
        restored = GameState.model_validate_json(json_str)
        assert restored.combat is None

    def test_json_output_uses_string_enums(self) -> None:
        state = GameState(
            character=CharacterState(race=Race.HALFLING, dnd_class=DndClass.ROGUE),
        )
        data = json.loads(state.model_dump_json())
        assert data["character"]["race"] == "halfling"
        assert data["character"]["dnd_class"] == "rogue"


# ---------------------------------------------------------------------------
# PlayerAction & DmResponse
# ---------------------------------------------------------------------------


class TestActions:
    def test_player_action_minimal(self) -> None:
        action = PlayerAction(action_type=ActionType.LOOK)
        assert action.action_type == ActionType.LOOK
        assert action.target is None
        assert action.message is None

    def test_player_action_full(self) -> None:
        action = PlayerAction(
            action_type=ActionType.ATTACK,
            target="goblin_1",
            message="I swing my sword!",
            item_slug="longsword",
            extra={"advantage": True},
        )
        assert action.action_type == ActionType.ATTACK
        assert action.target == "goblin_1"
        assert action.extra == {"advantage": True}

    def test_player_action_json_round_trip(self) -> None:
        action = PlayerAction(
            action_type=ActionType.SPEAK,
            message="Hello, barkeep!",
        )
        json_str = action.model_dump_json()
        restored = PlayerAction.model_validate_json(json_str)
        assert restored.action_type == ActionType.SPEAK
        assert restored.message == "Hello, barkeep!"

    def test_dm_response_minimal(self) -> None:
        resp = DmResponse(narration="You see a dark corridor.")
        assert resp.narration == "You see a dark corridor."
        assert resp.choices == []
        assert resp.state_delta is None
        assert resp.combat_log is None
        assert resp.error is None

    def test_dm_response_full(self) -> None:
        resp = DmResponse(
            narration="The goblin lunges at you!",
            choices=["Dodge", "Parry", "Counter-attack"],
            state_delta=StateDelta(
                hp_change=-5,
                conditions_added=[Condition.FRIGHTENED],
                xp_gained=50,
            ),
            combat_log=["Goblin attacks with scimitar", "Hit! 5 slashing damage"],
        )
        assert resp.state_delta is not None
        assert resp.state_delta.hp_change == -5
        assert Condition.FRIGHTENED in resp.state_delta.conditions_added
        assert resp.state_delta.xp_gained == 50
        assert len(resp.combat_log) == 2

    def test_dm_response_json_round_trip(self) -> None:
        resp = DmResponse(
            narration="The door creaks open.",
            choices=["Enter", "Turn back"],
            state_delta=StateDelta(position_change=(3, 7)),
        )
        json_str = resp.model_dump_json()
        restored = DmResponse.model_validate_json(json_str)
        assert restored.narration == "The door creaks open."
        assert restored.state_delta is not None
        assert restored.state_delta.position_change == (3, 7)


# ---------------------------------------------------------------------------
# Constants sanity checks
# ---------------------------------------------------------------------------


class TestConstants:
    def test_skill_abilities_complete(self) -> None:
        """Every Skill enum member should have a governing ability."""
        for skill in Skill:
            assert skill in SKILL_ABILITIES, f"Missing SKILL_ABILITIES entry for {skill}"

    def test_xp_thresholds_length(self) -> None:
        assert len(XP_THRESHOLDS) == 20

    def test_xp_thresholds_monotonic(self) -> None:
        for i in range(1, len(XP_THRESHOLDS)):
            assert XP_THRESHOLDS[i] > XP_THRESHOLDS[i - 1]

    def test_race_data_complete(self) -> None:
        for race in Race:
            assert race in RACE_DATA, f"Missing RACE_DATA entry for {race}"
            info = RACE_DATA[race]
            assert info.name
            assert info.speed > 0
            assert info.size in ("Small", "Medium")

    def test_class_data_complete(self) -> None:
        for cls in DndClass:
            assert cls in CLASS_DATA, f"Missing CLASS_DATA entry for {cls}"
            info = CLASS_DATA[cls]
            assert info.name
            assert info.hit_die in (6, 8, 10, 12)
            assert info.num_skills >= 1
            assert len(info.saving_throws) == 2
