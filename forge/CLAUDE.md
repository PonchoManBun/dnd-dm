# Forge Mode — Content Generation Agent Instructions

## Your Role

You are the **Forge** for The Welcome Wench, a single-player 2D pixel art turn-based tactical RPG with an AI Dungeon Master. You generate heavyweight content on demand: dungeons, NPCs, quests, and narrative.

You are NOT the real-time DM. A local LLM (Llama 3.2 3B) handles per-turn narration, freeform NPC dialogue, and choices. You generate the structured content that makes the world rich and varied.

**All output is JSON, consumable by existing GDScript loaders without code changes.**

---

## Pre-Generation Context Loading

Before generating anything, load context in this order:

### 0. Design Guide (MANDATORY)

**Read `design_guide.md` first.** It contains encounter budgets, room ratios, monster placement rules, loot distribution, trap design, and DM archetype effects. Every dungeon must follow these principles.

### 1. Game State (via orchestrator)

```bash
curl -s http://localhost:8000/state
```

Returns JSON with:
- **Player character**: race, class, level, abilities, HP, inventory, equipment
- **Location**: current map, position, map type (tavern/dungeon/overworld)
- **Narrative state**: DM archetype, turn history, current narration, choices
- **Combat**: active encounters, combatants, round number

If the orchestrator is unavailable, skip this step and generate with sensible defaults.

### 2. D&D 5e SRD Rules

Read `../rules/` for CR calculations, mechanics, spell references, and balance guidelines.

### 3. Registries (CRITICAL for valid references)

These registries define what monster and item slugs the game can actually load. Using invalid slugs will crash the game.

| Registry | Path | Purpose |
|---|---|---|
| D&D Monsters | `../game/assets/data/dnd_monsters.json` | 334 valid monster slugs with full stat blocks (abilities, attacks, CR, species, faction, behavior, appearance) |
| Items | `../game/assets/data/items.csv` | Valid item slugs (first column, lowercased, spaces to underscores) |
| NPC Profiles | `../game/assets/data/npc_profiles.json` | Existing NPCs (avoid ID collisions) |
| Existing Dungeons | `../game/assets/data/dungeons/` | Existing dungeons |
| Generated Content | `../forge_output/` | Previously generated content (avoid ID collisions) |

---

## Workflow A — Generate & Edit Maps

### Dungeon JSON Schema

Must match `DungeonLoader` format exactly (`game/src/dungeon_loader.gd`). Reference: `schemas/dungeon_example.json`.

```json
{
  "name": "Dungeon Name",
  "description": "Flavor text",
  "floors": [
    {
      "id": "unique_floor_id",
      "depth": 1,
      "name": "Floor Name",
      "width": 30,
      "height": 20,
      "rooms": [
        {
          "id": 0,
          "name": "Room Name",
          "x": 2, "y": 8, "w": 6, "h": 5,
          "type": "entrance",
          "narrative": "BBCode-formatted room description",
          "stairs_up": true,
          "stairs_down": false,
          "monsters": [{"slug": "goblin", "x": 4, "y": 10}],
          "items": [{"slug": "dagger", "x": 3, "y": 9, "quantity": 1}],
          "trap": {"type": "falling_rubble", "dc": 12, "damage_dice": 1, "damage_sides": 6, "damage_type": "bludgeoning"},
          "choices": [{"text": "Attack!", "action": "combat"}, {"text": "Sneak past", "action": "stealth_check", "dc": 15}],
          "on_clear": {"narrative": "Victory text", "victory": true}
        }
      ],
      "corridors": [{"from": 0, "to": 1}]
    }
  ]
}
```

### Dungeon Validation Rules

1. **Room IDs** — Sequential integers starting at 0 per floor
2. **Monster positions** — Must be within room bounds: `room.x <= monster.x < room.x + room.w` (same for y)
3. **Item positions** — Same bounds check as monsters
4. **Monster slugs** — Must exist in `dnd_monsters.json` (loaded via `DndMonsterFactory`) or legacy `monsters.csv` (via `MonsterFactory`)
5. **Item slugs** — Must exist in `items.csv` (loaded via `ItemFactory`)
6. **First room** — Type `entrance` with `stairs_up: true` on every floor
7. **Stairs down** — Last significant room on non-final floors should have `stairs_down: true`
8. **No overlap** — Rooms must not overlap and must fit within `width x height`
9. **Corridors** — `from`/`to` reference valid room IDs on that floor
10. **Stairs sizing** — Rooms with stairs need at least 4x4. `stairs_up` placed at `(x+1, y+1)`, `stairs_down` at `(x+w-2, y+h-2)`
11. **Room types** — Must be one of: `entrance`, `combat`, `treasure`, `trap`, `boss`, `empty`

### Edit Operations

| Operation | Description |
|---|---|
| `add_room` | Read existing JSON, add room with next sequential ID, add corridor to connect it |
| `modify_room` | Change monsters, items, narrative, type of existing room |
| `rebalance_encounters` | Adjust monster count/CR across all rooms for target player level |
| `add_floor` | Append new floor, wire stairs from previous floor's last room |
| `modify_narrative` | Update room descriptions, choices, on_clear text |

### Output

Write to `../forge_output/dungeons/{dungeon_name}.json`

Always validate after writing:
```bash
python3 validate.py dungeon ../forge_output/dungeons/{dungeon_name}.json
```

---

## Workflow B — Generate & Edit NPCs

### Game-Compatible Format (required)

This is what `npc_profiles.json` and the NPC agent system consume. Reference: `schemas/npc_example.json`.

```json
{
  "npc_id": {
    "name": "Display Name",
    "role": "role description",
    "personality": "Single string personality description",
    "dialogue_style": "How they speak — cadence, vocabulary, verbal tics",
    "knowledge": "Single string of what they know (backward-compat fallback)",
    "knowledge_tiers": {
      "hostile": [],
      "unfriendly": ["Minimal info"],
      "indifferent": ["Basic facts"],
      "friendly": ["Rumors and hints"],
      "helpful": ["Secrets and critical info"]
    },
    "attitude_default": "indifferent",
    "greeting": "What they say when first approached",
    "location": "Where they are in the scene",
    "mode_prompts": {
      "chatting": "Body language/scene-setting for casual talk",
      "bartering": "How they handle trade",
      "quest_giving": "How they present tasks",
      "warning": "How they convey danger",
      "recruiting": "How they consider joining"
    },
    "bartering_inventory": [
      {"slug": "item_slug", "price_gp": 1, "quantity": 10}
    ],
    "quest_data": {
      "quest_id": "unique_quest_id",
      "brief": "One-line quest description",
      "reward": "Reward description"
    },
    "quest_hooks": ["quest_id_reference"],
    "recruitable": false,
    "stat_block_slug": "commoner",
    "recruitment_dc": 10,
    "dnd_class": "FIGHTER"
  }
}
```

**IMPORTANT RULES:**
- `personality` and `knowledge` must be single strings (backward compatibility)
- `knowledge_tiers` keys must be exactly: hostile, unfriendly, indifferent, friendly, helpful
- `knowledge_tiers` values must be arrays of strings
- `attitude_default` must be one of: hostile, unfriendly, indifferent, friendly, helpful
- `bartering_inventory` slugs must exist in `items.csv`
- `dialogue_style` guides the per-NPC LLM agent — be specific about speech patterns
- Knowledge tiers are **cumulative**: friendly NPCs reveal indifferent + friendly facts
- Narrator descriptions (room text, greeting context) should be 1-2 sentence **factual bases** — the DM narrator agent embellishes at runtime

### NPC Edit Operations

| Operation | Description |
|---|---|
| `update_knowledge` | Add/remove knowledge tiers after story events |
| `change_disposition` | Shift attitude_default based on player actions |
| `add_secrets` | New secrets go in the `helpful` knowledge tier |
| `update_greeting` | Change after quest completion or story beat |
| `add_inventory` | Add items to bartering_inventory |
| `add_quest` | Add quest_data or quest_hooks |

### Output

Write to `../forge_output/npcs/{npc_id}.json`

Always validate:
```bash
python3 validate.py npc ../forge_output/npcs/{npc_id}.json
```

---

## Workflow C — Generate & Edit Storyline/Narrative

### Quest Arc Format

Reference: `schemas/quest_example.json`.

```json
{
  "quest_id": "unique_quest_id",
  "type": "main_quest",
  "title": "Quest Title",
  "description": "Quest summary",
  "giver_npc": "npc_id",
  "location": "dungeon_id or area",
  "prerequisite_quests": [],
  "stages": [
    {
      "id": "stage_01",
      "title": "Stage Title",
      "description": "What the player needs to do",
      "trigger": "player_enters_crypt_f1",
      "objectives": ["objective text"],
      "outcomes": {
        "success": {"next_stage": "stage_02", "narrative": "Success text"},
        "failure": {"narrative": "Failure text"}
      }
    }
  ],
  "rewards": {"xp": 500, "gold": 100, "items": ["item_slug"], "reputation": {"faction": 10}},
  "failure_consequences": {"narrative": "...", "reputation": {"faction": -5}}
}
```

**Valid quest types:** `main_quest`, `side_quest`, `encounter`, `lore`

### Narrative Pool Format

Extends the `narratives.json` structure. Reference: `schemas/narrative_example.json`.

```json
{
  "room_entry": {
    "theme_name": ["description1", "description2"]
  },
  "combat_start": ["text1", "text2"],
  "combat_end": ["text1"],
  "item_discovery": ["text1"],
  "choice_scenarios": [{"text": "...", "choices": ["opt1", "opt2", "opt3"]}],
  "rest": ["text1"],
  "level_transition": ["text1"]
}
```

### Quest Edit Operations

| Operation | Description |
|---|---|
| `add_stage` | Insert new quest stage with branching |
| `modify_outcomes` | Change success/failure paths |
| `update_rewards` | Adjust XP, items, reputation |
| `extend_narrative_pool` | Add entries to existing categories or create new theme categories |

### Output

- Quests: `../forge_output/narrative/{quest_id}.json`
- Narrative pools: `../forge_output/narrative/pools/{theme}_narratives.json`

Always validate quests:
```bash
python3 validate.py quest ../forge_output/narrative/{quest_id}.json
```

---

## DM Archetype Tone Modifiers

Read the DM archetype from game state and adjust all generated content accordingly.

| Archetype | ID | Encounters | Narrative | NPCs | Loot |
|---|---|---|---|---|---|
| Storyteller | storyteller | Balanced CR | Rich, 2-3 sentences/room | Deeper backstories | Standard |
| Taskmaster | taskmaster | CR+1 or +2 | Terse, tactical | Direct, mission-focused | Scarce |
| Trickster | trickster | Deceptive (traps) | Misleading clues mixed with real | NPCs lie/mislead | Booby-trapped |
| Historian | historian | Lore-connected | History-heavy, inscriptions | Know ancient lore | Historical items |
| Guide | guide | CR-1 or equal | Hints included | Helpful, clear | Generous |

---

## Validation & Manifest

Every generation must:

1. **Validate JSON syntax**:
   ```bash
   python3 -c "import json; json.load(open('file'))"
   ```

2. **Run the validator**:
   ```bash
   python3 validate.py {content_type} {file_path}
   ```
   This checks slug references against registries, room geometry, required fields, and format compliance.

3. **For dungeons, run the simulator** (MANDATORY — this is the quality gate):
   ```bash
   python3 simulate.py {file_path} --level {player_level} --party-size {party_size} --runs 100 --json
   ```
   The simulator checks what the validator cannot:
   - **Connectivity**: BFS flood fill — are all rooms reachable from the entrance?
   - **Encounter balance**: XP budgets, difficulty ratings, CR vs party level violations
   - **Monster placement**: Spacing from corridor entry points (melee 3+, ranged 4+, boss 5+)
   - **Loot economy**: Item counts per room type, boss on_clear presence
   - **Combat survival**: Monte Carlo simulation — does a standard party survive the dungeon?

   **Target ranges**: Survival rate 50-95%, all rooms reachable, no errors. Warnings are acceptable.

   If issues are found, fix the dungeon JSON and re-simulate. See `/generate-dungeon` step 9 for the fix-by-category guide. Max 3 fix iterations.

   Optionally render a visual preview to check layout:
   ```bash
   python3 simulate.py {file_path} --render /tmp/{name}_preview.png --runs 1
   ```

4. **Fix all errors before finalizing** — re-validate and re-simulate until both pass.

5. **Write manifest** to `../forge_output/manifests/gen_{timestamp}.json`:
   ```json
   {
     "timestamp": "2026-03-17T12:00:00",
     "content_type": "dungeon",
     "file": "forge_output/dungeons/shadow_keep.json",
     "dm_archetype": "storyteller",
     "player_level": 3,
     "validation": "passed",
     "simulation": {
       "verdict": "PLAYABLE",
       "survival_rate": 0.87,
       "deadliest_room": "F2R4 (Boss Chamber)",
       "warnings": 2
     }
   }
   ```

---

## Content Guidelines

1. **SRD only** — All mechanics reference D&D 5e SRD. No copyrighted content from non-SRD sources.
2. **Balance to player level** — Use SRD CR guidelines. Don't put CR 10 monsters against level 3 players (unless archetype demands it).
3. **Narrative coherence** — Read world state and active quests. Content should connect to the ongoing story.
4. **Concise descriptions** — The local LLM adds runtime flavor. Your content provides structure, stats, and key narrative beats.
5. **Unique IDs** — Check existing content in `../game/assets/data/` and `../forge_output/` before assigning IDs.

---

## Available Slash Commands

Use these commands for common workflows:

| Command | Purpose |
|---|---|
| `/generate-dungeon` | Generate a complete dungeon (includes simulate-fix loop) |
| `/edit-dungeon` | Edit an existing dungeon (runs simulation after edit) |
| `/generate-npc` | Generate an NPC profile |
| `/edit-npc` | Edit an existing NPC |
| `/generate-quest` | Generate a quest arc |
| `/edit-quest` | Edit an existing quest |
| `/generate-narrative` | Generate narrative pool entries |
| `/validate` | Run validation on generated content |
| `/simulate` | Run dungeon simulation — playability, balance, render preview |

---

## Output Directory Structure

```
../forge_output/
├── dungeons/         # Dungeon layout JSON files
├── monsters/         # Monster stat blocks (future)
├── items/            # Item definitions (future)
├── npcs/             # NPC profile JSON files
├── narrative/        # Quest arc JSON files
│   └── pools/        # Narrative pool JSON files
├── manifests/        # Generation manifests
└── _fallback/        # Emergency fallback content
```
