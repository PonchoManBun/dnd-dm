# 11 — Combat System

## Overview

Combat is **turn-based on a grid**, following D&D 5e rules. Each turn represents 6 seconds of in-game time. The AI DM resolves all mechanics — rolls, modifiers, conditions, and outcomes.

## Action Economy

Each turn, a character gets:

- **Movement** — Up to speed in feet (e.g., 30 ft = 5 tiles)
- **Action** — Attack, Cast a Spell, Dash, Disengage, Dodge, Help, Hide, Ready, Search, Use an Object
- **Bonus Action** — Class features, off-hand attacks, certain spells
- **Reaction** — One per round (opportunity attacks, Shield, Counterspell, etc.)

## Initiative & Turn Order

1. DM rolls initiative for all combatants (d20 + DEX mod).
2. Turn order displayed in the UI.
3. On the player's turn, movement and action options are presented.
4. On enemy turns, the DM resolves and narrates actions.

## The Reaction Window

After enemy actions resolve, the player gets a **reaction window**:

1. DM presents the triggering event (*"The orc swings at you..."*)
2. Player sees available reactions (Shield, Counterspell, opportunity attack, or Skip)
3. Player chooses. DM resolves.
4. Turn completes.

This is critical to preserving D&D's reaction system in a digital format.

## Dice & Rolls

All rolls use the full d20 system. Every roll is shown to the player:

- Attack rolls, damage rolls, saving throws
- Skill checks during combat (grapple, shove, etc.)
- Concentration checks when hit while maintaining a spell

Dice are rendered as animated pixel sprites in the DM panel. An optional cinematic mode renders them in the main viewport.

## Conditions

Full D&D 5e conditions: Blinded, Charmed, Deafened, Frightened, Grappled, Incapacitated, Invisible, Paralyzed, Petrified, Poisoned, Prone, Restrained, Stunned, Unconscious. The DM tracks and applies all effects.

## Combat Log

A scrollable text log records every action, roll, and result for reference.
