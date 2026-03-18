"""Keyword-based conversation mode detection.

Runs in ~0ms -- no LLM call needed. Detects mode from player message content
and NPC capabilities.
"""

from __future__ import annotations

import logging

from orchestrator.models.npc_agent import ConversationMode, NpcAttitude

logger = logging.getLogger(__name__)

# Keyword sets for mode detection
_BARTER_KEYWORDS = {"buy", "sell", "cost", "price", "how much", "trade", "purchase", "shop", "wares"}
_QUEST_KEYWORDS = {"quest", "job", "work", "task", "mission", "help me", "need help", "bounty"}
_RECRUIT_KEYWORDS = {"join", "recruit", "come with", "party", "travel with", "hire"}
_WARNING_KEYWORDS = {"danger", "warning", "beware", "careful", "watch out", "threat"}


def detect_mode(
    message: str,
    profile: dict,
    current_mode: ConversationMode,
    attitude: NpcAttitude,
) -> ConversationMode:
    """Detect conversation mode from player message and NPC profile.

    Returns the detected mode, or the current mode if no change detected.
    """
    msg_lower = message.lower()

    # Hostile/Unfriendly NPCs refuse unless intimidated
    if attitude in (NpcAttitude.HOSTILE, NpcAttitude.UNFRIENDLY):
        return ConversationMode.REFUSING

    # Check for barter keywords (only if NPC has inventory)
    if profile.get("bartering_inventory") and _matches_keywords(msg_lower, _BARTER_KEYWORDS):
        return ConversationMode.BARTERING

    # Check for quest keywords (only if NPC has quest data)
    if (profile.get("quest_data") or profile.get("quest_hooks")) and _matches_keywords(msg_lower, _QUEST_KEYWORDS):
        return ConversationMode.QUEST_GIVING

    # Check for recruit keywords (only if NPC is recruitable)
    if profile.get("recruitable") and _matches_keywords(msg_lower, _RECRUIT_KEYWORDS):
        return ConversationMode.RECRUITING

    # Check for warning keywords
    if _matches_keywords(msg_lower, _WARNING_KEYWORDS):
        return ConversationMode.WARNING

    # Default: stay in current mode or return to chatting
    return current_mode if current_mode != ConversationMode.REFUSING else ConversationMode.CHATTING


def _matches_keywords(text: str, keywords: set[str]) -> bool:
    """Check if text contains any of the keywords."""
    for keyword in keywords:
        if keyword in text:
            return True
    return False
