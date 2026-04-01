# The Welcome Wench

A single-player 2D pixel art turn-based tactical RPG with a **dual-model AI Dungeon Master**.

A local LLM (Llama 3.2 3B) handles real-time DM duties -- narration, freeform NPC conversation, choices. Claude generates high-quality content on demand via Forge Mode -- dungeons, monsters, items, quest arcs. Godot 4 renders the world. Developed and played on Jetson Orin Nano.

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

## Tech Stack

| Component | Technology |
|-----------|-----------|
| **Client** | Godot 4.x, GDScript |
| **Backend** | Python 3.10+, FastAPI |
| **Local LLM** | Ollama, Llama 3.2 3B |
| **Cloud LLM** | Claude (via Claude Code CLI) |
| **Rules** | D&D 5e SRD (markdown) |
| **Hardware** | Jetson Orin Nano (8GB) |

## Technical Decisions

| Decision | Why |
|----------|-----|
| **Dual-model split** | Local LLM for latency-sensitive tasks (narration, dialogue). Cloud model for quality-sensitive generation (dungeons, quests). Cost and speed optimized. |
| **FastAPI orchestrator** | Decouples game client from AI backends. Either model can be swapped without touching the renderer. |
| **Edge hardware (Jetson Orin Nano)** | Proves the local LLM runs on constrained hardware -- not just a beefy dev machine. 8GB, real inference. |
| **Rules engine separation** | Game mechanics are deterministic and testable. AI handles narrative; math stays in code. |
| **Vertical slice development** | Each feature ships as a complete slice: implement, test, verify, document. Managed via Claude Code agents. |

## Development Phases

| Phase | Status | Focus |
|-------|--------|-------|
| 0. Research & Documentation | Done | Architecture design, tech validation |
| 1. Standalone Godot Game | Done | Playable game with hardcoded content, no AI |
| 2. Local LLM Integration | **In Progress** | Real-time DM narration, NPC dialogue |
| 3. Forge Mode | Planned | Cloud-generated dungeons, monsters, items |
| 4. Content Depth | Planned | Factions, permadeath, archetypes |
| 5. Polish | Planned | Full game flow, audio, MCP formalization |

## What This Project Demonstrates

- **Multi-model AI orchestration** -- routing requests to the right model based on latency vs. quality tradeoffs
- **Edge computing with LLMs** -- local inference on constrained hardware (Jetson Orin Nano, 8GB)
- **Clean separation of concerns** -- game engine, orchestrator, AI backends, and rules engine are fully decoupled
- **Human-in-the-loop design** -- player agency drives the AI, not the other way around
- **Agentic development workflow** -- built using Claude Code with structured task management

## Design Pillars

1. **The DM is real.** A local LLM improvises and reacts. Every NPC is a live conversational agent.
2. **Permadeath matters.** One life. The world remembers your dead characters.
3. **Emergent everything.** Quests, factions, NPCs -- generated, never scripted.
4. **Dark comedy.** Dangerous, absurd, and narrated with gallows humor.

## Project Structure

```
game/                  # Godot 4 project
orchestrator/          # Python/FastAPI DM orchestrator
forge/                 # Forge Mode working directory
forge_output/          # Claude-generated content
rules/                 # D&D 5e SRD markdown files (OGL)
specs/
  phase-1-core/        # Phase 1 build specs (complete)
  research/            # Architecture research docs
  reference/           # 24 GDD documents
scripts/               # Automated playtest and utility scripts
```
