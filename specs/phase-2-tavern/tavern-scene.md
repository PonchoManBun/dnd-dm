# Phase 2 — Tavern Scene Spec

## Overview

The Welcome Wench is the persistent hub between dungeon runs. It is a hand-crafted, fixed-layout tilemap scene where the player walks around, talks to NPCs, and prepares for the next adventure. No procedural generation. The tavern is always the same building, with the same NPCs in the same spots, providing continuity across permadeath resets.

This spec covers the tavern's tilemap layout, NPC placement and profiles, interaction model, visual treatment, scene transitions, and API contract with the orchestrator.

---

## Tavern Layout

### Tilemap Specifications

- **Tile size:** 16x16 pixels (matches `Constants.TILE_SIZE = 16` in the existing codebase)
- **Map dimensions:** 24 tiles wide x 20 tiles tall (384x320 pixels)
- **Tileset:** Reuses `world_tiles.tres` with new tavern-specific tiles added (wood floor, bar counter, tavern walls)
- **Implementation:** Hand-built `TileMapLayer` in a `.tscn` file — NOT generated via `Map` class. The tavern is a scene, not a dungeon level.

### Zone Map

```
    0         1         2
    0123456789012345678901234
  0 ########################
  1 #......................#
  2 #..MMMM..............S#
  3 #..MMMM...TT....TT..S#
  4 #..MMMM...cc....cc...##
  5 #.........TT....TT....#
  6 #.........cc....cc.....#
  7 #......................#
  8 ##..........BB.........#
  9 #R..........BB.........#
 10 #R..........BB.........#
 11 ##..........BB..QQQQ...#
 12 #...........BB..QQQQ...#
 13 #...........*B..QQQQ...#
 14 #......................#
 15 #......................#
 16 #..ssssss..............#
 17 #..ssssss..............#
 18 #......................DD
 19 ########################

Legend:
  #  = Wall (Terrain.Type.DUNGEON_WALL, using tavern wall tiles)
  .  = Floor (wood plank floor tiles)
  B  = Bar counter (Obstacle, not walkable)
  *  = Barkeep Marta position (behind bar, south end)
  T  = Table (Obstacle, not walkable)
  c  = Chair (Obstacle, walkable — decorative)
  M  = Memorial wall zone (wall tiles with plaques)
  Q  = Quest board zone (wall with board obstacle)
  S  = Stairs up to rooms (Obstacle.Type.STAIRS_UP)
  s  = Shop counter zone (counter obstacle)
  R  = Rooms / rest area (behind door)
  D  = Entrance door (south wall, player spawn point)
```

### Zone Descriptions

| Zone | Grid Region | Purpose |
|------|-------------|---------|
| **Entrance** | (22-23, 18) | Double-wide door. Player spawns at (22, 17) facing north. |
| **Bar Area** | (12-13, 8-13) | Vertical bar counter. Barkeep Marta stands at (12, 13). Stools along the player side. |
| **Dining Area** | (10-17, 3-6) | Two tables with chairs. Patron NPCs sit here. |
| **Quest Board** | (16-19, 11-13) | Interactable quest board on the east wall. Placeholder in Phase 2. |
| **Shop Counter** | (2-7, 16-17) | Merchant counter along the south-west wall. Deferred — non-interactive in Phase 2. |
| **Memorial Wall** | (2-5, 2-4) | West wall with memorial plaques. Deferred — decorative only in Phase 2. |
| **Stairs/Rooms** | (22, 2-3) | Stairs up leading to rentable rooms. Rest mechanic (long rest). |

### Collision Rules

- Walls, bar counter, tables, shop counter, and quest board are **not walkable** (solid obstacles).
- Chairs are **walkable** (decorative, player can walk through them).
- NPC tiles are **not walkable** (player cannot occupy NPC positions).
- The entrance door is walkable and triggers scene transition to dungeon when the player steps on it.

---

## NPC Placement

### Fixed NPCs

| NPC | Position | Facing | Behavior |
|-----|----------|--------|----------|
| Barkeep Marta | (12, 13) | South (toward player) | Fixed. Never moves. Always interactable. |
| Patron: Grizzled Dwarf | (11, 3) | East (toward table) | Fixed. Sits at left table. |
| Patron: Hooded Figure | (16, 5) | West (toward table) | Fixed. Sits at right table. |
| Patron: Halfling Bard | (14, 5) | North (toward room) | Fixed. Stands near tables. |

NPCs are rendered as character sprites on the existing sprite layer, placed at fixed grid positions. They do not move, patrol, or change position in Phase 2. NPC scheduling and patrol routes are deferred to Phase 4.

### NPC Sprite Requirements

Each NPC needs a 16x16 idle sprite (single frame or 2-frame idle animation). These are placed as `Sprite2D` nodes in the tavern scene, not as `Monster` entities on a `Map` grid. NPCs are not combatants.

---

## NPC Profiles

NPC profiles are JSON files loaded by the orchestrator to build LLM context prompts. In Phase 2 (standalone, no AI), profiles are loaded by Godot directly and used to display static dialogue. When the orchestrator comes online in Phase 3, the same files drive freeform conversation.

### Profile Format

```json
{
  "npc_id": "barkeep_marta",
  "name": "Barkeep Marta",
  "race": "human",
  "occupation": "tavern_owner",
  "personality": ["warm", "gossipy", "shrewd"],
  "dialogue_style": "Colloquial, uses food metaphors, calls everyone 'love'.",
  "knowledge": [
    "Local rumors and traveler stories",
    "Regulars and their habits",
    "Which adventurers never came back"
  ],
  "goals": [
    "Run a profitable tavern",
    "Protect her regulars",
    "Collect secrets — information is currency"
  ],
  "disposition_default": "friendly",
  "secrets": [
    "Knows the location of the thieves' guild fence",
    "Witnessed a murder she has never reported"
  ],
  "greeting": "Well now, another brave soul walks through my door. What'll it be, love?",
  "position": { "x": 12, "y": 13 },
  "sprite": "barkeep_marta"
}
```

### Phase 2 NPC Profiles

#### Barkeep Marta

```json
{
  "npc_id": "barkeep_marta",
  "name": "Barkeep Marta",
  "race": "human",
  "occupation": "tavern_owner",
  "personality": ["warm", "gossipy", "shrewd"],
  "dialogue_style": "Colloquial, uses food metaphors, calls everyone 'love'.",
  "knowledge": [
    "Local rumors and traveler stories",
    "Regulars and their habits",
    "Which adventurers never came back"
  ],
  "goals": [
    "Run a profitable tavern",
    "Protect her regulars",
    "Collect secrets"
  ],
  "disposition_default": "friendly",
  "secrets": [
    "Knows the thieves' guild fence location",
    "Witnessed a murder she never reported"
  ],
  "greeting": "Well now, another brave soul walks through my door. What'll it be, love?",
  "position": { "x": 12, "y": 13 },
  "sprite": "barkeep_marta"
}
```

#### Grizzled Dwarf (Durgan Ironfoot)

```json
{
  "npc_id": "patron_durgan",
  "name": "Durgan Ironfoot",
  "race": "dwarf",
  "occupation": "retired_mercenary",
  "personality": ["gruff", "loyal", "superstitious"],
  "dialogue_style": "Short sentences, mining metaphors, swears by Moradin.",
  "knowledge": [
    "Old dungeon layouts from years past",
    "Monster weaknesses from firsthand experience",
    "Knows the tavern has a cellar nobody talks about"
  ],
  "goals": [
    "Drink ale in peace",
    "Warn young adventurers about the depths",
    "Find someone brave enough to retrieve his lost axe"
  ],
  "disposition_default": "neutral",
  "secrets": [
    "Lost his entire warband in the Ashmaw Caves",
    "Has a map fragment he will not share easily"
  ],
  "greeting": "Hmph. Another one. Sit down before you fall down.",
  "position": { "x": 11, "y": 3 },
  "sprite": "patron_dwarf"
}
```

#### Hooded Figure (Whisper)

```json
{
  "npc_id": "patron_whisper",
  "name": "Whisper",
  "race": "half-elf",
  "occupation": "informant",
  "personality": ["cautious", "cryptic", "observant"],
  "dialogue_style": "Speaks in half-truths and questions. Never gives a straight answer.",
  "knowledge": [
    "Thieves' guild operations",
    "Who enters and exits the tavern",
    "Secrets overheard from other patrons"
  ],
  "goals": [
    "Gather information for an unknown employer",
    "Stay hidden in plain sight",
    "Find a trustworthy agent for a dangerous job"
  ],
  "disposition_default": "wary",
  "secrets": [
    "Works for a faction the player has not yet encountered",
    "Carries a stolen signet ring"
  ],
  "greeting": "...You're staring. Most people know better.",
  "position": { "x": 16, "y": 5 },
  "sprite": "patron_hooded"
}
```

#### Halfling Bard (Pippa Lightfoot)

```json
{
  "npc_id": "patron_pippa",
  "name": "Pippa Lightfoot",
  "race": "halfling",
  "occupation": "traveling_bard",
  "personality": ["cheerful", "nosy", "dramatic"],
  "dialogue_style": "Theatrical, speaks in rhyme when excited, loves a good story.",
  "knowledge": [
    "Songs and legends about local dungeons",
    "Rumors from other towns",
    "Which monsters are drawn to music"
  ],
  "goals": [
    "Collect stories from adventurers",
    "Compose an epic ballad",
    "Find the legendary Harp of Whisperwind"
  ],
  "disposition_default": "friendly",
  "secrets": [
    "Her songs contain coded messages for the resistance",
    "She is mapping escape routes out of the region"
  ],
  "greeting": "Oh! A new face! Sit, sit! Tell me everything!",
  "position": { "x": 14, "y": 5 },
  "sprite": "patron_halfling"
}
```

### File Location

NPC profiles are stored in `game/assets/data/npcs/` as individual JSON files:

```
game/assets/data/npcs/
  barkeep_marta.json
  patron_durgan.json
  patron_whisper.json
  patron_pippa.json
```

---

## Interaction Model

### Bump-to-Interact

The tavern reuses the dungeon exploration input model: WASD grid movement with bump-to-interact. When the player moves into a tile occupied by an NPC, instead of attacking (as in dungeon combat), the game initiates a conversation.

#### Phase 2: Local Hardcoded Dialogue

In Phase 2 there is no orchestrator and no LLM. NPC interaction works entirely within Godot:

1. Player bumps into NPC tile.
2. Godot loads the NPC profile JSON from `res://assets/data/npcs/<npc_id>.json`.
3. The NPC's `greeting` text is displayed in the DM panel via `NarrativeManager.add_narrative()`.
4. A set of hardcoded choices is presented (e.g., "Ask about rumors", "Buy a drink", "Leave").
5. Each choice triggers a hardcoded response via `NarrativeManager.add_narrative()`.

This provides a testable interaction loop before the orchestrator is wired up.

#### Phase 3+: Orchestrator API (Freeform LLM Conversation)

When the orchestrator is online, bump-to-interact sends an HTTP request:

```
POST /action
{
  "type": "speak",
  "target": "barkeep_marta",
  "text": ""
}
```

The orchestrator:
1. Loads the NPC profile from `npcs/barkeep_marta.json`.
2. Loads the NPC state file (interaction history, disposition).
3. Builds the LLM context prompt with NPC personality, knowledge, and conversation history.
4. Sends to the local LLM (Ollama).
5. Returns the response to Godot.

```
Response:
{
  "narration": "Marta sets down the mug she was polishing and leans across the bar. \"Well now, another brave soul walks through my door. What'll it be, love? Ale, information, or a room for the night?\"",
  "choices": [
    "I'll take an ale.",
    "What have you heard lately?",
    "I need a room."
  ],
  "state_delta": {
    "npcs": {
      "barkeep_marta": {
        "met_player": true,
        "disposition": 5
      }
    }
  }
}
```

Subsequent conversation turns use the free-text input in the DM panel:

```
POST /action
{
  "type": "speak",
  "target": "barkeep_marta",
  "text": "What do you know about the crypt beneath the town?"
}
```

### API Flow: NPC Conversation

```
Player bumps NPC          Godot                    Orchestrator           Ollama
      |                     |                           |                   |
      |--- WASD move ------>|                           |                   |
      |                     |-- POST /action ---------->|                   |
      |                     |   {type:"speak",          |                   |
      |                     |    target:"barkeep_marta"}|                   |
      |                     |                           |-- load profile -->|
      |                     |                           |-- load state ---->|
      |                     |                           |-- build prompt -->|
      |                     |                           |-- chat() -------->|
      |                     |                           |<-- dialogue ------|
      |                     |<-- {narration, choices} --|                   |
      |<-- DM panel text ---|                           |                   |
      |                     |                           |                   |
      |--- free-text ------>|                           |                   |
      |                     |-- POST /action ---------->|                   |
      |                     |   {type:"speak",          |                   |
      |                     |    target:"barkeep_marta",|                   |
      |                     |    text:"Tell me about..."}                   |
      |                     |                           |-- append history->|
      |                     |                           |-- chat() -------->|
      |                     |                           |<-- dialogue ------|
      |                     |<-- {narration, choices} --|                   |
      |<-- DM panel text ---|                           |                   |
```

### Interaction Zones (Non-NPC)

| Object | Interaction | Phase 2 Behavior |
|--------|-------------|------------------|
| Quest Board | Bump into it | Display placeholder text: "The quest board is empty. Check back later." |
| Shop Counter | Bump into it | Display placeholder text: "The shop is closed for now." |
| Memorial Wall | Bump into it | Display placeholder text: "Blank plaques line the wall, waiting for names." |
| Stairs Up | Walk onto tile | Display: "The rooms upstairs offer rest. (Long rest: restore HP and abilities.)" Trigger long rest if confirmed. |
| Entrance Door | Walk onto tile | Trigger scene transition to dungeon. |

---

## Visual Style

### Color Palette

Per GDD 03, the tavern uses warm tones to contrast with the cold dungeon palette:

| Element | Color | Hex |
|---------|-------|-----|
| Wood floor | Warm brown | `#8B6914` |
| Wood walls | Dark brown | `#5C3A1E` |
| Bar counter | Rich mahogany | `#6B3A2A` |
| Candlelight ambient | Amber | `#FFD280` |
| Ale/mug accents | Gold | `#DAA520` |
| Shadow areas | Warm dark | `#2A1A0E` |

### CanvasModulate

The tavern scene applies a `CanvasModulate` node with a warm amber tint to shift all tiles toward the tavern palette:

```
CanvasModulate.color = Color(1.0, 0.92, 0.78, 1.0)  # warm amber tint
```

This tints the existing dungeon tileset tiles to feel warmer without requiring a completely separate tileset.

### Lighting

- No fog of war in the tavern. All tiles are always visible (`god_mode = true` equivalent).
- No vision layer rendering.
- Ambient vignette shader (already exists at `assets/shaders/ambient_vignette.gdshader`) provides subtle edge darkening.
- Optional: flickering candlelight effect via `PointLight2D` nodes at candle positions with animated energy values.

### Dust Motes

The existing `DustMotes` particle system (used in dungeon rooms) is reused in the tavern with warmer color settings to simulate floating dust in candlelight.

---

## Scene Structure

### Godot Scene Tree

```
TavernScene (Node2D)
  +-- CanvasModulate (warm amber tint)
  +-- TileMapLayer "Floor" (wood plank tiles)
  +-- TileMapLayer "Walls" (tavern wall tiles)
  +-- TileMapLayer "Furniture" (tables, chairs, bar counter, shelves)
  +-- TileMapLayer "Decorations" (candles, mugs, barrels, memorial plaques)
  +-- NPCs (Node2D)
  |     +-- BarkeepMarta (Sprite2D @ grid 12,13)
  |     +-- PatronDurgan (Sprite2D @ grid 11,3)
  |     +-- PatronWhisper (Sprite2D @ grid 16,5)
  |     +-- PatronPippa (Sprite2D @ grid 14,5)
  +-- Player (existing player scene, placed at spawn point)
  +-- DustMotes (particle effects)
  +-- PointLight2D nodes (candle positions)
```

### Why Not Reuse `Map` + `MapRenderer`?

The existing `Map` class is designed for procedurally generated dungeon grids with FOV, monster placement, and area effects. The tavern needs none of this:

- No fog of war (always fully lit).
- No monsters or combat.
- Fixed layout (no generation).
- NPCs are not `Monster` instances.

Instead, the tavern is a standard Godot `TileMapLayer`-based scene. The player character reuses the same movement and input code but with tavern-specific collision and interaction logic. A thin `TavernMap` adapter class provides the grid-query interface (`is_walkable`, `get_npc_at`) that the player controller expects.

### TavernMap Adapter

```gdscript
class_name TavernMap
extends RefCounted

## Lightweight grid adapter for the tavern scene.
## Provides the same query interface the player controller uses
## without the full Map/MapCell/FOV machinery.

var width: int = 24
var height: int = 20
var _walkable: Array[Array] = []   # bool grid
var _npcs: Dictionary = {}         # Vector2i -> NPC profile data

func is_walkable(pos: Vector2i) -> bool:
    if not is_in_bounds(pos):
        return false
    if _npcs.has(pos):
        return false
    return _walkable[pos.x][pos.y]

func is_in_bounds(pos: Vector2i) -> bool:
    return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height

func get_npc_at(pos: Vector2i) -> Dictionary:
    return _npcs.get(pos, {})

func has_npc(pos: Vector2i) -> bool:
    return _npcs.has(pos)
```

---

## Game Flow

### First-Time Entry

```
Main Menu
  |
  +--> [New Game]
         |
         +--> Character Creation (race, class, abilities, name)
                |
                +--> DM Selection (archetype)
                       |
                       +--> Tavern Scene (player spawns at entrance door)
                              |
                              +--> Player explores tavern, talks to NPCs
                              |
                              +--> Player walks to entrance door / stairs down
                                     |
                                     +--> Dungeon Scene (Phase 1 game.tscn)
```

### Scene Transition: DM Selection to Tavern

Currently, `main_menu.gd` calls `get_tree().change_scene_to_file("res://scenes/game/game.tscn")` after DM selection. In Phase 2, this changes to:

```gdscript
func _on_archetype_selected(archetype_id: int) -> void:
    World.set_meta("player_character_data", _pending_character_data)
    World.set_meta("dm_archetype", archetype_id)
    _pending_character_data = null
    # Phase 2: go to tavern first, not directly to dungeon
    get_tree().change_scene_to_file("res://scenes/tavern/tavern.tscn")
```

The tavern scene's `_ready()` function:
1. Reads `World.get_meta("player_character_data")` to initialize the player character.
2. Reads `World.get_meta("dm_archetype")` to set the DM personality.
3. Places the player sprite at the entrance spawn point (22, 17).
4. Plays the entrance narration via `NarrativeManager`.

### Death to Tavern Return

When the player dies:

```
Death Screen ("YOU HAVE FALLEN")
  |
  +--> [New Adventure]
         |
         +--> Main Menu
                |
                +--> Character Creation (new character)
                       |
                       +--> DM Selection
                              |
                              +--> Tavern Scene (NPCs remember previous character)
```

The death screen's "New Adventure" button currently goes to `main_menu.tscn`. This does not change. The flow always passes through character creation and DM selection before reaching the tavern. Cross-death NPC memory is handled by persistent NPC state files (Phase 4).

### Tavern to Dungeon Transition

When the player steps onto the entrance door tile (22, 18) or a dedicated "descend" trigger:

1. A confirmation prompt appears in the DM panel: "Leave the safety of the tavern?"
2. On confirm, transition to `res://scenes/game/game.tscn` (the existing dungeon scene).
3. The dungeon scene reads the player character data from `World` metadata as it does today.

### Dungeon to Tavern Return (Non-Death)

If the player ascends past floor 1 (e.g., via stairs up on the first dungeon level), they return to the tavern. This transition loads `res://scenes/tavern/tavern.tscn` and places the player at the entrance.

---

## WASD Movement and Collision

The tavern reuses the same grid-based movement system from Phase 1 dungeon exploration:

- **Input:** WASD or arrow keys for cardinal movement, one tile per input.
- **Collision:** Query `TavernMap.is_walkable(target_pos)` before moving.
- **Bump-to-interact:** If the target tile has an NPC (`TavernMap.has_npc(target_pos)`), trigger conversation instead of movement.
- **Bump-to-examine:** If the target tile has an interactable object (quest board, shop counter, memorial wall), trigger examination text.
- **No combat:** Movement never triggers combat in the tavern. There are no hostile entities.
- **Turn system:** Movement in the tavern is real-time (not turn-based). The player moves freely without advancing a turn counter.

### Input Mode Differences

| Feature | Dungeon (Phase 1) | Tavern (Phase 2) |
|---------|-------------------|-------------------|
| Movement | Grid, turn-based | Grid, real-time |
| Bump NPC | Attack (if hostile) | Converse |
| Bump obstacle | Push/open/examine | Examine |
| FOV | Computed per move | Disabled (full visibility) |
| Combat | Yes | No |
| Turn counter | Advances per action | Does not advance |

---

## Deferred Features

The following features are referenced in the GDD but are NOT implemented in Phase 2:

| Feature | Deferred To | Phase 2 Placeholder |
|---------|-------------|---------------------|
| Quest board content | Phase 3 (Forge generates quests) | Static "board is empty" message |
| Memorial wall persistence | Phase 4 (cross-death state) | Decorative tiles only |
| Full shop economy | Phase 4+ | "Shop is closed" message |
| NPC schedules / patrol | Phase 4 (state machines) | NPCs fixed in place |
| NPC memory of previous characters | Phase 4 (persistent NPC state files) | No cross-death memory |
| Freeform LLM conversation | Phase 3 (orchestrator + Ollama) | Hardcoded greeting + choice menu |
| Room rental / long rest | Phase 2 (stretch goal) | Placeholder stairs interaction |
| Drinks / food purchase | Phase 4+ | Not implemented |
| Rotating patron cast | Phase 4+ | Fixed 3 patrons |

---

## Implementation Checklist

Phase 2 tavern implementation breaks down into these tasks:

1. **Tavern tileset** — Add tavern-specific tiles (wood floor, tavern walls, bar counter, furniture) to `world_tiles.tres` or create a separate tavern tileset.
2. **Tavern scene** — Build `res://scenes/tavern/tavern.tscn` with TileMapLayer-based layout matching the zone map above.
3. **TavernMap adapter** — Implement `TavernMap` class for walkability and NPC queries.
4. **NPC profile JSONs** — Create the 4 NPC profile files in `game/assets/data/npcs/`.
5. **NPC sprites** — Source or create 16x16 NPC sprites for Marta, Durgan, Whisper, Pippa.
6. **Tavern controller** — GDScript scene controller handling player movement, bump-to-interact, NPC dialogue display via NarrativeManager.
7. **Scene transitions** — Update `main_menu.gd` to route through tavern. Add tavern-to-dungeon and dungeon-to-tavern transitions.
8. **Visual treatment** — CanvasModulate warm tint, disable FOV, optional candlelight PointLight2D nodes.
9. **Hardcoded NPC dialogue** — Greeting + 2-3 choice branches per NPC, displayed in DM panel.
10. **Placeholder interactions** — Quest board, shop, memorial wall bump messages.
