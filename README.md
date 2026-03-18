# The Welcome Wench

A single-player 2D pixel art turn-based tactical RPG with a **dual-model AI Dungeon Master**.

A local LLM (Llama 3.2 3B) handles real-time DM duties — narration, freeform NPC conversation, choices. Claude generates high-quality content on demand via Forge Mode — dungeons, monsters, items, quest arcs. Godot 4 renders the world. Developed and played on Jetson Orin Nano.

## Tech Stack

- **Client:** Godot 4.x + GDScript (base: statico/godot-roguelike-example)
- **Orchestrator:** Python 3.10+ + FastAPI
- **Real-time DM:** Ollama + Llama 3.2 3B
- **Forge:** Claude Code CLI (persistent session)
- **Rules:** D&D 5e SRD (markdown)
- **Platform:** Jetson Orin Nano (8GB) — development and play

## Development Phases

| Phase | Name | Goal |
|-------|------|------|
| **0** | Research & Documentation | Validate architecture, write specs (DONE) |
| **1** | Standalone Godot Game | Playable game with hardcoded content, no AI (DONE — extension complete) |
| **2** | Local LLM Integration | Real-time DM narration and NPC dialogue |
| **3** | Forge Mode | Claude generates content on demand |
| **4** | Content Depth | Factions, permadeath, archetypes |
| **5** | Polish | Full game flow, audio, MCP formalization |

**Current phase:** Phase 2 (Local LLM Integration)

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
  phase-1-core/        # Phase 1 design specs (complete)
  phase-2-tavern/      # Future phase placeholders
  phase-3-combat/      #   (specs written when phase begins)
  phase-4-dungeon/
  phase-5-world/
  phase-6-polish/
  research/            # Research documents (legal, base game, Jetson, dev workflow)
  reference/           # 24 GDD documents (game design reference)
rules/                 # D&D 5e SRD markdown files (17 files, OGL)
forge/                 # Forge Mode working directory (has its own CLAUDE.md)
game/                  # Godot 4 project (active)
orchestrator/          # Python/FastAPI DM orchestrator
forge_output/          # Claude-generated content (tracked)
scripts/               # Automated playtest and utility scripts
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

Full game design is documented across 24 GDD files in `specs/reference/`. Phase-specific build specs are in `specs/phase-N-*/`. Research documents in `specs/research/`.
