# 14 — Multi-Agent NPC System

## Design Principle

**Every NPC is a live conversational agent. No menu trees. No canned dialogue.**

When you talk to the barkeep, the blacksmith, or a random guard, the local LLM generates their dialogue in real-time based on their personality, knowledge, and relationship with you. You can negotiate prices, bluff your way past guards, ask for directions, flirt, threaten, or say anything you want. NPCs respond naturally. This is a core differentiator — not a side feature.

## Architecture

NPCs use a **hybrid approach**: deterministic state machines in GDScript for movement/scheduling + **freeform LLM conversation** for all dialogue and personality expression.

```
DM Orchestrator
├── Faction System (deterministic logic)
│   ├── Faction: Thieves' Guild
│   │   ├── NPC: Dagger Nell (fence)
│   │   └── NPC: Whisper (informant)
│   ├── Faction: Town Guard
│   │   ├── NPC: Captain Holt (commander)
│   │   └── NPC: Recruit Tam (patrol)
│   └── Independent NPCs
│       ├── NPC: Barkeep Marta (tavern owner)
│       └── NPC: Old Gren (hermit)
│
├── Local LLM → dialogue generation, personality expression
└── Forge (Claude) → NPC profile creation, faction arc design
```

## NPC Behavior: State Machines + Freeform LLM Conversation

### GDScript State Machine (Movement & Scheduling)

Each NPC has a finite state machine implemented in GDScript that handles **non-dialogue behavior**:

```
States: IDLE → PATROL → ALERT → INTERACT → FLEE → COMBAT
```

Transitions are based on game events, not LLM decisions:
- Player enters detection radius → IDLE → ALERT
- Player initiates conversation → ALERT → INTERACT
- NPC health below threshold → COMBAT → FLEE
- Time of day changes → IDLE → PATROL (if daytime shopkeeper)

The state machine handles: movement, pathfinding, animations, positioning. **All dialogue is LLM-generated.**

### Freeform LLM Conversation (All Dialogue)

When the player interacts with an NPC, the local LLM generates **freeform dialogue** using the NPC's personality profile. There are no dialogue trees, no menu options (beyond the standard "Do something else..." free-text input). The player can say anything, and the NPC responds in character.

**Example conversation types:**
- **Negotiation:** "Can you knock 10 gold off the price?" → Barkeep responds based on disposition, personality, how much the player has bought before
- **Information gathering:** "What do you know about the crypt?" → NPC shares (or withholds) based on their knowledge and trust
- **Bluffing:** "I'm with the town guard, let me through." → NPC evaluates based on player's charisma, the situation, their personality
- **Social:** "How's business?" → NPC chats naturally, reveals personality, may drop hints

**Orchestrator builds the NPC context prompt:**
```
NPC: Barkeep Marta
Role: tavern owner, information broker
Personality: warm, gossipy, shrewd businesswoman
Knowledge: [events she's witnessed from her NPC state file]
Disposition toward player: [friendly/neutral/hostile, based on faction + past interactions]
Current state: INTERACT
Player said: "What do you know about the crypt?"
```

**Local LLM generates:** Freeform dialogue, emotional tone, hints or misdirection based on personality. The player can respond with anything — the LLM continues the conversation naturally.

### Forge-Generated NPC Profiles

When a new significant NPC is needed, Forge (Claude) creates the full profile:

```json
{
  "name": "Barkeep Marta",
  "role": "tavern_owner",
  "race": "human",
  "personality": ["warm", "gossipy", "shrewd"],
  "goals": ["run profitable tavern", "protect regulars", "collect secrets"],
  "knowledge_base": ["local rumors", "traveler stories", "thieves guild dealings"],
  "disposition_default": "friendly",
  "dialogue_style": "colloquial, uses food metaphors, calls everyone 'love'",
  "secrets": ["knows thieves guild fence location", "saw the murder"],
  "schedule": {
    "morning": "cleaning tavern",
    "afternoon": "serving customers",
    "evening": "busy service, gossip hour",
    "night": "closing up, counting coins"
  }
}
```

## Faction System

### Deterministic Logic (Orchestrator)

Factions operate on mechanical rules, not LLM creativity:

- **Reputation scores** — Player actions adjust numeric reputation per faction
- **Relationship matrix** — Faction-to-faction dispositions (allied, neutral, hostile)
- **Threshold triggers** — At certain reputation levels, faction behavior changes
- **Resource tracking** — Members, territory, gold (simplified)

```python
# Example: faction reputation change
if player_killed_guard:
    factions["town_guard"].reputation -= 20
    factions["thieves_guild"].reputation += 5  # enemy of my enemy

    if factions["town_guard"].reputation < -50:
        trigger_event("town_guard_hostile")  # guards attack on sight
```

### Forge-Designed Arcs (Claude)

Claude generates the **narrative arcs** for faction conflicts during Forge Mode:

- What happens when the thieves' guild gains power?
- What quest does the town guard offer to regain control?
- How do faction conflicts intertwine with the main story?

These arcs are written as JSON quest data that the orchestrator loads and advances based on deterministic triggers.

## NPC Memory: JSON State Files

Each significant NPC has a JSON state file:

```json
{
  "npc_id": "barkeep_marta",
  "met_player": true,
  "interactions": [
    {"turn": 42, "summary": "Player asked about crypt, Marta warned about undead"},
    {"turn": 67, "summary": "Player returned injured, Marta offered free healing potion"}
  ],
  "disposition": 15,
  "knowledge": [
    "Player is investigating the crypt",
    "Player defeated the skeleton patrol"
  ],
  "flags": {
    "told_about_secret_passage": false,
    "offered_discount": true
  }
}
```

The orchestrator loads the relevant NPC state file and includes it in the local LLM's context when the player interacts with that NPC. The LLM uses this memory to generate contextually appropriate dialogue.

## Event System

### World Events (Deterministic)

The orchestrator broadcasts events as they happen:

- Combat outcomes, deaths, quest completions
- Faction reputation changes
- Time passage, location changes

### NPC Reactions (Hybrid)

Each NPC's state machine checks relevant events:
- Guard NPC sees player steal → state transition to COMBAT (deterministic)
- Barkeep hears about player's heroism → disposition increase (deterministic)
- Next dialogue: LLM references the event naturally (creative)

## Cross-Death Persistence

NPC state files persist across permadeath. The world log continues. When a new player character enters:

- NPCs remember previous characters via their state files
- Disposition resets to default (new person, no relationship)
- Knowledge persists ("Your predecessor owed me 50 gold...")
- Faction reputations carry forward as world state

The local LLM generates the cross-death references using the NPC's stored knowledge of the previous character.
