# 15 — UI & HUD

## Layout Overview

The game uses different layouts depending on the scene:

### Dungeon / Game Scene

```
+------------------------+-----+
|                        | DM  |
|    Game Viewport       |Panel|
|    (pixel art world,   | (192|
|     16x16 tile grid)   |  px)|
|                        |     |
+--+---------------------+-----+
|  |  HUD (Left Panel)          |
|  |  HP, Status, Equipment     |
|  |  Inventory Button          |
|  |  Log Messages              |
+--+----------------------------+
```

### Tavern Scene

```
+------------------+-----------+
|                  |           |
|  Tavern Map      |  DM Panel |
|  (16x16 tiles,   | (narrative|
|   warm tint)     |  + choices|
|                  |  + input) |
|                  |           |
+------------------+-----------+
```

## Game Viewport (Main Area)

- Top-down pixel art rendering of the current dungeon or tavern
- Character sprites, NPCs, enemies, terrain, items, obstacles
- Fog of war overlay (black = unexplored, dimmed = explored but not visible)
- Visual effects: hit vignette shader, ambient vignette shader, dust motes, explosions, status popups, splatter particles
- Reticle for tile hover/targeting
- Camera follows the player with `CameraController`

## DM Panel (Right Side)

The `DMPanel` class (`game/scenes/ui/dm_panel.gd`) is a `PanelContainer` built entirely in code:

- **Header** — "DM" label in cyan
- **Narrative text** — Scrollable `RichTextLabel` with BBCode support. Displays DM descriptions, dialogue, story beats. Dark background (`Color(0.06, 0.05, 0.08, 0.92)`) with light text.
- **Choice buttons** — Dynamically generated numbered buttons in yellow text. Styled with dark backgrounds and hover states. Connected to `NarrativeManager` for choice resolution.
- **Free-text input** — `LineEdit` at the bottom with "Say something..." placeholder. Submits to `NarrativeManager`. Click-to-focus (never auto-grabs keyboard). Escape releases focus.
- **Width:** 192px fixed, anchored to right side of screen
- **Auto-scroll:** Scrolls to bottom when new narrative is added

The DM panel connects to `NarrativeManager` signals: `narrative_added`, `choices_presented`, `narrative_cleared`. It loads existing history on ready.

In the tavern scene, the DM panel is also created programmatically and attached to a UI CanvasLayer.

## Initiative Tracker (Combat Only)

The `InitiativeTracker` class (`game/scenes/ui/initiative_tracker.gd`) is a `PanelContainer` shown only during combat:

- **Header:** "Initiative (Round N)" with round counter
- **Entries:** One line per combatant showing:
  - Initiative value
  - Name
  - HP (current/max)
  - Active combatant highlighted: green `>` for player, red `>` for enemies
  - Dead combatants shown with strikethrough in gray
  - Surprised combatants tagged with `[Surprised]` in yellow
- **Action economy display:** For the active combatant, shows remaining resources:
  - `Mv:N` (cyan) — movement tiles remaining
  - `Act` (lime) — action available
  - `Bon` (yellow) — bonus action available
  - `Rea` (orange) — reaction available
  - `(Space=end)` hint for ending turn
- **Position:** Top-left overlay during combat
- **Visibility:** Hidden during exploration, shown during combat

## HUD (Left Panel)

The `HUD` class (`game/scenes/ui/hud.gd`) is a `MarginContainer` with:

- **HP Bar** — `ProgressBarWithLabel` showing current/max HP
- **Status Text** — `RichTextLabel` showing turn number and other status info
- **Melee Container** — Shows equipped melee weapon info/icons
- **Ranged Container** — Shows equipped ranged weapon info/icons
- **Armor Container** — Shows equipped armor icons
- **Inventory Button** — Opens the inventory modal
- **Log Messages** — Scrollable text log recording combat actions, roll results, and game events with BBCode formatting
- **Hover Info** — Right-aligned text showing information about the tile under the cursor
- **Throw Info** — Centered pulsing text prompt shown during throw targeting
- **DawnLike Notice** — Attribution text for the tileset (dimmed)

## SRD Reference Panel

The `SrdReference` class (`game/scenes/ui/srd_reference.gd`) is a toggleable overlay (press `?`) for looking up D&D 5e SRD rules:

- Split layout: chapter list on the left, content display on the right
- Loads SRD markdown files from the `rules/` directory
- Dark-themed to match the game UI

## Inventory Screen (Modal Overlay)

The `InventoryModal` is opened via the Inventory button or `I` hotkey:

- **Tabbed interface** — Multiple tabs (inventory, equipment)
- **Equipment slots** — Melee, ranged, armor, shield
- **Item list** — Scrollable list of inventory items
- **Actions:** Pickup, drop, equip, unequip, use, throw, reparent (attach modules), toggle containers
- **Drag support** — Items can be dragged between slots

## Other Modals

- **Confirmation Modal** — Yes/No prompts (e.g., "Confirm Escape")
- **Direction Modal** — Directional input for targeting
- **Game Over Modal** — Shown on death

## Key UI Principles

- Dark backgrounds, light text, pixel art consistency
- All UI built in code (no .tscn for DM panel, initiative tracker, or SRD reference — they construct themselves programmatically)
- Keyboard-navigable — WASD/arrow keys for movement, Space for end turn, I for inventory, `?` for SRD reference, Escape for focus release
- BBCode-formatted text throughout for color coding and emphasis
- Modal stack system (`Modals` singleton) with fade-in/fade-out transitions

## Planned (Not Yet Implemented)

- **Companion portraits/status** — BG3-style party member portraits showing HP, conditions, and turn status in the HUD
- **Speaker selection dropdown** — UI for selecting which party member speaks during NPC dialogue
- **TTS icon** — Text-to-speech marker on narrative text (deferred post-MVP)
- **Hotbar** — Quick-access slots for frequently used actions (attack, spells, items)
- **Minimap toggle** — If the player has a map item
- **Spellbook** (`B`) — Available spells, prepared spells, slot tracker
- **Quest Log** (`J`) — Active and completed quests
- **World Map** (`M`) — Overworld node map
- **Character Sheet** (`C`) — Full stats, skills, features overlay
