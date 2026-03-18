# The Welcome Wench — Phase Context

## Project

**The Welcome Wench** (TWW) is a single-player 2D pixel art turn-based tactical RPG with an AI Dungeon Master. A **local LLM** (Llama 3.2 3B on Ollama) handles real-time DM duties — narration, combat text, freeform NPC conversation, contextual choices. **Claude** (via a persistent CLI session) generates high-quality content on demand in "Forge Mode" — dungeon maps, monsters, items, quest arcs. **Godot 4** renders the world. A **Python/FastAPI orchestrator** coordinates everything with a deterministic D&D 5e rules engine.

**Platform:** Jetson Orin Nano (8GB) — development and play. See `specs/research/dev-workflow.md`.

## Current Phase: Phase 2 — Local LLM Integration

**Goal:** Connect the Godot client to the Python/FastAPI orchestrator and Ollama LLM for real-time DM narration, NPC dialogue, and contextual choices. The game currently runs with hardcoded content — Phase 2 replaces that with live LLM responses.

### Phase 1 Objectives (All Complete)
1. ~~Fork and adapt statico/godot-roguelike-example base game~~
2. ~~Adapt D20 combat to D&D 5e SRD rules~~
3. ~~Add DM panel UI (narrative text, choices, free-text input)~~
4. ~~Hardcoded test dungeon with hand-authored content~~
5. ~~Basic character creation flow (race, class, ability scores)~~
6. ~~Save/load system~~
7. ~~Hybrid combat model (roguelike exploration + tactical D&D 5e combat)~~
8. ~~BG3-style party/companion system (up to 3 companions + player character)~~
9. ~~NPC recruitment — any NPC anywhere can be recruited via conversation~~
10. ~~Companion stat block to character sheet conversion~~
11. ~~Companion XP tracking (separate per character)~~
12. ~~Party-aware combat (player controls all party members)~~
13. ~~Dialogue UI with speaker selection dropdown~~
14. ~~Encounter balance for party of 4 (standard D&D 5e XP budgets)~~

All HIGH and MEDIUM criteria met. 3 LOW items (companion AI, dismissal, quest hooks) deferred to Phase 2.

### Phase 2 Objectives
15. Godot HTTP client connecting to orchestrator API
16. Real-time DM narration via Ollama (room entry, combat, exploration)
17. Freeform NPC conversation via LLM (replace hardcoded narratives)
18. Contextual choice generation (DM offers situational choices)
19. Combat narration (LLM describes hits, misses, kills, spells)
20. Memory/context management (orchestrator tracks conversation history)
21. Tavern hub scene (rest, recruit, shop, quest board — LLM-powered)

### Phase 2 is done when:
- Godot client communicates with orchestrator via HTTP
- Room entry triggers LLM narration (not hardcoded text)
- Player can have freeform conversation with any NPC via LLM
- DM panel shows LLM-generated choices based on context
- Combat has LLM narration for key events
- Orchestrator maintains conversation context across turns
- Tavern scene works as a hub with LLM-powered NPCs

### Additional Infrastructure Done
- **Forge Mode** is set up: validated schemas, forge/CLAUDE.md, validation script, schema reference files, prompt templates, 8 slash commands, design guide
- **Automated playtest system** exists: monitor.sh, playtest.sh, playtest_brain.py, the-player agent with two-tier workflow

## Tech Stack

- **Client:** Godot 4.x + GDScript (fork of statico/godot-roguelike-example)
- **Orchestrator:** Python 3.10+ + FastAPI
- **Real-time DM:** Ollama + Llama 3.2 3B (Q4_K_M)
- **Forge (on-demand):** Claude Code CLI (persistent session with /clear + forge/CLAUDE.md)
- **Rules:** D&D 5e SRD (markdown files in `rules/`)
- **Platform:** Jetson Orin Nano (8GB) — development and play

## Architecture Principles

1. **Client = dumb renderer.** Godot reads game state JSON and draws pixels. No dice, no combat, no narrative.
2. **Orchestrator = the brain.** Routes between LLM, Forge, and rules engine. Maintains all state.
3. **Local LLM = fast DM.** Handles every turn. Narration, freeform NPC dialogue, choices. ~20-43 tok/s.
4. **Forge (Claude) = quality content.** On-demand generation via persistent CLI session. 10-60 sec, player waits.
5. **State contract = JSON.** All layers communicate via JSON.
6. **Deterministic rules stay deterministic.** Dice, combat math, conditions — Python, not LLM.

## Combat Model

- **Exploration:** Roguelike turns — grid movement, bump-to-interact
- **Combat:** Tactical D&D 5e mode — movement + action + bonus action + reaction, positioning, terrain, flanking

## NPC Model

Every NPC is a **freeform conversational agent** powered by the local LLM. No menu trees, no canned dialogue. Players can negotiate, bluff, ask directions, or say anything. This is a core differentiator.

## Development Principles

1. **Prove risky things first.** The three-layer architecture on 8GB is the biggest risk. Validate before content investment.
2. **Vertical slices.** Each phase delivers a playable slice — not a layer of infrastructure.
3. **Keep it simple.** Avoid over-engineering. Start with direct invocation, formalize later.
4. **Tests at integration points.** Test orchestrator API, LLM routing, forge pipeline. Don't test LLM output quality or pixel rendering.
5. **Iterate on specs.** Phase specs are written when that phase begins. Research informs everything.

## Development Workflow

Claude Code is the developer. Work is managed through phases, tasks, and agents:

1. **Start of phase:** Read this file for context, `@fix_plan.md` for the task list, and `specs/phase-N-*/` for specs.
2. **Work through tasks** in priority order (HIGH -> MEDIUM -> LOW). Each task is a vertical slice — implement, test, verify, mark done.
3. **Use agents** for parallel work where tasks are independent (e.g., research in one agent, coding in another).
4. **Track progress** by checking off tasks in `@fix_plan.md` as they complete.
5. **Phase complete** when all HIGH and MEDIUM tasks are done. Update `@fix_plan.md`, advance phase references in this file and `CLAUDE.md`.

## Current Tasks

See `@fix_plan.md` for the prioritized task list.

## Specs

See `specs/phase-1-core/` for current phase specifications:
- `overview.md` — Design pillars, core loop, platform
- `architecture.md` — Three-layer topology, state contract
- `dm-integration.md` — Dual-model DM, response cycle
- `dm-orchestrator.md` — Orchestrator design, rules engine
- `forge-mode.md` — Claude on-demand content generation via persistent CLI session

See `specs/research/` for research documents:
- `legal-claude-usage.md` — ToS/legal findings
- `base-game-evaluation.md` — Godot 4 base game candidates
- `godot-file-formats.md` — File format AI editability
- `jetson-setup.md` — Hardware/software setup
- `mcp-forge-design.md` — MCP/Forge architecture options
- `dev-workflow.md` — Jetson development workflow

See `specs/reference/` for the full 24-document GDD archive.
