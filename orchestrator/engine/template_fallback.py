"""Template-based response generator for when Ollama is unreachable.

Produces DmResponse-compatible narration and choices per action type,
with multiple variations selected at random so repeated fallbacks
don't feel completely static.
"""

from __future__ import annotations

import random

from orchestrator.models.enums import ActionType


# ---------------------------------------------------------------------------
# Narration templates — keyed by ActionType, each a list of variations.
# Placeholders:
#   {target}    — action.target (or "the area" / "your surroundings")
#   {direction} — action.direction (or "forward")
#   {message}   — action.message (or "...")
#   {rules}     — rules_result string (may be empty)
# ---------------------------------------------------------------------------

_NARRATION: dict[ActionType, list[str]] = {
    ActionType.MOVE: [
        "You make your way {direction}. The shadows shift around you as the path unfolds.",
        "Footsteps echo as you move {direction}. The air carries a faint chill.",
        "You press on {direction}, keeping your wits about you.",
    ],
    ActionType.ATTACK: [
        "You steel yourself and strike at {target}. {rules}",
        "With a fierce cry you swing at {target}! {rules}",
        "You lunge toward {target}, weapon raised. {rules}",
    ],
    ActionType.SPEAK: [
        'You turn to {target} and say, "{message}" They regard you thoughtfully before replying.',
        '{target} listens as you speak. "{message}" A moment of silence follows.',
        '"{message}" you say to {target}. They nod slowly, considering your words.',
    ],
    ActionType.LOOK: [
        "You survey your surroundings carefully. Stone walls and flickering torchlight greet you.",
        "You take a moment to observe the area. Nothing seems immediately out of place.",
        "Your eyes sweep across the scene, noting exits and potential dangers.",
    ],
    ActionType.REST: [
        "You find a quiet spot and rest for a while. The weariness in your bones begins to fade. {rules}",
        "You settle down to rest, keeping one eye open. Your body thanks you. {rules}",
        "A brief respite. You catch your breath and tend to minor scrapes. {rules}",
    ],
    ActionType.INTERACT: [
        "You reach out and interact with {target}. Something shifts.",
        "You examine {target} more closely, looking for anything useful.",
        "Your hands find {target}. It responds to your touch in an expected way.",
    ],
    ActionType.USE_ITEM: [
        "You rummage through your belongings and use the item.",
        "You pull out the item and put it to use. It serves its purpose.",
        "With practiced hands you employ the item. The effect is immediate.",
    ],
    ActionType.CAST_SPELL: [
        "Arcane energy crackles at your fingertips as you weave the spell. {rules}",
        "You speak the incantation and feel the magic surge through you. {rules}",
        "The air shimmers with magical energy as you complete the casting. {rules}",
    ],
    ActionType.CUSTOM: [
        "You act decisively. The world responds in kind.",
        "Your actions set events in motion. What comes next remains to be seen.",
        "You do what must be done. The consequences will reveal themselves.",
    ],
}

# ---------------------------------------------------------------------------
# Choice templates — keyed by ActionType
# ---------------------------------------------------------------------------

_CHOICES: dict[ActionType, list[list[str]]] = {
    ActionType.MOVE: [
        ["Continue forward", "Look around", "Go back the way you came"],
        ["Press onward carefully", "Search for hidden passages", "Rest here a moment"],
    ],
    ActionType.ATTACK: [
        ["Attack again", "Fall back to a defensive position", "Look for an advantage"],
        ["Press the attack", "Try to disarm your foe", "Disengage and regroup"],
    ],
    ActionType.SPEAK: [
        ["Continue the conversation", "Ask about local rumors", "Take your leave"],
        ["Press for more information", "Change the subject", "Say farewell"],
    ],
    ActionType.LOOK: [
        ["Investigate something interesting", "Move on", "Search more thoroughly"],
        ["Examine the nearest object", "Check for hidden doors", "Continue forward"],
    ],
    ActionType.REST: [
        ["Get up and move on", "Rest a while longer", "Check your supplies"],
        ["Continue your journey", "Tend to your equipment", "Look around"],
    ],
    ActionType.INTERACT: [
        ["Try something else with it", "Move on", "Look around for more"],
        ["Examine it further", "Take it with you", "Leave it alone"],
    ],
    ActionType.USE_ITEM: [
        ["Use another item", "Look around", "Continue onward"],
        ["Check your inventory", "Move forward", "Rest"],
    ],
    ActionType.CAST_SPELL: [
        ["Cast another spell", "Conserve your magic", "Examine the result"],
        ["Try a different approach", "Move carefully forward", "Take a short rest"],
    ],
    ActionType.CUSTOM: [
        ["Look around", "Move forward", "Check inventory"],
        ["Investigate further", "Press onward", "Rest a moment"],
    ],
}


def generate_fallback_narration(
    action_type: ActionType,
    *,
    target: str | None = None,
    direction: str | None = None,
    message: str | None = None,
    rules_result: str | None = None,
) -> str:
    """Pick a random narration template for *action_type* and fill placeholders.

    Returns a flavorful (but generic) narration string compatible with
    ``DmResponse.narration``.
    """
    templates = _NARRATION.get(action_type, _NARRATION[ActionType.CUSTOM])
    template = random.choice(templates)

    narration = template.format(
        target=target or "your surroundings",
        direction=direction or "forward",
        message=message or "...",
        rules=rules_result or "",
    )

    # Clean up any double-spaces left by empty {rules} etc.
    return " ".join(narration.split())


def generate_fallback_choices(action_type: ActionType) -> list[str]:
    """Pick a random set of choices appropriate for *action_type*.

    Returns a list of 3 choice strings compatible with
    ``DmResponse.choices``.
    """
    choice_sets = _CHOICES.get(action_type, _CHOICES[ActionType.CUSTOM])
    return list(random.choice(choice_sets))
