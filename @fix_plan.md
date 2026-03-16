# Phase 0 — Research & Documentation: Task List

## COMPLETED — Research

- [x] Legal/ToS research for Claude automated usage → `specs/research/legal-claude-usage.md`
- [x] Base game evaluation (Godot 4 dungeon crawlers) → `specs/research/base-game-evaluation.md`
- [x] Godot file format analysis for AI editability → `specs/research/godot-file-formats.md`
- [x] Jetson Orin Nano hardware/software research → `specs/research/jetson-setup.md`
- [x] MCP/Forge Mode architecture design → `specs/research/mcp-forge-design.md`

## COMPLETED — GDD Rewrites

- [x] GDD-18 (Technical Architecture) — Three-layer single-machine topology
- [x] GDD-13 (AI Dungeon Master) — Dual-model DM (local LLM + Claude Forge)
- [x] GDD-14 (Multi-Agent NPC System) — State machines + freeform LLM conversation
- [x] GDD-20 (Development Roadmap) — New phased plan (0-5)

## COMPLETED — New Specs

- [x] `specs/phase-1-core/architecture.md` — Rewritten for new architecture
- [x] `specs/phase-1-core/overview.md` — Updated for new stack
- [x] `specs/phase-1-core/dm-integration.md` — Updated for dual-model DM
- [x] `specs/phase-1-core/forge-mode.md` — Persistent CLI session model, player-action-triggered
- [x] `specs/phase-1-core/dm-orchestrator.md` — DM Orchestrator design, forge trigger detection

## COMPLETED — Meta File Updates

- [x] `PROMPT.md` — Updated for new architecture
- [x] `CLAUDE.md` — Updated project instructions and tech stack
- [x] `@fix_plan.md` — This file (updated)
- [x] `@AGENT.md` — Updated build/run/test commands

## COMPLETED — Design Decision Refinements (Phase 0b)

- [x] Forge invocation model → persistent CLI session, not Agent SDK subprocess
- [x] Development workflow → Windows 11 laptop → Jetson (SSH, git, rsync)
- [x] Genre language → "turn-based tactical RPG" with hybrid combat
- [x] NPC emphasis → all NPCs are freeform conversational agents
- [x] New file: `forge/CLAUDE.md` — Forge-specific instructions
- [x] New file: `specs/research/dev-workflow.md` — Two-machine dev workflow
- [x] Updated all specs, reference docs, and meta files for consistency

---

## NEXT — Phase 1 Tasks (Standalone Godot Game)

### HIGH — Must complete

- [ ] Fork statico/godot-roguelike-example into project
- [ ] Evaluate and adapt D20 combat to D&D 5e SRD rules
- [ ] Add DM panel UI (narrative text display, choice buttons, free-text input)
- [ ] Create hardcoded test dungeon with hand-authored content
- [ ] Basic character creation flow (race, class, ability scores)
- [ ] Save/load system
- [ ] Implement hybrid combat model (roguelike exploration + tactical D&D 5e combat)

### MEDIUM — Should complete

- [ ] Adapt tileset/sprites for TWW visual style
- [ ] Implement DM archetype selection (UI only, no LLM yet)
- [ ] Inventory and equipment UI polish
- [ ] SRD rules markdown loading into Godot (for reference display)

### LOW — Nice to have

- [ ] Audio integration (placeholder music + SFX)
- [ ] Death/permadeath flow (UI only)
- [ ] Title screen and menu flow
