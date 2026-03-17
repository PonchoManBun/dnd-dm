"""Character state Pydantic model, ported from GDScript CharacterData."""

from __future__ import annotations

import math

from pydantic import BaseModel, Field

from orchestrator.models.enums import (
    Ability,
    ArmorCategory,
    Condition,
    DndClass,
    Race,
    Skill,
)


class AbilityScores(BaseModel):
    """The six core D&D 5e ability scores."""

    strength: int = 10
    dexterity: int = 10
    constitution: int = 10
    intelligence: int = 10
    wisdom: int = 10
    charisma: int = 10


class CharacterState(BaseModel):
    """Full D&D 5e character state for player characters and NPCs."""

    # Identity
    name: str = ""
    race: Race = Race.HUMAN
    dnd_class: DndClass = DndClass.FIGHTER
    level: int = 1
    experience_points: int = 0

    # Ability scores
    ability_scores: AbilityScores = Field(default_factory=AbilityScores)

    # Hit points
    max_hp: int = 10
    current_hp: int = 10
    temp_hp: int = 0
    hit_dice_remaining: int = 1

    # Combat
    base_ac: int = 10
    speed_feet: int = 30
    initiative_bonus: int = 0

    # Death saves (player only)
    death_save_successes: int = 0
    death_save_failures: int = 0

    # Proficiencies
    saving_throw_proficiencies: list[Ability] = Field(default_factory=list)
    skill_proficiencies: list[Skill] = Field(default_factory=list)
    skill_expertise: list[Skill] = Field(default_factory=list)

    # Equipment proficiencies
    armor_proficiencies: list[ArmorCategory] = Field(default_factory=list)
    weapon_proficiencies: list[str] = Field(default_factory=list)

    # Conditions
    conditions: list[Condition] = Field(default_factory=list)

    # Spellcasting
    spell_slots: dict[int, int] = Field(
        default_factory=lambda: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0, 8: 0, 9: 0}
    )
    spell_slots_max: dict[int, int] = Field(
        default_factory=lambda: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0, 8: 0, 9: 0}
    )

    # Flavour
    alignment: str = ""
    backstory: str = ""

    # ------------------------------------------------------------------
    # Derived-value helpers
    # ------------------------------------------------------------------

    def get_ability_score(self, ability: Ability) -> int:
        """Return the raw score for the given ability."""
        return getattr(self.ability_scores, ability.value)

    def set_ability_score(self, ability: Ability, value: int) -> None:
        """Set the raw score for the given ability."""
        setattr(self.ability_scores, ability.value, value)

    @staticmethod
    def ability_modifier(score: int) -> int:
        """Standard 5e ability modifier: floor((score - 10) / 2)."""
        return math.floor((score - 10) / 2)

    def get_modifier(self, ability: Ability) -> int:
        """Return the modifier for a given ability."""
        return self.ability_modifier(self.get_ability_score(ability))

    def get_proficiency_bonus(self) -> int:
        """Proficiency bonus by level: 2 + (level - 1) // 4."""
        return 2 + (self.level - 1) // 4
