# 04 — Character Creation

## Overview

Character creation follows D&D 5e SRD rules. The player builds a single character through a streamlined 4-step flow. The UI is built entirely in code (no .tscn dependency) with animated step transitions, selection highlighting, and a character summary preview.

## Races (9)

All 9 SRD races are available, each with ability score bonuses, speed, and size:

| Race | Ability Bonuses | Speed | Size |
|------|----------------|-------|------|
| Human | STR +1, DEX +1, CON +1, INT +1, WIS +1, CHA +1 | 30 ft. | Medium |
| Elf | DEX +2 | 30 ft. | Medium |
| Dwarf | CON +2 | 25 ft. | Medium |
| Halfling | DEX +2 | 25 ft. | Small |
| Half-Orc | STR +2, CON +1 | 30 ft. | Medium |
| Gnome | INT +2 | 25 ft. | Small |
| Dragonborn | STR +2, CHA +1 | 30 ft. | Medium |
| Half-Elf | CHA +2 | 30 ft. | Medium |
| Tiefling | INT +1, CHA +2 | 30 ft. | Medium |

Race descriptions and traits are loaded from `game/assets/data/races.json`.

## Classes (12)

All 12 SRD classes are available, each with hit die, primary ability, saving throw proficiencies, armor proficiencies, skill choices, and class features through level 3:

| Class | Hit Die | Primary Ability | Saving Throws | Armor | Skills |
|-------|---------|----------------|---------------|-------|--------|
| Fighter | d10 | STR | STR, CON | All + Shields | 2 of 8 |
| Wizard | d6 | INT | INT, WIS | None | 2 of 6 |
| Rogue | d8 | DEX | DEX, INT | Light | 4 of 11 |
| Cleric | d8 | WIS | WIS, CHA | Light, Medium, Shields | 2 of 5 |
| Ranger | d10 | DEX | STR, DEX | Light, Medium, Shields | 3 of 8 |
| Paladin | d10 | STR | WIS, CHA | All + Shields | 2 of 6 |
| Barbarian | d12 | STR | STR, CON | Light, Medium, Shields | 2 of 6 |
| Bard | d8 | CHA | DEX, CHA | Light | 3 of any |
| Druid | d8 | WIS | INT, WIS | Light, Medium, Shields | 2 of 8 |
| Monk | d8 | DEX | STR, DEX | None | 2 of 6 |
| Sorcerer | d6 | CHA | CON, CHA | None | 2 of 6 |
| Warlock | d8 | CHA | WIS, CHA | Light | 2 of 7 |

Class descriptions are loaded from `game/assets/data/classes.json`. Each class has defined features, scaling resources (rage charges, spell slots, ki points, etc.), and spellcasting where applicable.

## Creation Flow (4 Steps)

### Step 1: Choose Race

Grid of 9 race buttons (3 columns). Selecting a race displays its description, ability bonuses, speed, and traits in a detail panel on the right. Default selection: Human.

### Step 2: Choose Class

Grid of 12 class buttons (3 columns). Selecting a class displays its description, hit die, primary ability, and saving throws. Default selection: Fighter.

### Step 3: Roll Abilities

Six ability scores (STR, DEX, CON, INT, WIS, CHA) rolled using the standard 4d6-drop-lowest method. Displays three columns: base roll, racial bonus, and total. A "Re-Roll" button lets the player re-roll all scores with an animation effect. Racial bonuses from Step 1 are applied and displayed automatically.

### Step 4: Name & Confirm

Text input for character name (max 24 characters) with a "Random" button that picks from a pool of 30 fantasy names. Displays a full character summary: race, class, hit die, speed, all ability scores with modifiers, and starting HP.

The "Confirm" button (disabled until a name is entered) finalizes the character and emits the `character_created` signal.

## What Is NOT in Character Creation

- No alignment selection
- No skill proficiency selection (automated based on class)
- No background selection
- No DM-generated backstory (reserved for Phase 2 LLM integration)
- No starting equipment selection (class defaults applied)
- No starting gold roll

## Character Initialization on Confirm

When the player confirms:
- Level set to 1, XP to 0
- Ability scores = base rolls + racial bonuses
- Speed from race data
- HP = class hit die + CON modifier (minimum 1)
- AC = 10 + DEX modifier (no starting armor)
- Saving throw proficiencies from class data
- Armor proficiencies from class data
- Class features initialized via `CharacterData.initialize_class_features()`

## Companion Recruitment (Planned)

After creation, the player can recruit NPC companions through conversation:
- NPCs start with monster stat blocks; stat blocks convert to full `CharacterData` character sheets upon recruitment
- First XP earned grants the companion their first class level
- Party size: up to 3 companions + 1 player character (4 total)
- Any NPC encountered in the world can potentially be recruited

## Source Files

- `game/scenes/character_creation/character_creation.gd` — Full creation flow (UI built in code)
- `game/src/character_data.gd` — `CharacterData` Resource with all enums, race/class data tables, and derived-value helpers
- `game/assets/data/races.json` — Race descriptions and traits
- `game/assets/data/classes.json` — Class descriptions
