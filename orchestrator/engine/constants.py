"""D&D 5e rules constants used by the engine.

Condition lists and skill-ability mapping live here so that rules.py stays
focused on game logic rather than data tables.
"""

from __future__ import annotations

from orchestrator.models.enums import Ability, Condition, Skill

# Re-export the canonical mapping that already lives in enums.py so that
# engine consumers only need to import from engine.constants.
from orchestrator.models.enums import SKILL_ABILITIES as SKILL_ABILITIES  # noqa: F401

# ---------------------------------------------------------------------------
# Condition groups
# ---------------------------------------------------------------------------

# Conditions that grant advantage on attack rolls *against* the target.
ADVANTAGE_CONDITIONS: list[Condition] = [
    Condition.BLINDED,
    Condition.PARALYZED,
    Condition.STUNNED,
    Condition.UNCONSCIOUS,
    Condition.RESTRAINED,
    Condition.PRONE,
]

# Conditions that impose disadvantage on the *attacker's* attack rolls.
DISADVANTAGE_CONDITIONS: list[Condition] = [
    Condition.BLINDED,
    Condition.FRIGHTENED,
    Condition.POISONED,
    Condition.RESTRAINED,
    Condition.PRONE,
]

# Conditions that reduce movement speed to 0.
MOVEMENT_ZERO_CONDITIONS: list[Condition] = [
    Condition.GRAPPLED,
    Condition.RESTRAINED,
]

# Conditions that auto-fail STR/DEX saving throws.
INCAPACITATED_CONDITIONS: list[Condition] = [
    Condition.PARALYZED,
    Condition.STUNNED,
    Condition.UNCONSCIOUS,
]
