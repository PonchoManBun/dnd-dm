# The Welcome Wench — Godot 4 Game Client

Single-player 2D pixel art turn-based tactical RPG with a dual-model AI Dungeon Master. This directory contains the Godot 4 client — the renderer and UI layer.

## Run

```bash
# Run the game
godot --path game/

# Open in Godot editor
godot --path game/ -e

# Headless validation
godot --path game/ --headless --quit
```

## Directory Structure

```
src/               # GDScript source (one file per concern)
  actions/         # Turn actions (move, attack, ranged, use item, etc.)
  map_generators/  # BSP dungeon generation, arena, dungeon loader
scenes/            # Godot scenes (.tscn)
  actor/           # Player and monster scenes
  character_creation/  # 4-step character creation flow
  game/            # Main game scene
  menu/            # Main menu, death screen
  tavern/          # Tavern hub (Phase 2+)
  ui/              # HUD, DM panel, inventory, initiative tracker, modals
  debug/           # Map generator tool, sprite/item explorers
  fx/              # Visual effects
assets/
  data/            # Game data files (see below)
  fonts/           # Pixel Operator font family
  generated/       # Tileset sprite sheets (from art pipeline)
  icons/           # UI icons
  textures/        # FX textures, shaders, particles
  shaders/         # Visual shaders (vignette, FOW)
art/               # Tileset source + gen_*.py pipeline scripts
  DawnLike/        # Dawnlike tileset source
  IndoorRPG/       # Indoor tileset source
```

## Key Systems

- **D&D 5e Combat** — SRD action economy (movement + action + bonus + reaction), D20 attack rolls, damage types, conditions
- **Party System** — BG3-style companions, up to 3 recruitable NPCs, shared inventory, individual equipment
- **Dungeon Loader** — JSON-defined dungeons with rooms, corridors, encounters, loot, stairs, triggers
- **Character Creation** — Race, class, ability scores (4d6 drop lowest), name — produces valid 5e character sheet
- **Save/Load** — JSON game state, continuous auto-save, roguelike anti-scumming (delete on death/resume)
- **DM Panel** — Right-side narrative display, choice buttons, free-text input, speaker selection
- **Initiative Tracker** — D&D 5e initiative order UI for tactical combat mode
- **Fog of War** — Shadowcasting FOV with seen-but-not-visible tiles
- **SRD Reference** — In-game toggleable rules overlay (? key)

## Data Files

```
assets/data/
  dnd_monsters.json    # 334 SRD monster stat blocks (from 5e-database, MIT)
  items.csv            # D&D 5e items with weight, damage, properties
  classes.json         # 6 playable classes (Fighter, Rogue, Wizard, Cleric, Ranger, Barbarian)
  races.json           # 6 playable races (Human, Elf, Dwarf, Halfling, Half-Orc, Tiefling)
  narratives.json      # Hardcoded DM narrative content (placeholder for Phase 2 LLM)
  npc_profiles.json    # NPC personality profiles for dialogue
  monsters.csv         # Legacy base game monsters (unused, kept for reference)
  dungeons/
    test_crypt.json    # 3-floor test dungeon (Crypt of the Fallen)
```

## Art Pipeline

Tileset sprites are generated from source images in `art/` using Python scripts:

```bash
cd art/
pip install -r requirements.txt
python3 gen_characters.py   # Character sprites
python3 gen_items.py        # Item sprites
python3 gen_world.py        # World/terrain tiles
python3 gen_indoor.py       # Indoor tiles
python3 gen_ui.py           # UI elements
```

Then run the corresponding `gen_*_tileset.gd` scripts from within Godot to build `.tres` resources.

## Attribution

Originally forked from [statico/godot-roguelike-example](https://github.com/statico/godot-roguelike-example) (MIT). Substantially rewritten for D&D 5e mechanics, party system, dungeon loading, and AI DM integration.

## Licenses

- **Source code:** MIT (see LICENSE)
- **Dawnlike tileset:** [DawnBringer](https://opengameart.org/content/16x16-dawnhack-roguelike-tileset) — see tileset license
- **Pixel Operator font:** [CC0](https://creativecommons.org/publicdomain/zero/1.0/)
