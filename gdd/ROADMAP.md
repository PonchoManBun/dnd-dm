# The Welcome Wench — Roadmap

## Phase 0: Experiments

Phase 0 is about proving core mechanics before committing to full implementation. Each experiment answers a specific question and produces a working prototype.

### Experiment 1: Tile Layer Stack
**Question:** Can we render 10 TileMapLayers at 60 FPS on Jetson with the current DawnLike tilesets?

**Tasks:**
- Extend `village_renderer.gd` from 6 to 10 layers
- Add SubWall, Roofing, Items, Vision layers
- Render a test village with all layers populated
- Profile on Jetson: FPS, draw calls, memory

**Success:** 60 FPS with all 10 layers active on Jetson.

### Experiment 2: Block Placement Prototype
**Question:** Does the block placement UX feel good? Is ghost cursor + validation responsive enough?

**Tasks:**
- Implement Build Mode toggle (B key)
- Block palette UI with category tabs
- Ghost cursor with valid/invalid highlighting
- Place/remove blocks with material tracking
- Undo/redo stack

**Success:** Player can build a simple house (walls, floor, door, furniture) in under 2 minutes.

### Experiment 3: AI Map Generation
**Question:** Can the AI DM (Forge Mode) generate village layouts and dungeon maps that render correctly?

**Tasks:**
- Define map generation prompt format (JSON output)
- Forge generates a village layout with buildings, paths, NPCs
- Validate output against block/layer schema
- Render generated map in Godot

**Success:** Forge-generated map loads and renders without manual fixes.

### Experiment 4: Farming Cycle
**Question:** Does the till → plant → water → grow → harvest loop feel satisfying in 2D?

**Tasks:**
- Implement ground tilling (hoe on grass)
- Crop planting and growth stages (4 visual stages)
- Watering mechanic (manual + irrigation)
- Harvest interaction
- Day advancement triggers growth

**Success:** Player can plant, grow, and harvest a turnip crop across 4 in-game days.

### Experiment 5: Roof Visibility
**Question:** Does the indoor/outdoor roof toggle work intuitively? Is flood-fill performant?

**Tasks:**
- Implement roof tile placement on layer 8
- Flood-fill connected roof region detection
- Toggle roof visibility when player enters/exits buildings
- Profile flood-fill on Jetson

**Success:** Walking through a door seamlessly shows/hides the roof. <1ms per toggle.

### Experiment 6: NPC Schedules
**Question:** Can NPCs follow daily schedules with LLM-powered freeform conversation?

**Tasks:**
- Define NPC schedule format (JSON: time → location → activity)
- NPC pathfinding on village grid
- Bump-to-talk triggers LLM conversation with personality context
- Test with 3–5 NPCs running schedules simultaneously

**Success:** NPCs visibly move through their daily routine. Conversation feels natural and contextual.

### Experiment 7: Seasonal Visuals
**Question:** Can we swap tile palettes per season without performance cost?

**Tasks:**
- Create season-variant tilesets (or shader-based palette swap)
- Ground tiles change: green (spring) → golden (summer) → orange (autumn) → white (winter)
- Tree Objects change sprites per season
- Test transition between seasons

**Success:** Season change is visually distinct and transitions smoothly.

## Milestones

Broad progression from experiments to playable game:

### M1: Foundation (Post-Experiments)
- 10-layer rendering works on Jetson
- Build mode functional with 20+ block types
- Farming loop complete (till → harvest)
- Roof visibility working
- Save/load with delta serialization

### M2: Living Village
- 10+ NPCs with schedules and freeform conversation
- Seasonal cycle (4 seasons, crop calendars, weather)
- Economy basics (materials, gold, trading)
- Player home with storage
- Village grows as player builds

### M3: Expedition Loop
- World map with 3+ regions
- Dungeon generation (Forge-powered)
- Full expedition flow (prepare → explore → fight → return)
- Soft death implemented
- Loot and material rewards

### M4: Content & Polish
- All 6 world regions accessible
- 50+ block types, 10+ crops, 20+ items
- NPC gift system and affinity
- Companion recruitment from village NPCs
- Festivals and seasonal events
- DM narration covers all modes

### M5: Playable Release
- Full game loop: farm → build → explore → fight → return
- 10+ hours of content
- Balance pass on economy, combat, progression
- Jetson-optimized, stable 60 FPS
- Save system robust

## Legacy Migration

### Carries Forward (Keep)
| Component | Current Location | Status |
|-----------|-----------------|--------|
| Python/FastAPI orchestrator | `orchestrator/` | Extend with building/farming/season logic |
| D&D 5e rules engine | `orchestrator/` | Keep unchanged for combat |
| Combat system (GDScript) | `game/src/` | Keep — combat mode is a pillar |
| Party/companion system | `game/src/` | Keep — companions are core |
| DM Panel UI | `game/src/` | Keep — adapt for all modes |
| Tile rendering pipeline | `game/src/` | Extend from 6 to 10 layers |
| Character creation | `game/src/` | Keep unchanged |
| Forge Mode infrastructure | `forge/` | Keep — content generation is core |
| DawnLike tilesets | `game/assets/generated/` | Keep — extend with new tiles |

### Gets Replaced
| Component | Why |
|-----------|-----|
| Permadeath system | Replaced by soft death (see PRD.md) |
| Dungeon-only gameplay | Village life is now the primary loop |
| Tavern as static hub | Replaced by player-built village with living NPCs |
| Node-based overworld travel | Replaced by explorable world regions |
| Full-map save serialization | Replaced by delta-only village persistence |

### Gets Extended
| Component | From → To |
|-----------|-----------|
| Village renderer | 6 layers → 10 layers with building support |
| MapCell | Terrain + obstacle → adds block, crop, roof data |
| Terrain types | Dungeon-only → adds overworld types (grass, dirt, water, sand) |
| NPC system | Basic conversation → schedules, affinity, gifts, recruitment |
| Save system | Full serialization → delta village + expedition separation |
| DM narration | Dungeon/combat only → all modes (village, building, farming, social) |

### Legacy Reference
The 24 GDD documents in `specs/reference/` remain as historical reference. They informed this redesign but are no longer the active design spec. This `gdd/` folder replaces them as the source of truth.
