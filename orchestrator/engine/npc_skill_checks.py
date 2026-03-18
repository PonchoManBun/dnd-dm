"""Skill check resolution for NPC interactions.

Uses the existing rules engine for d20 rolls and applies attitude shifts
based on success/failure.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass

from orchestrator.engine import npc_agent_registry as registry
from orchestrator.engine.rules import ability_check
from orchestrator.models.character import CharacterState
from orchestrator.models.enums import Skill
from orchestrator.models.npc_agent import ATTITUDE_DC, ATTITUDE_ORDER, NpcAttitude

logger = logging.getLogger(__name__)


@dataclass
class NpcSkillCheckResult:
    """Result of a skill check against an NPC."""

    success: bool
    skill: str
    roll_total: int
    dc: int
    roll_description: str
    old_attitude: str
    new_attitude: str
    context_message: str


def resolve_npc_skill_check(
    character: CharacterState,
    npc_id: str,
    skill_name: str,
) -> NpcSkillCheckResult:
    """Resolve a Persuasion, Intimidation, or Deception check against an NPC.

    Skill effects:
        Persuasion:    success → attitude +1, failure → attitude -1
        Intimidation:  success → attitude becomes Unfriendly (compliant),
                       failure → attitude -1
        Deception:     success → attitude +1 (temporary, 3 interactions),
                       failure → attitude -2

    DC is determined by the NPC's current attitude:
        Hostile=20, Unfriendly=15, Indifferent=12, Friendly=8, Helpful=5
    """
    state = registry.get_or_create(npc_id)
    old_attitude = state.attitude

    # Map skill name to enum
    skill_map = {
        "persuasion": Skill.PERSUASION,
        "intimidation": Skill.INTIMIDATION,
        "deception": Skill.DECEPTION,
    }
    skill_enum = skill_map.get(skill_name.lower())
    if skill_enum is None:
        return NpcSkillCheckResult(
            success=False,
            skill=skill_name,
            roll_total=0,
            dc=0,
            roll_description="Invalid skill",
            old_attitude=old_attitude.value,
            new_attitude=old_attitude.value,
            context_message=f"'{skill_name}' is not a valid social skill.",
        )

    # Determine DC from current attitude
    dc = ATTITUDE_DC.get(old_attitude, 12)

    # Roll the check
    result = ability_check(character, skill_enum, dc)

    # Track skill usage on the NPC state
    state.last_skill_used = skill_name.lower()
    state.last_skill_success = result.success

    # Apply attitude shift based on skill and outcome
    context_message: str
    if skill_name.lower() == "persuasion":
        if result.success:
            registry.update_attitude(npc_id, +1)
            context_message = "The adventurer's words ring true. You warm to them slightly."
        else:
            registry.update_attitude(npc_id, -1)
            context_message = "The adventurer's plea falls flat. You think less of them."

    elif skill_name.lower() == "intimidation":
        if result.success:
            # Intimidation forces compliance but doesn't make friends
            # Set to unfriendly (compliant but resentful)
            current_idx = ATTITUDE_ORDER.index(state.attitude)
            unfriendly_idx = ATTITUDE_ORDER.index(NpcAttitude.UNFRIENDLY)
            if current_idx < unfriendly_idx:
                registry.update_attitude(npc_id, unfriendly_idx - current_idx)
            elif current_idx > unfriendly_idx:
                registry.update_attitude(npc_id, unfriendly_idx - current_idx)
            context_message = "The adventurer just intimidated you successfully. You comply grudgingly."
        else:
            registry.update_attitude(npc_id, -1)
            context_message = "The adventurer tried to intimidate you and failed. You are offended."

    elif skill_name.lower() == "deception":
        if result.success:
            registry.update_attitude(npc_id, +1)
            registry.set_deception(npc_id, 3)
            context_message = "The adventurer seems trustworthy. You believe their words."
        else:
            registry.update_attitude(npc_id, -2)
            context_message = "You caught the adventurer lying. Your trust is shattered."
    else:
        context_message = ""

    # Store context for injection into next LLM prompt
    new_state = registry.get_or_create(npc_id)
    new_state.skill_context = context_message

    return NpcSkillCheckResult(
        success=result.success,
        skill=skill_name,
        roll_total=result.roll.total,
        dc=dc,
        roll_description=result.roll.description,
        old_attitude=old_attitude.value,
        new_attitude=new_state.attitude.value,
        context_message=context_message,
    )
