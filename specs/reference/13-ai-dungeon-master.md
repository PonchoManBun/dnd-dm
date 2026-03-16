# 13 — AI Dungeon Master

## Role

The AI DM is not a feature — it **is** the game engine. But unlike the original design where a single Claude instance handled everything in real-time, the DM is now a **dual-model system**:

- **Local LLM (Ollama, Llama 3.2 3B):** Handles every player turn in real-time (~20-43 tok/s). Fast, cheap, always available.
- **Claude (via persistent CLI session):** On-demand "Forge Mode" for high-quality content generation. Player-action-triggered (10-60 sec, player waits). Expensive but excellent.

The **DM Orchestrator** (Python/FastAPI) coordinates both models and runs the deterministic rules engine.

## DM Archetypes

At game start, the player chooses a DM personality. Archetypes are implemented as **prompt templates** for the local LLM:

| Archetype | Style | Prompt Emphasis |
|-----------|-------|-----------------|
| **Classic Storyteller** | Balanced narrative and challenge | Default template |
| **Cruel Taskmaster** | Harder encounters, fewer drops, more ambushes | Emphasize danger, scarcity |
| **Whimsical Trickster** | Chaotic encounters, absurd NPCs, dark humor | Emphasize surprises, humor |
| **Grim Historian** | Lore-heavy, deep world-building | Emphasize history, description |
| **Merciful Guide** | Easier, more hints, generous loot | Emphasize help, encouragement |

The archetype prompt is prepended to every local LLM call. Claude Forge uses the same archetype context when generating content.

## The DM Response Cycle

This is the core game loop, now routed through the orchestrator:

```
Player Action (Godot)
       │
       ▼
DM Orchestrator (Python)
       │
       ├─── 1. Parse action type
       ├─── 2. Load relevant game state
       ├─── 3. Apply deterministic rules:
       │         - Dice rolls (d20, damage dice)
       │         - Combat math (attack vs AC, damage calc)
       │         - SRD rule lookups (conditions, spells)
       │         - Inventory changes, HP tracking
       ├─── 4. Send context + results to local LLM
       │         (rules outcome, game state, archetype prompt)
       │
       ▼
Local LLM (Ollama)
       │
       ├─── 5. Generate narration for the action
       ├─── 6. Generate contextual choices
       ├─── 7. (If applicable) Generate NPC dialogue
       │
       ▼
DM Orchestrator
       │
       ├─── 8. Validate LLM output, merge with rules results
       ├─── 9. Update game state JSON
       ├─── 10. Check escalation triggers (→ Forge if needed)
       │
       ▼
Response (Godot)
       │
       ├─── Narrative text in DM panel
       ├─── Game state updates (HP, position, inventory)
       ├─── Contextual choices
       └─── Animations / effects
```

### What's Deterministic vs What's AI

| System | Handler | Why |
|--------|---------|-----|
| Dice rolls | **Orchestrator** (Python `random`) | Must be fair, reproducible |
| Attack resolution (d20 + mod vs AC) | **Orchestrator** | Rules are unambiguous |
| Damage calculation | **Orchestrator** | Arithmetic, not creative |
| Condition effects (poisoned, prone) | **Orchestrator** | SRD lookup |
| Spell mechanics | **Orchestrator** | SRD lookup + dice |
| Narration / flavor text | **Local LLM** | Creative, contextual |
| NPC dialogue (freeform conversation) | **Local LLM** | Creative, personality-driven |
| Contextual choices | **Local LLM** | Requires game understanding |
| Room descriptions | **Local LLM** | Creative, thematic |
| Dungeon layouts | **Forge (Claude)** | Complex, needs quality |
| Monster design | **Forge (Claude)** | Needs D&D balance knowledge |
| Quest arcs | **Forge (Claude)** | Needs narrative coherence |
| Item creation | **Forge (Claude)** | Needs game balance |

## Escalation Rules: When Does the Orchestrator Call Forge?

The local LLM handles moment-to-moment gameplay. Forge Mode is triggered for heavyweight content generation:

| Trigger | What Forge Generates |
|---------|---------------------|
| Player enters a new dungeon floor | Dungeon layout, encounters, loot |
| Player reaches a major story beat | Quest arc continuation, NPC changes |
| New NPC needs full profile | Personality, dialogue style, behavior |
| Boss encounter preparation | Boss stats, lair actions, narrative |
| Player levels up (complex choices) | Class feature descriptions, options |
| World event (faction conflict escalates) | Faction state changes, consequences |

Forge is **player-action-triggered** — when the player takes an action that needs new content (e.g., descending stairs), the game shows a "Generating..." indicator while a persistent Claude Code CLI session produces the content. The orchestrator sends the request, waits for completion, then resumes gameplay with the new content loaded.

## DM Input Options

The player always sees:

- **Contextual choices** — Local LLM suggests actions appropriate to the situation
- **"Do something else..."** — Free-text input. Type anything. The DM will adjudicate it.

This is what makes TWW a D&D game, not a menu-driven RPG. The player can always try something creative. The local LLM evaluates free-text input and the orchestrator resolves the mechanics.

## Level-Up Narration

The local LLM narrates level-ups in character, using the DM archetype's voice. Forge provides the class feature descriptions and mechanical options. The orchestrator merges both into the level-up flow.

## Context Management

The local LLM has limited context (2048 tokens). The orchestrator manages what goes into each prompt:

1. **System prompt** — DM archetype + SRD rules summary (~300 tokens)
2. **Current state** — Player stats, location, active conditions (~200 tokens)
3. **Recent history** — Last 3-5 exchanges (~500-800 tokens)
4. **Action context** — Current action + dice results (~200 tokens)
5. **Remaining** — Available for LLM response (~500-800 tokens)

Important context that doesn't fit is summarized. The orchestrator compresses older conversation history into bullet-point summaries.
