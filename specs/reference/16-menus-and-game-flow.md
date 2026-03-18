# 16 — Menus & Game Flow

## Game Flow

```
Title Screen -> New Game -> Character Creation -> DM Selection -> Game (Dungeon)
                                                                    ^       |
                                                                    |       v
                                                                 Tavern  Death -> Game Over
                |
            Continue -> Load Save -> Game (Dungeon)
```

The actual flow as implemented in `main_menu.gd`:

1. **Title Screen** — Play button, Continue button (if save exists), Quit button
2. **Character Creation** — Guided class/race/ability score selection (Cancel returns to title)
3. **DM Selection** — Choose from 5 DM archetypes (Cancel returns to character creation)
4. **Game Start** — Character data and archetype stored on `World` via `set_meta()`, scene transitions to `game.tscn`

## Title Screen

The main menu (`game/scenes/menu/main_menu.gd`) provides:

- **Play** — Starts a new game. Deletes any existing save first, then opens character creation.
- **Continue** — Visible only when `AutoSave.save_exists()` returns true. Loads the save via `AutoSave.load_game()` and transitions to the game scene. If load fails, deletes the corrupt save and hides the button.
- **Quit** — Exits the application.

There is also a `--skip-menu` command-line flag for automated playtesting that creates a default Fighter character and skips directly to the game.

## Character Creation

Character creation is loaded as a separate scene (`character_creation.tscn`). On completion, it emits a `character_created` signal with a `CharacterData` resource containing:

- Name, race, class
- Ability scores (STR, DEX, CON, INT, WIS, CHA)
- HP calculated from class hit die + CON modifier
- Initialized class features

## DM Selection

After character creation, the DM archetype selection screen (`dm_selection.gd`) is shown:

- 5 archetypes displayed as a button list on the left
- Selected archetype shows flavor text and gameplay effect on the right
- Confirm stores the archetype ID on `World` and starts the game
- Cancel returns to character creation

## In-Game Menus

### Implemented

- **Inventory** (`I` key or button) — Equipment + backpack. Supports equip, unequip, drop, pickup, use, throw, reparent (attach modules), and toggle containers. Modal overlay with fade-in/fade-out transitions.
- **SRD Reference** (`?` key) — Toggleable overlay for looking up D&D 5e SRD rules from markdown files in `rules/`. Chapter list on the left, content on the right.
- **Confirmation dialogs** — Used for escape confirmation and other yes/no prompts.
- **Direction modal** — Directional input prompt for targeting (throwing, etc.).
- **Game Over modal** — Shown on death.

### Not Yet Implemented

- **Character Sheet** (`C`) — Full stats, skills, features overlay
- **Spellbook** (`B`) — Available spells, prepared spells, slot tracker (casters only)
- **Quest Log** (`J`) — Active and completed quests (DM-maintained)
- **World Map** (`M`) — Overworld node map (requires map item)
- **Settings** (`Esc`) — Pause + settings overlay with audio, display, keybindings

## Save System

The auto-save system (`auto_save.gd`) implements roguelike save semantics:

- **Continuous auto-save** — Game state saved to `user://save.json` after every turn (`turn_ended` signal)
- **Atomic writes** — Writes to `user://save.json.tmp` first, then renames to `save.json` to prevent corruption
- **No manual save** — Player cannot create save points
- **Delete on resume** — `AutoSave.load_game()` deletes the save file after successful load
- **Delete on death** — `game_ended` signal triggers `delete_save()` — no save-scumming
- **Save format** — Single JSON file containing version, timestamp, turn number, map reference, player data (stats, inventory, equipment, character data, status effects, position), and faction affinities
- **Map regeneration** — Maps are not serialized. On load, the `WorldPlan` regenerates maps up to the saved depth, then places the player at the correct position.

## Pause

Not yet implemented. There is no pause overlay or settings menu accessible during gameplay.
