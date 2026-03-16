# Base Game Evaluation: Open-Source Godot 4 Dungeon Crawlers

## Search Criteria

- Godot 4.x (not Godot 3)
- 2D top-down tilemap-based (pixel art preferred)
- MIT or permissive license
- Basic movement and/or combat
- Dungeon crawler, roguelike, or RPG genre

---

## Top Recommendation: statico/godot-roguelike-example

| Field | Value |
|-------|-------|
| **URL** | https://github.com/statico/godot-roguelike-example |
| **License** | MIT |
| **Stars** | 11 |
| **Last pushed** | 2026-01-29 |
| **Godot version** | **4.6** (GL Compatibility renderer) |
| **Language** | GDScript (pure, no C#) |
| **Demo** | https://roguelike.statico.io |

### Existing Features
- Turn-based roguelike with grid movement (8-directional WASD+QEZC + mouse click-to-move)
- **D20-based combat system** with attack rolls, AC, damage types, resistances
- BSP dungeon generation with configurable room/corridor params
- Full inventory with drag-and-drop UI, equipment slots (armor, melee, ranged, accessories)
- Monster AI using custom **behavior tree** system (aggressive, fearful, curious, passive)
- Faction system for monster relationships
- Field of view via shadowcasting + fog of war
- Nutrition system, status effects with duration/magnitude
- Throwable items with AoE, ranged combat distinct from melee
- Data-driven: monsters and items defined in **CSV files**
- Dawnlike 16x16 pixel art tileset
- Debug tools: map generator preview, sprite explorer, item explorer

### Missing Features
- No scrolls, wands, rings, amulets
- No shops/economy
- No quests/objectives
- No save/load

### Why This Is the Top Pick
- **Already uses D20 mechanics** (attack rolls, AC, strength bonuses) -- maps directly to D&D 5e
- Code is **exceptionally well-structured**: one `.gd` file per concern (`combat.gd`, `monster_ai.gd`, `equipment.gd`, `dice.gd`, etc.)
- Strictly typed GDScript with `class_name` declarations and gdtoolkit linting
- Action pattern: every game event is an `Action` object with `ActionEffect` for rendering
- Scenes are minimal `.tscn` files -- logic lives in `.gd` scripts (very Claude-friendly)
- **README mentions use with Claude Code/Cursor** for editing
- CSV data files mean Claude can modify game content without touching scene files
- No external addon dependencies -- fully self-contained

---

## Candidate 2: stesproject/godot-2d-topdown-template

| Field | Value |
|-------|-------|
| **URL** | https://github.com/stesproject/godot-2d-topdown-template |
| **License** | MIT |
| **Stars** | 142 |
| **Last pushed** | 2026-02-18 |
| **Godot version** | **4.6** (requires 4.4+) |
| **Demo** | https://alchemy-pot.web.app/files/godot-2d-topdown-template/play |

### Existing Features
- Real-time action top-down movement (run, jump, attack, dodge)
- Health controller with optional health bars
- Interaction system (chests, switches, doors)
- Inventory management, save/load, state machines
- Dialogue system (Dialogue Manager addon by nathanhoad)
- Tilemap-based levels, scene transitions
- User preferences and localization support
- Props: chests, doors, gates, keys, potions, traps

### Assessment
Well-organized component-based architecture. Data-driven items via `.tres` resources. Would need conversion from real-time to turn-based combat. Depends on Dialogue Manager addon. Best fit if targeting a **Zelda-like action RPG** rather than traditional roguelike.

---

## Candidate 3: gdquest-demos/godot-open-rpg

| Field | Value |
|-------|-------|
| **URL** | https://github.com/gdquest-demos/godot-open-rpg |
| **License** | MIT |
| **Stars** | **2,621** |
| **Last pushed** | 2026-03-08 |
| **Godot version** | **4.5** |

### Existing Features
- **Turn-based JRPG-style combat** with battler stats, actions, AI
- Grid-based field movement, combat UI (menus, life bars, damage labels)
- Area transitions, cutscene triggers, inventory, dialogue (Dialogic addon)
- Music player, screen transitions

### Assessment
By GDQuest (well-known Godot educators). Professionally structured. Turn-based combat is closest to D&D style. However, follows JRPG conventions (party-based, side-view battle screen) not top-down dungeon combat. Heavy Dialogic addon dependency. Multiple autoloads create coupling.

---

## Candidate 4: ForlornU/TopdownStarter

| Field | Value |
|-------|-------|
| **URL** | https://github.com/ForlornU/TopdownStarter |
| **License** | MIT |
| **Stars** | 106 |
| **Last pushed** | 2024-08-24 |
| **Godot version** | **4.3** |

### Assessment
Clean, minimal starting point with FSM-based player/enemy, NPC dialogue, quest tracker. Good for learning patterns but too lightweight for a production base -- would need most systems built from scratch.

---

## Reference: SelinaDev/Godot-Roguelike-Tutorial

| Field | Value |
|-------|-------|
| **URL** | https://github.com/SelinaDev/Godot-Roguelike-Tutorial |
| **License** | MIT |
| **Stars** | 171 |
| **Godot version** | 4.1+ |

A 13-part tutorial series. Good for learning roguelike patterns but not a cohesive moddable game base.

---

## Summary Ranking

| Rank | Repo | Best For | Godot | Active? |
|------|------|----------|-------|---------|
| **1** | **statico/godot-roguelike-example** | D&D dungeon crawler (D20 combat, inventory, dungeon gen, behavior trees, data-driven) | 4.6 | Yes |
| **2** | stesproject/godot-2d-topdown-template | Polished action-RPG template with save/load, dialogue, inventory | 4.6 | Yes |
| **3** | gdquest-demos/godot-open-rpg | Turn-based JRPG combat reference. Most popular. Heavy dependencies | 4.5 | Yes |
| **4** | ForlornU/TopdownStarter | Minimal FSM reference. Lightweight | 4.3 | No |

## Decision

**statico/godot-roguelike-example** is the recommended base. It already uses D20 mechanics, has data-driven content via CSV, behavior tree AI, BSP dungeon generation, and is designed for AI-assisted editing. The D20 combat, equipment slots, and faction system map almost directly to D&D 5e concepts.
