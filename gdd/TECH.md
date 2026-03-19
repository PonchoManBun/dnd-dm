# The Welcome Wench — Technical Design

## Architecture

Three-layer design, adapted for building/farming/social systems:

```
┌─────────────────────────────────────────────┐
│  Godot 4 Client (Dumb Renderer)             │
│  - Renders tile layers, sprites, UI         │
│  - Handles input → sends actions to orch    │
│  - No game logic, no dice, no state mgmt    │
└──────────────────┬──────────────────────────┘
                   │ HTTP/JSON
┌──────────────────▼──────────────────────────┐
│  Python/FastAPI Orchestrator (Brain)         │
│  - Game state (village, NPCs, inventory)    │
│  - D&D 5e rules engine (combat, skills)     │
│  - Farming/building/season simulation       │
│  - Routes to LLM layer                      │
└──────────┬──────────────────┬───────────────┘
           │                  │
┌──────────▼──────┐  ┌───────▼───────────────┐
│  Ollama (Fast)  │  │  Claude Forge (Quality)│
│  Llama 3.2 3B   │  │  Persistent CLI session│
│  Narration, NPC │  │  Dungeons, quests,     │
│  dialogue,      │  │  items, story arcs     │
│  choices        │  │  (player waits)        │
└─────────────────┘  └───────────────────────┘
```

**Key change from legacy:** The orchestrator now manages village state (buildings, crops, NPC schedules, seasons) in addition to dungeon/combat state. The client gains Build Mode input handling but remains a dumb renderer — it sends "place block at (x, y)" and the orchestrator validates and updates state.

## Tile Layer Stack

10 TileMapLayers in Godot, bottom to top:

| # | Layer | TileSet | Purpose | Player Editable |
|---|-------|---------|---------|-----------------|
| 1 | Ground | world_tiles | Grass, dirt, water, sand, tilled soil | Till / dig |
| 2 | Floor | world_tiles | Wood planks, stone tiles, carpet | Place / remove |
| 3 | SubWall | world_tiles | Foundations, half-walls | Auto-generated |
| 4 | Walls | world_tiles | Full walls, fences, doors, windows | Place / remove |
| 5 | Furniture | world_tiles | Tables, chairs, crafting stations, chests | Place / remove |
| 6 | Decoration | indoor_tiles | Shelves, beds, rugs, wall hangings | Place / remove |
| 7 | Objects | outdoor_tiles | Trees, rocks, crops, ore veins, bushes | Harvest / plant |
| 8 | Roofing | world_tiles | Roof tiles (hidden when player is inside) | Place / remove |
| 9 | Items | item_sprites | Dropped items on the ground | Pickup / drop |
| 10 | Vision | world_tiles | FOV overlay, darkness, fog of war | Auto (engine) |

**Current state:** `village_renderer.gd` has 6 layers (Ground, Floor, Walls, Furniture, Decoration, Objects). Extending to 10 means adding SubWall, Roofing, Items, and Vision layers.

## Block System

Every placeable element is a **BlockData** — a data-driven definition loaded from JSON:

```json
{
  "id": "wall_wood",
  "name": "Wooden Wall",
  "category": "walls",
  "layer": 4,
  "tile_name": "wall-4-nsew",
  "walkable": false,
  "sight_blocking": true,
  "hp": 20,
  "recipe": { "wood": 4 },
  "harvest_yields": { "wood": 2 },
  "placement_rules": ["on_empty", "adjacent_to_floor"],
  "tags": ["flammable", "basic"]
}
```

**BlockData fields:**

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique identifier |
| `name` | string | Display name |
| `category` | string | Palette tab: ground, floors, walls, furniture, decoration, objects |
| `layer` | int | Which TileMapLayer (1–10) |
| `tile_name` | string | Atlas tile reference in the TileSet |
| `walkable` | bool | Can entities walk through this block |
| `sight_blocking` | bool | Does this block fog of war / line of sight |
| `hp` | int | Durability (0 = indestructible ground) |
| `recipe` | dict | Materials consumed to place: `{ material: count }` |
| `harvest_yields` | dict | Materials returned when removed/harvested |
| `placement_rules` | array | Where this can be placed (see Building Mechanics) |
| `tags` | array | Behavioral tags: flammable, waterproof, luxury, etc. |

All block data lives in `game/assets/data/blocks.json`. The orchestrator validates placement; the client just renders.

## Building Mechanics

### Build Mode Activation
- Press **B** to enter Build Mode. Press **B** or **Escape** to exit.
- Client sends `enter_build_mode` to orchestrator. Orchestrator confirms and sends block palette data.

### Ghost Cursor
- In Build Mode, a translucent preview of the selected block follows the mouse cursor.
- Client highlights valid placement cells in green, invalid in red.
- Validity is determined by the orchestrator (client requests `can_place(block_id, x, y)`).

### Placement Rules

| Rule | Meaning |
|------|---------|
| `on_empty` | Target cell's layer must be empty |
| `on_ground` | Must have ground tile below (layer 1) |
| `on_floor` | Must have floor tile below (layer 2) |
| `adjacent_to_wall` | Must be next to a wall (layer 4) |
| `adjacent_to_floor` | Must be next to a floor tile |
| `outdoor_only` | Cannot be inside a roofed area |
| `indoor_only` | Must be inside a roofed area |

### Construction Flow
1. Player selects block from palette
2. Player clicks target cell
3. Client sends `place_block(block_id, x, y)` to orchestrator
4. Orchestrator checks: placement rules, material availability, collision
5. If valid: deduct materials, update state, respond with new cell data
6. Client renders the new block

### Removal Flow
1. Player right-clicks a placed block
2. Client sends `remove_block(x, y, layer)` to orchestrator
3. Orchestrator checks: is this player-placed? Is removal allowed?
4. If valid: return partial materials (harvest_yields), update state
5. Client removes the tile

## Indoor/Outdoor Roofing

Roof visibility is determined by **connected roof region detection**:

1. When a roof tile is placed/removed, flood-fill from the player's position
2. If the player is inside a fully enclosed roof region → hide roofing tiles in that region (show interior)
3. If the player is outside → show all roofing tiles (buildings appear as rooftops)
4. "Enclosed" = all edges of the roof region touch walls (layer 4) or more roof

**Performance:** Flood-fill on a 60×40 grid completes in <1ms. Re-run only when player crosses an indoor/outdoor boundary (door interaction). Well within Jetson budget.

**Implementation:** The orchestrator tracks roof regions as connected components. On player movement, check if the player's cell has a roof tile above it. If the roof-state changed (entered/exited building), send a `roof_visibility` update to the client with the list of cells to show/hide.

## Farming

### Crop Lifecycle

```
Bare Ground → [Till] → Tilled Soil → [Plant + Seed] → Planted
→ [Water + Days] → Sprout → Growing → Mature → [Harvest] → Yield + Bare Ground
```

### Mechanics

| Action | Input | Effect |
|--------|-------|--------|
| Till | Hoe on grass (layer 1) | Changes ground to tilled soil |
| Plant | Seed item on tilled soil | Creates crop on Objects layer (layer 7) |
| Water | Watering can on crop | Sets `watered` flag for the day |
| Harvest | Interact with mature crop | Yields items, clears crop |

### Growth
- Each crop has a `growth_days` value (e.g., turnips = 4, wheat = 8, pumpkin = 13)
- Crops advance one growth stage per day if watered
- Unwatered crops don't grow (but don't die unless drought > 3 days)
- Each growth stage has a visual sprite (seed, sprout, half-grown, mature)

### Irrigation
- Crops within 3 tiles of a water source are auto-watered
- Player can build irrigation channels (floor-layer blocks) to extend water reach
- Rain auto-waters all outdoor crops

### Season Lock
- Each crop has valid seasons. Planting out-of-season fails (DM warns)
- Crops still growing when season changes wither (lose harvest)
- Greenhouse building allows any-season growth (expensive to build)

### Data Format
Crop definitions in `game/assets/data/crops.json`:

```json
{
  "id": "turnip",
  "name": "Turnip",
  "seasons": ["spring"],
  "growth_days": 4,
  "seed_cost": 10,
  "sell_price": 35,
  "harvest_yield": { "turnip": 1 },
  "sprites": ["crop-seed", "crop-sprout", "crop-half", "crop-turnip-mature"],
  "water_needed": true,
  "regrows": false
}
```

## Resource Gathering

### Harvestable Obstacles
Objects layer (layer 7) contains natural resources that can be harvested:

| Resource | Tool | Yields | Regrowth |
|----------|------|--------|----------|
| Oak Tree | Axe | 4-6 wood, 0-1 acorn | 7 days |
| Pine Tree | Axe | 3-5 wood, 0-1 pinecone | 7 days |
| Rock | Pickaxe | 2-4 stone | Never (finite) |
| Iron Ore | Pickaxe | 1-3 iron ore | Never |
| Crystal Node | Pickaxe | 1-2 crystal | Never |
| Berry Bush | Hand | 2-3 berries | 3 days |
| Herb Patch | Hand | 1-2 herbs | 5 days |

### Tool Progression
- **Basic** (wood + stone): Slow, low yield
- **Iron**: Faster, better yield
- **Steel**: Fast, best yield, can harvest crystal

### Regrowth
Renewable resources (trees, bushes, herbs) regrow after a set number of days. The orchestrator tracks regrowth timers per cell. Non-renewable resources (rocks, ore) are finite — expeditions are needed to find more.

## Save Format

### Design Principles
- Only **player-modified cells** are serialized (delta from base map)
- Village state **survives death** — never wiped
- Expedition state is **temporary** — lost on death or return

### Structure

```json
{
  "version": 2,
  "player": { "name": "...", "level": 5, "xp": 1200, "class": "fighter" },
  "village": {
    "modified_cells": [
      { "x": 12, "y": 8, "layer": 4, "block_id": "wall_wood" },
      { "x": 12, "y": 8, "layer": 2, "block_id": "floor_wood" }
    ],
    "crops": [
      { "x": 5, "y": 10, "crop_id": "turnip", "growth_day": 3, "watered": true }
    ],
    "storage": { "wood": 45, "stone": 20, "iron": 8, "gold": 150 },
    "season": "spring",
    "day": 14,
    "year": 1
  },
  "npcs": [
    { "id": "blacksmith_thorin", "affinity": 65, "location": [10, 5], "state": "working" }
  ],
  "quests": [ ... ],
  "expedition": null
}
```

**Typical size:** ~40KB for a well-developed village. Compact because only deltas are stored — the base map (grass, trees, water) is regenerated from the map template.

## Existing Code to Extend

These files carry forward from the current codebase and need modification:

| File | Current | Change Needed |
|------|---------|---------------|
| `village_renderer.gd` | 6 TileMapLayers | Extend to 10 layers (add SubWall, Roofing, Items, Vision) |
| `map_cell.gd` | Terrain + Obstacle + Monster | Add block_id, crop_data, roof fields |
| `terrain.gd` | Dungeon-only enum (DUNGEON_WALL, etc.) | Add overworld types (GRASS, DIRT, WATER, SAND, TILLED_SOIL) |
| `game_state_serializer.gd` | Full map serialization | Delta-only village persistence, separate expedition state |

Code that carries forward unchanged: combat system, D&D 5e rules engine, character sheets, party system, companion management, DM panel UI (adapted), orchestrator API structure.

## Jetson Performance Budget

Target: 60 FPS on Jetson Orin Nano (8GB shared CPU/GPU memory).

| Component | Memory | CPU | Notes |
|-----------|--------|-----|-------|
| 10 TileMapLayers (60×40) | ~10 draw calls | Negligible | Godot batches same-tileset layers |
| Cell data (60×40 grid) | ~96 KB | — | 2400 cells × ~40 bytes each |
| Block definitions | ~50 KB | — | ~200 block types in JSON |
| Crop state | ~10 KB | — | ~100 active crops max |
| NPC schedules | ~20 KB | — | ~20 NPCs with daily schedules |
| LLM inference | ~2 GB | 1 core | Ollama with Llama 3.2 3B Q4_K_M |
| Godot engine | ~200 MB | — | Base engine + assets |
| **Total** | **~2.4 GB** | — | Well within 8 GB budget |

Roof flood-fill: <1ms per run. Crop growth tick: <1ms per day advance. Building validation: <1ms per placement check.

## AI Art Pipeline

Workflow for getting AI-generated art into the game:

1. **Generate** — Use AI image generation (Gemini, DALL-E, Midjourney) to create concept art, tile sprites, character art
2. **Process** — Resize to 16×16 pixel grid, reduce palette to match DawnLike style, clean up artifacts
3. **Integrate** — Add to appropriate tileset PNG (world_tiles, indoor_tiles, outdoor_tiles, item_sprites)
4. **Register** — Update tileset JSON with new tile names and atlas coordinates
5. **Reference** — Add block/crop/item definitions pointing to new tiles
6. **Test** — Render in Godot, verify on Jetson

Store raw AI output in `gdd/ref/` for reference. Processed game-ready sprites go in `game/assets/generated/`.

### Tileset Structure (Current)
- `world_tiles.png` — Terrain, floors, walls (DawnLike-based)
- `indoor_tiles.png` — Interior furniture, decorations
- `outdoor_tiles.png` — Trees, rocks, outdoor objects
- `item_sprites.png` — Inventory items, drops
- `character_tiles.png` — Player, NPCs, monsters
