# The Welcome Wench — Development Context

## Project

**The Welcome Wench** (TWW) is a single-player 2D pixel art turn-based tactical RPG with an AI Dungeon Master. A **local LLM** (Llama 3.2 3B on Ollama) handles real-time DM duties — narration, combat text, freeform NPC conversation, contextual choices. **Claude** (via a persistent CLI session) generates high-quality content on demand in "Forge Mode" — dungeon maps, monsters, items, quest arcs. **Godot 4** renders the world. A **Python/FastAPI orchestrator** coordinates everything with a deterministic D&D 5e rules engine.

**Development:** Windows 11 laptop. **Deployment/play:** Jetson Orin Nano (8GB). See `specs/research/dev-workflow.md`.

## Current Phase: Phase 0 — Research & Documentation

**Goal:** Complete research, validate architecture, update all documentation.

### Objectives
1. Legal/ToS research for Claude automated usage (DONE)
2. Base game evaluation — open-source Godot 4 dungeon crawlers (DONE)
3. Godot file format analysis for AI editability (DONE)
4. Jetson Orin Nano hardware/software research (DONE)
5. MCP/Forge Mode architecture design (DONE)
6. Rewrite GDDs 13, 14, 18, 20 for new architecture (DONE)
7. Write new specs: Forge Mode, DM Orchestrator, Architecture (DONE)
8. Update meta files: PROMPT.md, CLAUDE.md, @fix_plan.md, @AGENT.md (DONE)
9. Design decision refinements: Forge CLI model, dev workflow, genre, NPC emphasis (DONE)

### Phase 0 is done when:
- All research docs written to `specs/research/`
- GDDs rewritten for three-layer architecture
- New specs written for Forge Mode and DM Orchestrator
- Meta files updated to reflect the pivot
- Design decisions documented (Forge CLI, dev workflow, genre, NPC model)

## Tech Stack

- **Client:** Godot 4.x + GDScript (fork of statico/godot-roguelike-example)
- **Orchestrator:** Python 3.10+ + FastAPI
- **Real-time DM:** Ollama + Llama 3.2 3B (Q4_K_M)
- **Forge (on-demand):** Claude Code CLI (persistent session with /clear + forge/CLAUDE.md)
- **Rules:** D&D 5e SRD (markdown files in `rules/`)
- **Hardware:** Jetson Orin Nano (8GB) — runs game; Windows 11 laptop — development

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
- `dev-workflow.md` — Windows → Jetson development workflow

See `specs/reference/` for the full 20-document GDD archive.
