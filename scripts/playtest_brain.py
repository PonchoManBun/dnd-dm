#!/usr/bin/env python3
"""Playtest brain: reads DebugMonitor JSON, decides next key to press.

Usage: python3 playtest_brain.py <path_to_shot_NNNN.json>
Outputs a single key name to stdout (e.g. "w", "a", "p", "period").
"""

import json
import math
import random
import sys


# Direction key mapping: (dx, dy) -> xdotool key name
DIRECTION_KEYS = {
    (0, -1): "w",     # up
    (0, 1): "s",      # down
    (-1, 0): "a",     # left
    (1, 0): "d",      # right
    (-1, -1): "q",    # up-left
    (1, -1): "e",     # up-right
    (-1, 1): "z",     # down-left
    (1, 1): "c",      # down-right
}


def distance(a: list[int], b: list[int]) -> float:
    return math.sqrt((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2)


def direction_toward(src: list[int], dst: list[int]) -> tuple[int, int]:
    """Returns (dx, dy) unit direction from src toward dst."""
    dx = dst[0] - src[0]
    dy = dst[1] - src[1]
    # Clamp to -1, 0, 1
    dx = max(-1, min(1, dx))
    dy = max(-1, min(1, dy))
    return (dx, dy)


def key_toward(src: list[int], dst: list[int], walkable: list[list[int]]) -> str | None:
    """Find key to move from src toward dst, preferring walkable neighbors."""
    d = direction_toward(src, dst)
    target = [src[0] + d[0], src[1] + d[1]]

    # If target is walkable, go there
    if target in walkable:
        return DIRECTION_KEYS.get(d)

    # Try adjacent directions
    alternatives = []
    for pos in walkable:
        dist = distance(pos, dst)
        dx = pos[0] - src[0]
        dy = pos[1] - src[1]
        key = DIRECTION_KEYS.get((dx, dy))
        if key:
            alternatives.append((dist, key))

    if alternatives:
        alternatives.sort(key=lambda x: x[0])
        return alternatives[0][1]

    return None


def decide_exploration(state: dict) -> str:
    """Decide action during exploration mode."""
    player_pos = state.get("player_pos", [-1, -1])
    player_hp = state.get("player_hp", 0)
    player_max_hp = state.get("player_max_hp", 1)
    items = state.get("items_at_feet", [])
    walkable = state.get("walkable_neighbors", [])
    stairs_down = state.get("stairs_down_pos")
    monsters = state.get("monsters_visible", [])

    if not walkable:
        # No walkable neighbors — wait
        return "x"

    # 1. Pick up items at feet
    if items:
        return "p"

    # 2. If low HP, rest (period key = wait/rest)
    if player_max_hp > 0 and player_hp / player_max_hp < 0.3:
        return "x"

    # 3. If stairs down visible, move toward them (70% of the time — explore otherwise)
    if stairs_down and stairs_down != [player_pos[0], player_pos[1]]:
        if random.random() < 0.7:
            key = key_toward(player_pos, stairs_down, walkable)
            if key:
                return key

    # 4. If stairs down is at player pos, go down
    if stairs_down and stairs_down == [player_pos[0], player_pos[1]]:
        return "greater"  # '>' key to go downstairs

    # 5. Move toward nearest hostile monster (to trigger combat)
    hostile = [m for m in monsters if m.get("hostile")]
    if hostile:
        nearest = min(hostile, key=lambda m: distance(player_pos, m["pos"]))
        key = key_toward(player_pos, nearest["pos"], walkable)
        if key:
            return key

    # 6. Random exploration — pick a random walkable neighbor
    pos = random.choice(walkable)
    dx = pos[0] - player_pos[0]
    dy = pos[1] - player_pos[1]
    key = DIRECTION_KEYS.get((dx, dy))
    return key or "period"


def decide_combat(state: dict) -> str:
    """Decide action during combat mode."""
    combat = state.get("combat_state")
    if not combat:
        return "x"

    # Not our turn — wait
    if not combat.get("is_player_turn"):
        return "x"

    player_pos = state.get("player_pos", [-1, -1])
    walkable = state.get("walkable_neighbors", [])
    monsters = state.get("monsters_visible", [])
    has_action = combat.get("has_action", False)
    movement = combat.get("movement_remaining", 0)

    hostile = [m for m in monsters if m.get("hostile")]

    if not hostile:
        # No visible hostiles — end turn (space = end_turn action)
        return "space"

    nearest = min(hostile, key=lambda m: distance(player_pos, m["pos"]))
    dist = distance(player_pos, nearest["pos"])

    # Adjacent hostile and have action — bump to attack
    if dist < 1.5 and has_action:
        d = direction_toward(player_pos, nearest["pos"])
        key = DIRECTION_KEYS.get(d)
        return key or "period"

    # Adjacent but no action — end turn (can't attack)
    if dist < 1.5 and not has_action:
        return "space"

    # Have movement and action — move toward nearest hostile to attack
    if movement > 0 and has_action:
        key = key_toward(player_pos, nearest["pos"], walkable)
        if key:
            return key

    # Exhausted — end turn
    return "space"


def decide(state: dict) -> str:
    """Main decision function."""
    scene = state.get("scene", "unknown")

    # Not in game scene — can't do anything useful
    if scene != "game":
        return "Return"

    # Game over
    if state.get("game_over"):
        return "Return"

    # Modal visible — dismiss it
    if state.get("modal_visible"):
        return "Return"

    # Not waiting for input — skip
    if not state.get("waiting_for_input"):
        return "__wait__"

    game_mode = state.get("game_mode", "exploration")
    if game_mode == "combat":
        return decide_combat(state)
    else:
        return decide_exploration(state)


def main():
    if len(sys.argv) < 2:
        print("Usage: playtest_brain.py <shot_NNNN.json>", file=sys.stderr)
        sys.exit(1)

    json_path = sys.argv[1]
    try:
        with open(json_path) as f:
            state = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError) as e:
        print(f"Error reading {json_path}: {e}", file=sys.stderr)
        sys.exit(1)

    key = decide(state)
    print(key)


if __name__ == "__main__":
    main()
