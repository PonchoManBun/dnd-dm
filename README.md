# The Welcome Wench

A single-player 2D pixel art turn-based tactical RPG with a **dual-model AI Dungeon Master**.

A local LLM (Llama 3.2 3B) handles real-time DM duties — narration, freeform NPC conversation, choices. Claude generates high-quality content on demand via Forge Mode — dungeons, monsters, items, quest arcs. Godot 4 renders the world. Developed on Windows 11 laptop, deployed on Jetson Orin Nano.

## Tech Stack

- **Client:** Godot 4.x + GDScript (base: statico/godot-roguelike-example)
- **Orchestrator:** Python 3.10+ + FastAPI
- **Real-time DM:** Ollama + Llama 3.2 3B
- **Forge:** Claude Code CLI (persistent session)
- **Rules:** D&D 5e SRD (markdown)
- **Development:** Windows 11 laptop
- **Deployment:** Jetson Orin Nano (8GB)

## Development Phases

| Phase | Name | Goal |
|-------|------|------|
| **0** | Research & Documentation | Validate architecture, write specs (DONE) |
| **1** | Standalone Godot Game | Playable game with hardcoded content, no AI |
| **2** | Local LLM Integration | Real-time DM narration and NPC dialogue |
| **3** | Forge Mode | Claude generates content on demand |
| **4** | Content Depth | Factions, permadeath, archetypes |
| **5** | Polish | Full game flow, audio, MCP formalization |

**Current phase:** Phase 1

## Development Workflow

**Claude Code is the developer.** Each phase is built using Claude Code CLI with agents and tasks:

1. Read `PROMPT.md` for current phase context and `@fix_plan.md` for the task list
2. Break the phase into tasks, work through them in priority order (HIGH → MEDIUM → LOW)
3. Use agents for parallel work (e.g., research + coding simultaneously)
4. Each task = a vertical slice: implement → test → verify → mark done
5. Update `@fix_plan.md` as tasks complete
6. When all tasks are done, advance to the next phase

## Project Structure

```
PROMPT.md              # Current phase context and principles
@fix_plan.md           # Prioritized task list for current phase
@AGENT.md              # Build/run/test commands
CLAUDE.md              # Project instructions for Claude Code
specs/
  phase-1-core/        # Phase 1 design specs (active)
  phase-2-tavern/      # Phase 2 placeholder
  phase-3-combat/      # Phase 3 placeholder
  phase-4-dungeon/     # Phase 4 placeholder
  phase-5-world/       # Phase 5 placeholder
  phase-6-polish/      # Phase 6 placeholder
  research/            # Research documents
  reference/           # Original 20 GDD documents
rules/                 # D&D 5e SRD markdown files
forge/                 # Forge Mode working directory
```

## Architecture

```
[Godot 4 Client] ──HTTP──► [DM Orchestrator] ──► [Ollama/LLM]
                                              ──► [Forge/Claude]
```

- **Client** = dumb renderer (reads JSON, draws pixels)
- **Orchestrator** = the brain (routes LLM, Forge, rules engine)
- **Local LLM** = fast DM (narration, NPC dialogue, choices)
- **Forge (Claude)** = quality content (dungeons, monsters, quests)
- **Rules engine** = deterministic (dice, combat math, SRD)

## Design Pillars

1. **The DM is real.** A local LLM improvises and reacts. Every NPC is a live conversational agent.
2. **Permadeath matters.** One life. The world remembers your dead characters.
3. **Emergent everything.** Quests, factions, NPCs — generated, never scripted.
4. **Dark comedy.** Dangerous, absurd, and narrated with gallows humor.

## Specs

Full game design is documented across 20 GDD files in `specs/reference/`. Phase-specific build specs are in `specs/phase-N-*/`. Research documents in `specs/research/`.
