# 13 — AI Dungeon Master

## Role

The AI DM is not a feature — it **is** the game engine. The DM is a **dual-model system**:

- **Local LLM (Ollama, Llama 3.2 3B):** Handles every player turn in real-time (~20-43 tok/s). Fast, cheap, always available.
- **Claude (via persistent CLI session):** On-demand "Forge Mode" for high-quality content generation. Player-action-triggered (10-60 sec, player waits). Expensive but excellent.

The **DM Orchestrator** (Python/FastAPI) coordinates both models and runs the deterministic rules engine.

## DM Archetypes

At game start, the player chooses a DM personality via the **DMSelection** screen (`dm_selection.gd`). Five archetypes are available, each with its own selection UI entry and prompt template:

| Archetype | Style | Prompt Template File |
|-----------|-------|---------------------|
| **The Storyteller** | Rich narrative, character-focused encounters, dramatic moments | `orchestrator/prompts/storyteller.txt` |
| **The Taskmaster** | Tactical challenges, smart enemies, high stakes | `orchestrator/prompts/taskmaster.txt` |
| **The Trickster** | Surprises, traps, hidden secrets, misdirection | `orchestrator/prompts/trickster.txt` |
| **The Historian** | Deep lore, environmental storytelling, knowledge rewards | `orchestrator/prompts/historian.txt` |
| **The Guide** | Helpful hints, clear explanations, newcomer-friendly | `orchestrator/prompts/guide.txt` |

### Selection UI

The `DMSelection` class (`game/scenes/menu/dm_selection.gd`) builds the selection screen programmatically with:
- Left panel: 5 archetype buttons with icon and name
- Right panel: Selected archetype description (flavor text + gameplay effect)
- Navigation: Back (returns to character creation) and Confirm buttons
- The selected archetype ID is stored via `World.set_meta("dm_archetype", archetype_id)`

### Prompt Templates

Each archetype has a `.txt` template in `orchestrator/prompts/`. The template is loaded by `prompt_builder.py` via `load_archetype_prompt()` and includes a `{max_response_tokens}` placeholder that gets filled with the computed response budget. The archetype prompt is prepended as the system message in every local LLM call.

## The DM Response Cycle

The core game loop is routed through the orchestrator (`orchestrator/routes/action.py`):

```
Player Action (Godot)
       |
       v
DM Orchestrator (POST /action)
       |
       +--- 1. Parse action type (ActionType enum)
       +--- 2. Load current game state (in-memory GameState)
       +--- 3. Apply deterministic rules:
       |         - Attack rolls (resolve_attack with d20 + mod vs AC)
       |         - Damage rolls (weapon dice + modifier, crit doubles dice)
       |         - Spell resolution (resolve_spell with slot consumption)
       |         - Rest mechanics (short rest: hit dice, long rest: full restore)
       |         - Movement resolution
       +--- 4. Build prompt (prompt_builder.build_dm_prompt)
       |         - System prompt: archetype template
       |         - User prompt: state summary + history + NPC context + action
       |
       v
Local LLM (Ollama chat API)
       |
       +--- 5. Generate narration + choices
       |         (parsed via NARRATION:/CHOICES: format)
       |
       v
DM Orchestrator
       |
       +--- 6. Parse LLM output (parse_llm_response)
       +--- 7. Update game state (narrative history, turn number)
       +--- 8. Fallback to template narration if LLM unavailable
       |
       v
Response (DmResponse JSON to Godot)
       +--- narration: DM text
       +--- choices: contextual action options
       +--- state_delta: HP changes, custom data
       +--- combat_log: mechanical results
       +--- error/fallback flags
```

### Template Fallback

When the LLM is unavailable (connection error, timeout, model not found), the orchestrator falls back to `template_fallback.py` which generates basic narration and choices from templates. This ensures the game remains playable without Ollama running.

### What's Deterministic vs What's AI

| System | Handler | Why |
|--------|---------|-----|
| Dice rolls | **Orchestrator** (Python dice module) | Must be fair, reproducible |
| Attack resolution (d20 + mod vs AC) | **Orchestrator** (rules engine) | Rules are unambiguous |
| Damage calculation | **Orchestrator** | Arithmetic, not creative |
| Condition effects (poisoned, prone) | **GDScript RulesEngine** (client-side) | SRD lookup, speed modifiers |
| Spell mechanics | **Orchestrator** (spells module) | SRD lookup + dice + slot tracking |
| Rest mechanics | **Orchestrator** | Hit dice, HP restore, slot restore |
| Narration / flavor text | **Local LLM** | Creative, contextual |
| NPC dialogue (freeform conversation) | **Local LLM** | Creative, personality-driven |
| Contextual choices | **Local LLM** | Requires game understanding |
| Dungeon layouts | **Forge (Claude)** | Complex, needs quality |
| Monster design | **Forge (Claude)** | Needs D&D balance knowledge |
| Quest arcs | **Forge (Claude)** | Needs narrative coherence |
| Item creation | **Forge (Claude)** | Needs game balance |

## Forge Mode

Forge Mode uses a persistent Claude Code CLI session with `/clear` + `forge/CLAUDE.md` for context. The `forge/` directory contains its own `CLAUDE.md` with content generation instructions.

### Forge Output

The `forge_output/` directory exists with the following structure:
```
forge_output/
+-- dungeons/      # Generated dungeon layouts (JSON)
+-- monsters/      # Monster stat blocks
+-- items/         # Item definitions
+-- npcs/          # NPC profiles
+-- narrative/     # Quest arcs, room descriptions
+-- manifests/     # Generation tracking
+-- _fallback/     # Fallback content
```

### Forge Integration Status

Forge triggers are **not yet wired into live gameplay**. The forge directory has tools and the output directory structure exists, but the orchestrator does not currently call Forge during game sessions. The `/forge/trigger` endpoint mentioned in early designs is **not implemented**. Content generation via Forge is currently done manually outside of gameplay sessions.

**Planned:** Orchestrator escalation logic that detects triggers (new dungeon floor, boss encounter, level-up) and invokes Forge to generate content while showing a "Generating..." indicator.

## DM Input Options

The player always sees:

- **Contextual choices** — LLM-generated or template-based action options, presented as numbered buttons in the DM panel
- **Free-text input** — A "Say something..." text field at the bottom of the DM panel for freeform input

## Context Management

The local LLM has a 2048 token context window. Context management is handled by two modules:

### prompt_builder.py

Assembles the complete prompt from components:

1. **System prompt** — Archetype template with response budget (~300 tokens)
2. **State summary** — Player name, level, race, class, HP, AC, conditions, location (~200 tokens)
3. **NPC context** — NPC name, role, personality, knowledge (when in conversation)
4. **History** — Recent exchanges, compressed via context_manager
5. **Action context** — Current action type, target, direction, dice results

Token budget: `CONTEXT_WINDOW (2048) - SYSTEM_PROMPT_BUDGET (300) - RESPONSE_BUDGET (600)` = ~1148 tokens for state + history + action + NPC context.

### context_manager.py

Manages conversation history within the token budget:

- **Sliding window:** Keeps the 5 most recent exchanges (`MAX_RECENT_EXCHANGES`)
- **Compression:** Exchanges older than 3 turns (`COMPRESS_AFTER`) are compressed to bullet-point summaries (first sentence of response + truncated action)
- **Trimming:** If still over budget after compression, oldest compressed exchanges are dropped
- **Token estimation:** ~4 characters per token approximation

### NPC Context (npc_context.py)

NPC profiles are managed by the `npc_context` module:

- Default profiles for 3 tavern NPCs: Barkeep Marta, Old Tom, Elara the Quiet
- Each profile includes: name, role, personality, knowledge
- Profiles can be loaded from a JSON file or fall back to hardcoded defaults
- When the player speaks to an NPC, the profile is included in the LLM prompt

## Level-Up Narration

**Not yet implemented.** Level tracking exists in `CharacterData` with XP thresholds and class feature tables, but there is no automated level-up narration flow.
