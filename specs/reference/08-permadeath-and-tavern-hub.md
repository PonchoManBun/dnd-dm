# 08 — Permadeath & Tavern Hub

## Permadeath

Death is permanent. When a character reaches 0 HP, they die. There is no last-stand mechanic, no death saving throws in practice, and no resurrection.

### Death Flow (Current Implementation)

1. **0 HP** — The monster's `is_dead` flag is set to `true`.
2. **Death detection** — `World` checks `player.is_dead` after each action. If true, sets `game_over = true` and emits `game_ended`.
3. **Death effect** — A `DeathEffect` is emitted for visual/audio feedback. The `AudioManager` plays a descending tone death sound.
4. **Save deletion** — `AutoSave` deletes the save file on `game_ended` (roguelike anti-scumming).
5. **Game over modal** — `Modals.show_game_over()` displays the game over screen.

### Party Death

**Planned:** With the BG3-style party system, the game continues as long as any companion is alive. Only when all party members (player character + companions) are dead does the game end. Individual companion death removes them from the initiative order and party roster.

### Death Saves

`CharacterData` has `death_save_successes` and `death_save_failures` fields, and they are serialized in save files, but death saves are not mechanically used. Death currently means 0 HP = instant death.

### No Save-Scumming

Saves are roguelike-style:
- **Continuous auto-save** — `AutoSave` writes game state to `user://save.json` after every turn via atomic writes (write to `.tmp`, then rename)
- **Delete on resume** — Loading a save immediately deletes the save file
- **Delete on death** — Character death / game end triggers save deletion
- **No manual save** — No save points, no branching

## The Tavern Hub

The Welcome Wench is the persistent home base. It is a full pixel art scene where the player walks around, interacts with objects, and talks to NPCs.

### Tavern Implementation

The tavern is built from a **24x20 ASCII map layout** defined in both `tavern.gd` and `TavernMap`. The map uses single characters to define the layout:

```
# = Wall      . = Open floor    B = Bar counter
T = Table      c = Chair          Q = Quest board
s = Shop       S = Stairs         M = Memorial wall
R = Room door  D = Entrance door  * = Barkeep position
```

The tavern scene (`game/scenes/tavern/tavern.gd`) builds everything programmatically:
- **Visual layers:** Floor, walls, furniture, NPCs, player (rendered as separate Node2D layers)
- **Tile rendering:** Uses DawnLike world tile atlas with ColorRect fallback when atlases are unavailable
- **Warm atmosphere:** `CanvasModulate` with warm candlelight tint (`Color(1.0, 0.92, 0.82)`), plus warm-tinted DustMotes particles
- **16x16 tile grid:** Same tile size as the dungeon

### Tavern Features

- **Bar** — Bump into the barkeep (Marta) to talk. Conversation offers choices: ask about the cellar, order a drink, ask about rumors. When the orchestrator is available, sends a `speak` action for freeform LLM dialogue.
- **Quest board** — Bump into Q tiles. Shows "Adventurers Wanted" notice with placeholder text. Choices: look more closely or step away. Full quest system is planned.
- **Shop** — Bump into s tiles. Displays a price list (Health Potion 50 gp, Torch 1 gp, Rations 5 sp, Rope 1 gp, Antidote 50 gp). Purchasing is not yet implemented.
- **Rooms (Stairs)** — Bump into S tiles. Mentions resting. Long rest mechanics exist in the orchestrator but the tavern rest flow is not connected.
- **Room doors** — Bump into R tiles. Shows "locked, ask barkeep" message.
- **NPCs** — Three fixed-position NPCs with distinct personalities:
  - **Barkeep Marta** (position 12,13) — warm amber tint, tavern owner
  - **Old Tom** (position 10,3) — earthy brown tint, retired adventurer at a table
  - **Elara the Quiet** (position 17,5) — deep purple/blue tint, mysterious hooded traveler
- **Memorial wall** — Bump into M tiles. Reads fallen hero names from `user://memorial.json`. Displays names with class and level if available. Choice to pay respects or step away.
- **Entrance doors** — Walking into D tiles emits `exit_triggered` to leave the tavern.

### NPC Interaction

NPCs use a bump-to-interact system:
- Walking into an NPC's tile triggers interaction
- First interaction shows the NPC's greeting from their profile and presents hardcoded choices
- Repeat interactions show varied short acknowledgments (cycling through 3 options per NPC) before presenting the same choices
- When the orchestrator is available, interactions send a `speak` action with the NPC's profile for freeform LLM conversation
- NPC profiles are loaded from `res://assets/data/npc_profiles.json`

### DM Panel in Tavern

The tavern has its own DM panel (right side of screen) that displays:
- Opening narrative describing the tavern atmosphere
- NPC dialogue and interaction text
- Choice buttons for conversation options
- Free-text input field

The panel connects to `NarrativeManager` for text display and choice handling.

### Player Movement

- WASD or arrow keys for grid-based movement
- Player spawns at position (21, 17) — just inside the entrance
- Camera centered on player with 2x zoom
- Walkability is computed from the ASCII map layout

## World Memory

**Not yet implemented.** The memorial wall reads from a `memorial.json` file if it exists, but no system currently writes fallen hero records to this file. The planned features include:

- NPCs remembering previous characters via their state files
- Disposition resetting for new characters but knowledge persisting
- Faction reputations carrying forward as world state
- Cross-death narrative references generated by the LLM
