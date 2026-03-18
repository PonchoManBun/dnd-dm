"""Knowledge gating by NPC attitude tier.

NPCs reveal different information based on their attitude toward the player.
Knowledge tiers are cumulative: FRIENDLY includes INDIFFERENT facts.
"""

from __future__ import annotations

import logging

from orchestrator.models.npc_agent import NpcAttitude

logger = logging.getLogger(__name__)

# Tiers are cumulative in this order
_TIER_ORDER: list[str] = ["hostile", "unfriendly", "indifferent", "friendly", "helpful"]


def get_knowledge_for_attitude(
    profile: dict,
    attitude: NpcAttitude,
) -> list[str]:
    """Return the knowledge facts available at the given attitude level.

    Supports two profile formats:
    - Old flat format: {"knowledge": "single string"} -- always returned at indifferent+
    - New tiered format: {"knowledge_tiers": {"hostile": [], "indifferent": [...], ...}}

    Tiered knowledge is cumulative: FRIENDLY gets indifferent + friendly facts.
    """
    knowledge_tiers = profile.get("knowledge_tiers")

    if isinstance(knowledge_tiers, dict):
        return _get_tiered_knowledge(knowledge_tiers, attitude)

    # Flat format fallback
    flat_knowledge = profile.get("knowledge", "")
    if not flat_knowledge:
        return []

    # Only reveal flat knowledge at indifferent or better
    attitude_index = _TIER_ORDER.index(attitude.value) if attitude.value in _TIER_ORDER else 2
    if attitude_index >= 2:  # indifferent = index 2
        return [flat_knowledge]
    return []


def _get_tiered_knowledge(
    tiers: dict[str, list],
    attitude: NpcAttitude,
) -> list[str]:
    """Accumulate knowledge from all tiers up to and including the current attitude."""
    attitude_index = _TIER_ORDER.index(attitude.value) if attitude.value in _TIER_ORDER else 2
    facts: list[str] = []

    for i, tier_name in enumerate(_TIER_ORDER):
        if i > attitude_index:
            break
        tier_facts = tiers.get(tier_name, [])
        if isinstance(tier_facts, list):
            facts.extend(tier_facts)

    return facts
