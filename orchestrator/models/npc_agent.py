"""NPC agent state models for per-NPC LLM conversation system."""

from __future__ import annotations

from enum import Enum

from pydantic import BaseModel, Field


class NpcAttitude(str, Enum):
    HOSTILE = "hostile"
    UNFRIENDLY = "unfriendly"
    INDIFFERENT = "indifferent"
    FRIENDLY = "friendly"
    HELPFUL = "helpful"


# Ordered list for step-based attitude shifts
ATTITUDE_ORDER: list[NpcAttitude] = [
    NpcAttitude.HOSTILE,
    NpcAttitude.UNFRIENDLY,
    NpcAttitude.INDIFFERENT,
    NpcAttitude.FRIENDLY,
    NpcAttitude.HELPFUL,
]

# DC for skill checks by current attitude
ATTITUDE_DC: dict[NpcAttitude, int] = {
    NpcAttitude.HOSTILE: 20,
    NpcAttitude.UNFRIENDLY: 15,
    NpcAttitude.INDIFFERENT: 12,
    NpcAttitude.FRIENDLY: 8,
    NpcAttitude.HELPFUL: 5,
}


class ConversationMode(str, Enum):
    CHATTING = "chatting"
    BARTERING = "bartering"
    QUEST_GIVING = "quest_giving"
    WARNING = "warning"
    REFUSING = "refusing"
    RECRUITING = "recruiting"


class NpcAgentState(BaseModel):
    """Per-NPC conversation state tracked across interactions."""

    npc_id: str
    attitude: NpcAttitude = NpcAttitude.INDIFFERENT
    mode: ConversationMode = ConversationMode.CHATTING
    interaction_count: int = 0
    deception_active: bool = False
    deception_turns_remaining: int = 0
    last_skill_used: str | None = None
    last_skill_success: bool = False
    skill_context: str | None = None
