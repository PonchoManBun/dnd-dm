"""Tests for DM archetype prompt templates and prompt builder."""

from __future__ import annotations

import unittest

from orchestrator.models.enums import (
    ActionType,
    Condition,
    DmArchetype,
    DndClass,
    Race,
)
from orchestrator.models.character import CharacterState
from orchestrator.models.game_state import LocationState
from orchestrator.models.actions import PlayerAction
from orchestrator.engine.prompt_builder import (
    PROMPTS_DIR,
    build_dm_prompt,
    estimate_tokens,
    format_action_context,
    format_npc_context,
    format_state_summary,
    load_archetype_prompt,
)


# ---------------------------------------------------------------------------
# Template loading tests
# ---------------------------------------------------------------------------


class TestLoadArchetypePrompts(unittest.TestCase):
    """Verify all 5 archetype templates load and are well-formed."""

    def test_load_each_archetype_prompt(self) -> None:
        """Load all 5 templates; verify FORMAT section present and placeholder replaced."""
        for archetype in DmArchetype:
            with self.subTest(archetype=archetype.value):
                prompt = load_archetype_prompt(archetype, max_response_tokens=500)
                # Placeholder should have been replaced
                self.assertNotIn("{max_response_tokens}", prompt)
                # The concrete value should appear instead
                self.assertIn("500", prompt)
                # Every template must contain the FORMAT section
                self.assertIn("FORMAT:", prompt)
                self.assertIn("NARRATION:", prompt)
                self.assertIn("CHOICES:", prompt)

    def test_storyteller_content(self) -> None:
        """Storyteller template contains archetype-specific voice directives."""
        prompt = load_archetype_prompt(DmArchetype.STORYTELLER, max_response_tokens=600)
        self.assertIn("Storyteller", prompt)
        self.assertIn("vivid sensory language", prompt)
        self.assertIn("NPCs distinct speech patterns", prompt)


# ---------------------------------------------------------------------------
# Formatting helper tests
# ---------------------------------------------------------------------------


class TestFormatStateSummary(unittest.TestCase):
    def test_format_state_summary(self) -> None:
        char = CharacterState(
            name="Aldric",
            race=Race.HUMAN,
            dnd_class=DndClass.FIGHTER,
            level=3,
            max_hp=34,
            current_hp=28,
            base_ac=18,
            conditions=[],
        )
        loc = LocationState(
            location_id="tavern_01",
            location_name="The Welcome Wench tavern",
            position_x=5,
            position_y=3,
            map_type="tavern",
        )
        summary = format_state_summary(char, loc)
        self.assertIn("Aldric", summary)
        self.assertIn("Level 3", summary)
        self.assertIn("Human", summary)
        self.assertIn("Fighter", summary)
        self.assertIn("HP: 28/34", summary)
        self.assertIn("AC: 18", summary)
        self.assertIn("Conditions: none", summary)
        self.assertIn("The Welcome Wench tavern", summary)
        self.assertIn("(tavern)", summary)
        self.assertIn("(5, 3)", summary)

    def test_format_state_summary_with_conditions(self) -> None:
        char = CharacterState(
            name="Kira",
            conditions=[Condition.POISONED, Condition.PRONE],
        )
        loc = LocationState(location_id="dungeon_a1")
        summary = format_state_summary(char, loc)
        self.assertIn("poisoned", summary)
        self.assertIn("prone", summary)


class TestFormatActionContext(unittest.TestCase):
    def test_format_action_context_attack(self) -> None:
        action = PlayerAction(action_type=ActionType.ATTACK, target="Goblin")
        result = format_action_context(
            action, rules_result="d20(15)+5=20 vs AC 13 HIT! 1d8(6)+3=9 slashing"
        )
        self.assertIn("PLAYER ACTION: attack targeting Goblin", result)
        self.assertIn("DICE RESULTS:", result)
        self.assertIn("d20(15)+5=20", result)

    def test_format_action_context_speak(self) -> None:
        action = PlayerAction(
            action_type=ActionType.SPEAK,
            target="Barkeep",
            message="What news from the road?",
        )
        result = format_action_context(action)
        self.assertIn("PLAYER ACTION: speak targeting Barkeep", result)
        self.assertIn("What news from the road?", result)

    def test_format_action_context_move_direction(self) -> None:
        action = PlayerAction(action_type=ActionType.MOVE, direction="north")
        result = format_action_context(action)
        self.assertIn("direction: north", result)


class TestFormatNpcContext(unittest.TestCase):
    def test_format_npc_context(self) -> None:
        profile = {
            "role": "innkeeper",
            "personality": "gruff but kind",
            "knowledge": "knows about the goblin raids",
        }
        result = format_npc_context("Ostler Gundigoot", profile)
        self.assertIn("NPC: Ostler Gundigoot", result)
        self.assertIn("Role: innkeeper", result)
        self.assertIn("Personality: gruff but kind", result)
        self.assertIn("Knows: knows about the goblin raids", result)

    def test_format_npc_context_no_knowledge(self) -> None:
        profile = {"role": "guard", "personality": "suspicious"}
        result = format_npc_context("Gate Guard", profile)
        self.assertNotIn("Knows:", result)


# ---------------------------------------------------------------------------
# Token estimation
# ---------------------------------------------------------------------------


class TestEstimateTokens(unittest.TestCase):
    def test_estimate_tokens(self) -> None:
        # 20 chars => ~5 tokens
        self.assertEqual(estimate_tokens("a" * 20), 5)
        # Empty string => minimum 1
        self.assertEqual(estimate_tokens(""), 1)
        # 4 chars => 1 token
        self.assertEqual(estimate_tokens("abcd"), 1)


# ---------------------------------------------------------------------------
# build_dm_prompt integration tests (mock compress_history)
# ---------------------------------------------------------------------------


class TestBuildDmPrompt(unittest.TestCase):
    """Tests for the top-level build_dm_prompt function.

    compress_history is mocked out because the context_manager module
    may not exist yet (being built in parallel).
    """

    def _make_fixtures(self):
        char = CharacterState(
            name="Aldric",
            race=Race.HUMAN,
            dnd_class=DndClass.FIGHTER,
            level=3,
            max_hp=34,
            current_hp=28,
            base_ac=18,
        )
        loc = LocationState(
            location_id="tavern_01",
            location_name="The Welcome Wench",
            map_type="tavern",
            position_x=5,
            position_y=3,
        )
        action = PlayerAction(action_type=ActionType.ATTACK, target="Goblin")
        return char, loc, action

    def test_build_dm_prompt_returns_tuple(self) -> None:
        char, loc, action = self._make_fixtures()
        result = build_dm_prompt(
            archetype=DmArchetype.STORYTELLER,
            action=action,
            character=char,
            location=loc,
            history=[],
        )
        self.assertIsInstance(result, tuple)
        self.assertEqual(len(result), 2)
        system_prompt, user_prompt = result
        self.assertIsInstance(system_prompt, str)
        self.assertIsInstance(user_prompt, str)

    def test_build_dm_prompt_system_has_format(self) -> None:
        char, loc, action = self._make_fixtures()
        system_prompt, _ = build_dm_prompt(
            archetype=DmArchetype.STORYTELLER,
            action=action,
            character=char,
            location=loc,
            history=[],
        )
        self.assertIn("FORMAT:", system_prompt)
        self.assertIn("NARRATION:", system_prompt)
        self.assertIn("CHOICES:", system_prompt)

    def test_build_dm_prompt_user_has_action(self) -> None:
        char, loc, action = self._make_fixtures()
        _, user_prompt = build_dm_prompt(
            archetype=DmArchetype.STORYTELLER,
            action=action,
            character=char,
            location=loc,
            history=[],
        )
        self.assertIn("PLAYER ACTION: attack targeting Goblin", user_prompt)
        self.assertIn("PLAYER STATE:", user_prompt)
        self.assertIn("LOCATION:", user_prompt)


if __name__ == "__main__":
    unittest.main()
