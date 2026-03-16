# Forge Mode — Claude Content Generation System

## What Forge Mode Is

Forge Mode is the player-action-triggered content generation system where Claude (via a persistent Claude Code CLI session) creates high-quality game content on demand. When the player takes an action that requires new content, the game pauses with a "Generating..." indicator while Claude produces it. The game resumes once the content is ready.

## When Forge Fires

The DM Orchestrator detects forge triggers based on player actions:

| Trigger | What Gets Generated | Priority |
|---------|-------------------|----------|
| Player enters new dungeon floor | Level layout, encounters, loot | High |
| Player reaches major story beat | Quest continuation, NPC changes | High |
| New significant NPC needed | Full profile, dialogue style, behavior | Medium |
| Boss encounter approaching | Boss stats, lair actions, narrative | High |
| Player levels up | Class feature descriptions, options | Medium |
| Faction conflict escalates | Arc progression, consequences | Low |
| Loot drop needs unique item | Item with backstory, stats | Low |

## How Forge Works

```
1. Player takes an action that needs new content (e.g., descend stairs)
2. Orchestrator detects forge trigger
3. Game shows "Generating..." indicator (player waits)
4. Orchestrator sends command to persistent Claude Code CLI session:
   a. CLI does /clear to reset conversation context
   b. CLI re-reads forge/CLAUDE.md (forge-specific instructions)
   c. Orchestrator sends the generation prompt (content type, game state, SRD context)
   d. Claude generates content, writes files to forge_output/
5. Orchestrator loads new content into game state
6. Game resumes with new content
```

## Forge CLI Session Model

The Forge runs as a **persistent interactive Claude Code CLI session** on the Jetson, not as a subprocess or Agent SDK call.

### Why persistent CLI?
- `/clear` gives a clean context for each generation (no stale conversation bleeding in)
- After `/clear`, Claude re-reads `forge/CLAUDE.md` which contains generation instructions, output format specs, and game state references
- The CLI session stays warm — no process spawn overhead between forge calls
- Full Claude Code capabilities: file read/write/edit, bash commands, structured output

### Session lifecycle
1. **Startup:** Orchestrator launches `claude` in the `forge/` subdirectory at game boot
2. **Per-request:** Orchestrator pipes a prompt to CLI stdin (or writes a prompt file)
3. **Reset:** `/clear` before each generation ensures fresh context
4. **CLAUDE.md:** The `forge/CLAUDE.md` file is automatically loaded after `/clear`, providing generation instructions
5. **Output:** Claude writes generated files to `forge_output/` subdirectories

### Communication
The orchestrator communicates with the CLI session by:
- Writing a prompt file and instructing Claude to read it, OR
- Piping the prompt directly to CLI stdin
- Claude writes output files to `forge_output/` — the orchestrator watches for completion

## Forge CLAUDE.md

The `forge/CLAUDE.md` file is the instruction set Claude reads after every `/clear`. It contains:

- **Role definition** — "You are generating game content for The Welcome Wench"
- **Output directory** — Write all generated content to `forge_output/`
- **Output format specs** — JSON schemas for each content type
- **Game state reference** — Read current state from `game_state/` JSON files
- **D&D 5e SRD reference** — Read rules from `rules/` markdown files
- **Content templates** — Structure for each content type (dungeon, monster, item, NPC, narrative)
- **Validation rules** — Required fields, value ranges, balance guidelines
- **DM archetype context** — Match generated content to the active DM personality

See `forge/CLAUDE.md` for the full instruction set.

## Output Formats by Content Type

### Dungeon Layout
```json
{
  "floor_id": "crypt_level_2",
  "theme": "crypt",
  "width": 32, "height": 32,
  "tiles": [[1,1,1,0,0,...], ...],
  "rooms": [
    {"id": "room_1", "x": 5, "y": 3, "w": 8, "h": 6, "type": "entrance"},
    {"id": "room_2", "x": 18, "y": 10, "w": 10, "h": 8, "type": "boss"}
  ],
  "corridors": [
    {"from": "room_1", "to": "room_2", "tiles": [[6,9],[7,9],...]}
  ],
  "encounters": [
    {"room": "room_1", "monsters": ["skeleton", "skeleton"], "cr": 0.5},
    {"room": "room_2", "monsters": ["shadow_drake"], "cr": 5}
  ],
  "loot": [
    {"room": "room_1", "items": ["potion_healing"]},
    {"room": "room_2", "items": ["flame_tongue_sword"]}
  ]
}
```

### Monster Stats
```json
{
  "name": "Shadow Drake",
  "type": "dragon",
  "cr": 5,
  "hp": 68, "ac": 15,
  "speed": {"walk": 30, "fly": 60},
  "abilities": {"str": 16, "dex": 14, "con": 14, "int": 8, "wis": 12, "cha": 10},
  "attacks": [
    {"name": "Bite", "bonus": 6, "damage": "2d6+3", "type": "piercing"},
    {"name": "Shadow Breath", "recharge": "5-6", "save": {"type": "dex", "dc": 14},
     "damage": "4d6", "damage_type": "necrotic", "area": "30ft cone"}
  ],
  "traits": ["Darkvision 120ft", "Shadow Stealth"],
  "loot_table": ["dragon_scale", "shadow_gem"]
}
```

### Items, NPCs, Narrative
Similar JSON structures — see `specs/research/mcp-forge-design.md` for full tool schemas.

## Cost Control

- Use Claude Sonnet for routine content, Opus for complex quests
- Prompt caching for SRD rules (90% cost reduction)
- `/clear` between requests prevents context bloat and unnecessary token usage
- Track costs per forge call in orchestrator logs
- The persistent CLI session avoids repeated startup costs

## Fallback: Offline Content

If Claude API is unavailable (network down, rate limited, budget exhausted):
- Orchestrator falls back to pre-generated content pools
- Local LLM generates simpler content (basic room descriptions, simple encounters)
- Game remains playable, just with less variety

## File System Layout

```
/forge/
├── CLAUDE.md           # Forge-specific instructions (read after /clear)
└── prompt_templates/   # Reusable prompt templates by content type

/forge_output/
├── dungeons/           # Generated level layouts
│   └── crypt_level_2.json
├── monsters/           # Monster stat blocks
│   └── shadow_drake.json
├── items/              # Item definitions
│   └── flame_tongue_sword.json
├── npcs/               # NPC profiles
│   └── tomb_guardian.json
└── narrative/          # Quest arcs, room descriptions
    └── crypt_quest_act_2.json
```
