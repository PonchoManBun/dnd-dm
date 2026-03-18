# 11 — Combat System

## Overview

Combat is **turn-based on a grid**, following D&D 5e rules. Each turn represents 6 seconds of in-game time. The rules engine (`RulesEngine` in GDScript) handles all mechanical resolution — rolls, modifiers, conditions, and outcomes. The game mode state machine (`GameMode`) manages the transition between Exploration and Combat modes.

## Combat Modes

The game has two modes managed by `GameMode`:

- **EXPLORATION** — Roguelike turns. Grid movement, bump-to-interact, one action per turn. Monsters accumulate energy and act when they have enough.
- **COMBAT** — D&D 5e tactical mode. Initiative order, full action economy, positioning matters.

Combat starts when the player bumps an enemy (attack trigger) or when aggressive hostile monsters become visible (FOW reveal trigger). The `_check_combat_trigger()` method in `World` handles both cases.

## Action Economy

Each turn, a combatant gets (tracked by `CombatState`):

- **Movement** — `movement_remaining` in tiles (base `speed_feet / 5`, modified by conditions). Default 6 tiles (30 ft). Condition modifiers: Grappled/Restrained = 0 speed, Prone = halved.
- **Action** — `has_action`. Used for attacks, spell casting, and other main actions.
- **Bonus Action** — `has_bonus_action`. Available for class features and certain spells.
- **Reaction** — `has_reaction`. Tracked per combatant, resets at the start of their turn.

Action economy is validated before execution via `_validate_combat_action()`. Movement, actions, and bonus actions are consumed as `_consume_combat_resources()` processes the result effects. When a combatant exhausts all resources (`is_turn_exhausted()`), their turn auto-advances.

Players can also manually end their turn with the Space key.

## Initiative & Turn Order

1. All combatants roll initiative: `d20 + DEX modifier + initiative_bonus` (via `RulesEngine.initiative_roll()`).
2. Sorted highest first; ties broken by higher DEX score.
3. Turn order is displayed in the **InitiativeTracker** panel (top-left during combat).
4. The tracker shows: initiative values, names, HP, action economy status (Move/Act/Bon/Rea), and highlights the active combatant.
5. On the player's turn, the player uses movement and actions freely until exhausted.
6. On enemy turns, `MonsterAI` behavior trees decide actions, and `apply_combat_monster_turn()` resolves them.
7. Surprised combatants (set via `is_surprised` flag) lose their first-round turn.

## Party Combat

The current implementation supports a single player character plus multiple enemies. All combatants (player and enemies) roll initiative and are sorted into a shared turn order.

**Planned:** BG3-style party system where multiple player-controlled companions each take individual turns in initiative order. The player would control each companion's turn separately.

## Reactions

Reactions are **tracked but not prompted**. Each `CombatState` has a `has_reaction` flag and a `use_reaction()` method, but the game does not currently present a reaction window to the player during enemy turns. Reaction tracking exists in the data model for future implementation.

**Planned:** A reaction window that pauses after enemy actions and prompts the player to use available reactions (opportunity attacks, Shield, Counterspell, etc.).

## Dice & Rolls

All rolls use the full d20 system via `RulesEngine`. Every roll is computed and displayed as **text** in the combat log:

- **Attack rolls:** `d20 + ability modifier + proficiency bonus` vs target AC. Natural 1 always misses, natural 20 always hits (critical).
- **Damage rolls:** `NdX + ability modifier`. Critical hits double the dice count (not the modifier).
- **Saving throws:** `d20 + ability modifier + proficiency bonus (if proficient)` vs DC. Auto-fail on STR/DEX saves when Paralyzed, Stunned, or Unconscious.
- **Ability checks:** `d20 + ability modifier + proficiency bonus (if proficient)` vs DC. Expertise doubles the proficiency bonus.
- **Advantage/Disadvantage:** Roll 2d20, take highest (advantage) or lowest (disadvantage). Advantage and disadvantage cancel each other.

Roll results are formatted as strings like: `"d20(15)+5(mod3+prof2)=20 vs AC 13 HIT!"` and displayed in the combat log and DM panel.

Dice are **text-only** — there are no animated dice sprites.

## Attack Resolution

`RulesEngine.resolve_attack()` handles the full melee/ranged attack flow:

1. Roll attack (d20 + modifier + proficiency).
2. Compare to target AC.
3. On hit, roll damage (weapon dice + ability modifier, doubled dice on crit).
4. Returns an `AttackResult` with hit/miss, damage, damage type, and formatted descriptions.

## Class Feature Integration

The rules engine resolves class-specific combat features:

- **Sneak Attack (Rogue):** `resolve_sneak_attack()` — adds Nd6 bonus damage when the Rogue has advantage. Dice scale with level.
- **Rage Damage (Barbarian):** `resolve_rage_bonus()` — flat bonus to melee weapon damage while rage is active. Scales at levels 9 and 16.
- **Action Surge (Fighter):** `apply_action_surge()` — spends a charge to restore the action for the current turn.
- **Extra Attack:** Tracked via `has_used_extra_attack` on CombatState.

## Conditions

All 14 SRD conditions are defined in `CharacterData.Condition`:

Blinded, Charmed, Deafened, Frightened, Grappled, Incapacitated, Invisible, Paralyzed, Petrified, Poisoned, Prone, Restrained, Stunned, Unconscious.

**Conditions with implemented mechanical effects:**

- **Blinded:** Grants advantage to attackers, imposes disadvantage on the blinded creature's attacks.
- **Frightened:** Imposes disadvantage on the frightened creature's attacks.
- **Poisoned:** Imposes disadvantage on the poisoned creature's attacks.
- **Grappled:** Speed reduced to 0.
- **Restrained:** Speed reduced to 0, grants advantage to attackers, imposes disadvantage on attacks.
- **Prone:** Speed halved, grants advantage to melee attackers, imposes disadvantage on attacks.
- **Paralyzed/Stunned/Unconscious:** Auto-fail STR and DEX saving throws, grant advantage to attackers.

Conditions are tracked as an array on `CharacterData` and checked by `RulesEngine.has_advantage_against()`, `has_disadvantage_from_conditions()`, and `apply_condition_speed_modifiers()`.

## Monster AI

Enemy turns are driven by behavior trees (`MonsterAI`). Four behavior profiles exist:

- **AGGRESSIVE:** Check hostility, check visibility, then prioritize ranged combat, melee with weapon-seeking, or basic melee. Falls back to random movement or idle.
- **FEARFUL:** Flees from the player when visible.
- **CURIOUS:** Moves toward the player when visible.
- **PASSIVE:** 50% chance to move randomly, otherwise idle.

The AI system includes intelligence checks, ranged weapon management (equip, load ammo, fire), melee weapon seeking (find nearby weapons, pathfind to them, pick up and equip), and pathfinding with fallback when paths are blocked by other monsters.

## Combat Log

The game log (RichTextLabel in the HUD) records all combat actions, roll results, damage, and state changes as BBCode-formatted text. The DM panel also displays narrative text from the DM alongside mechanical results.

## Combat End

Combat ends (`_should_end_combat()`) when either:
- All enemies are dead (player victory), or
- The player is dead (game over).

On victory, the mode switches back to EXPLORATION and the `combat_ended` signal fires with `victory = true`.
