"""Dice rolling utilities for D&D 5e.

Pure functions wrapping random.randint for testability and clarity.
"""

from __future__ import annotations

import random


def roll(num_dice: int, sides: int) -> int:
    """Roll *num_dice* dice each with *sides* faces and return the sum."""
    return sum(random.randint(1, sides) for _ in range(num_dice))


def d20() -> int:
    """Roll a single d20."""
    return random.randint(1, 20)


def roll_4d6_drop_lowest() -> int:
    """Roll 4d6, drop the lowest die, return the sum (ability score generation)."""
    rolls = [random.randint(1, 6) for _ in range(4)]
    rolls.sort()
    return sum(rolls[1:])  # drop index 0 (the lowest)
