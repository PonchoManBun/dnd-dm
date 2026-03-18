# 06 — Progression & Leveling

## Level Range

Characters progress from **level 1 to 20**, following the full D&D 5e XP table. There is no level scaling or rubber-banding — the world's difficulty is fixed, and the player must choose which challenges to face.

## XP Thresholds

XP thresholds are defined in `CharacterData.XP_THRESHOLDS` (indexed by level - 1):

```
Level  1:      0 XP    Level 11:  85,000 XP
Level  2:    300 XP    Level 12: 100,000 XP
Level  3:    900 XP    Level 13: 120,000 XP
Level  4:  2,700 XP    Level 14: 140,000 XP
Level  5:  6,500 XP    Level 15: 165,000 XP
Level  6: 14,000 XP    Level 16: 195,000 XP
Level  7: 23,000 XP    Level 17: 225,000 XP
Level  8: 34,000 XP    Level 18: 265,000 XP
Level  9: 48,000 XP    Level 19: 305,000 XP
Level 10: 64,000 XP    Level 20: 355,000 XP
```

`CharacterData` tracks `experience_points` and `level` as exported fields. The level field is set during character creation and serialized in save files.

## XP Awards

The AI DM awards XP based on:

- **Combat** — Monster CR converted to XP per SRD encounter tables
- **Exploration** — Discovering locations, solving puzzles, disarming traps
- **Roleplay** — Meaningful NPC interactions, clever problem-solving, in-character decisions

**Current status:** XP tracking fields exist on `CharacterData` (`experience_points`, `level`) and are serialized/deserialized, but automated XP awards are not yet wired into combat victory or other triggers.

## Level-Up Flow

**Planned flow (not yet implemented as a ceremony):**

1. **DM narrates the moment.** "You feel something shift. The sword feels lighter. The spells come easier."
2. **DM presents options.** Class features, ability score improvements, new spells, subclass choices — all explained in-character.
3. **Player chooses.** Selects from the presented options.
4. **Sheet updates.** HP increases (hit die roll + CON mod), new features added, spell slots expanded.

**What exists now:**
- `CharacterData.get_max_hp_for_level()` — Calculates correct HP for any level (max hit die at level 1, average + CON mod per subsequent level)
- `CharacterData.get_proficiency_bonus()` — Returns `2 + (level - 1) / 4`, scaling every 4 levels
- `CharacterData.initialize_class_features()` — Populates all class-specific resources based on current level (rage charges, sneak attack dice, action surge charges, spell slots, ki points, etc.)
- `CharacterData.restore_all_resources()` — Restores all per-rest resources (long rest)

There is no automated level-up ceremony, stat selection UI, or DM narration trigger when XP thresholds are crossed.

## Class Features

All 12 SRD classes are defined in `CharacterData.CLASS_DATA` with level-scaled features:

| Class | Hit Die | Primary | Key Level-Scaled Features |
|-------|---------|---------|--------------------------|
| Fighter | d10 | STR | Fighting Style (1), Second Wind (1), Action Surge (2), Martial Archetype (3) |
| Wizard | d6 | INT | Spellcasting (1), Arcane Recovery (1), Arcane Tradition (2) |
| Rogue | d8 | DEX | Sneak Attack (1, scales odd levels), Expertise (1), Cunning Action (2) |
| Cleric | d8 | WIS | Spellcasting (1), Divine Domain (1), Channel Divinity (2) |
| Ranger | d10 | DEX | Favored Enemy (1), Natural Explorer (1), Spellcasting (2) |
| Paladin | d10 | STR | Divine Sense (1), Lay on Hands (1, 5 HP/level), Spellcasting (2), Divine Smite (2) |
| Barbarian | d12 | STR | Rage (1, charges scale), Unarmored Defense (1), Reckless Attack (2) |
| Bard | d8 | CHA | Spellcasting (1), Bardic Inspiration (1, uses = CHA mod), Jack of All Trades (2) |
| Druid | d8 | WIS | Spellcasting (1), Wild Shape (2, 2 charges) |
| Monk | d8 | DEX | Martial Arts (1), Unarmored Defense (1), Ki (2, points = level) |
| Sorcerer | d6 | CHA | Spellcasting (1), Sorcerous Origin (1), Font of Magic (2) |
| Warlock | d8 | CHA | Pact Magic (1, separate slot system), Eldritch Invocations (2) |

Spell slots follow the standard SRD table per class and level. Warlock uses Pact Magic with its own slot/level scaling.

## Companion XP Tracking

**Planned:** Each companion in the BG3-style party system will track XP separately via their own `CharacterData.experience_points` field. When a companion earns their first XP, they receive the first player class appropriate to their role. XP from combat encounters is split among surviving party members.

## Ability Score Improvements

At ASI levels (4, 8, 12, 16, 19), the player can increase two ability scores by 1 or one score by 2, or take a feat if using SRD feats.

**Current status:** Ability score fields exist on `CharacterData` and can be modified via `set_ability_score()`, but there is no ASI selection UI or automated trigger at the appropriate levels.

## No Meta-Progression

When a character dies, everything resets. No unlockable classes, no inherited gold, no persistent upgrades. The only thing that carries over is the **world's memory** — NPCs remember past heroes (via the memorial wall in the tavern), and the tavern tells their stories. Pure roguelike philosophy: skill and knowledge carry over. Stats don't.
