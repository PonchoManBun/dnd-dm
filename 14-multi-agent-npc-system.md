# 14 — Multi-Agent NPC System

## Architecture

NPCs are not simple dialogue trees. They are **autonomous agents** managed by the AI DM through a multi-agent hierarchy:

```
AI DM (Claude)
├── Faction Agent: Thieves' Guild
│   ├── NPC: Dagger Nell (fence)
│   └── NPC: Whisper (informant)
├── Faction Agent: Town Guard
│   ├── NPC: Captain Holt (commander)
│   └── NPC: Recruit Tam (patrol)
└── Independent NPCs
    ├── NPC: Barkeep Marta (tavern owner)
    └── NPC: Old Gren (hermit)
```

## Faction Agents

Each faction is a mid-level agent with:

- **Goals** — What the faction wants (territory, wealth, power, order)
- **Resources** — Members, gold, territory, information
- **Relationships** — Alliances and rivalries with other factions
- **Reaction rules** — How the faction responds to world events

Factions are seeded from 2–3 archetypes at world creation and evolve through play.

## NPC Sub-Agents

Each significant NPC has an individual identity:

- **Personality, goals, knowledge, disposition** (see §12)
- **Memory** — What they've witnessed and been told
- **Autonomy** — They act between player interactions (the DM simulates off-screen behavior)

## Event Bus

Agents communicate through a **central event bus**:

- World events are broadcast (combat, deaths, quests completed, faction actions)
- Each agent subscribes to relevant events
- NPCs and factions react based on their knowledge and goals

## World Log & Memory

A **chronological world log** records all significant events. Each NPC filters the log for events they witnessed or were told about. An NPC in a distant town doesn't know about a dungeon battle — unless someone tells them.

## Cross-Death Persistence

NPCs remember previous player characters. The world log persists across permadeath. A merchant might say: *"Your predecessor owed me 50 gold. You wouldn't happen to be paying her debts?"*
