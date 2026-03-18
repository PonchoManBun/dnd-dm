# 21 — Party & Companions

## Overview

The Welcome Wench uses a **BG3-style companion system**. The player can recruit up to **3 companions** (4 party members total). Any NPC in the game world can potentially join the party -- a tavern regular, a rescued prisoner, a reformed goblin, or a hired mercenary. Companions are full characters with their own stat blocks, personalities, and progression.

This is not a "hire a generic mercenary" system. Companions are the NPCs the player already knows from the world. Recruiting Old Tom from the tavern means Old Tom leaves the tavern and fights alongside the player. His personality, knowledge, and dialogue carry over. The world loses an NPC and the party gains a companion.

**Status: Planned**

---

## Recruitment

### How NPCs Are Recruited

Recruitment happens through **freeform conversation** with the local LLM. There is no "Recruit" button. The player must convince the NPC to join through dialogue -- persuasion, shared goals, payment, or circumstance.

Common recruitment paths:

| Method | Example |
|---|---|
| Persuasion | Convincing Elara the Quiet that her skills are needed |
| Quest completion | Rescuing a prisoner who offers to join in gratitude |
| Payment | Hiring a mercenary NPC for gold |
| Shared purpose | An NPC volunteers to join because they share the player's quest goal |
| Circumstance | An NPC joins because staying behind is more dangerous than coming along |

### Recruitment Rules

1. **NPCs can refuse.** The LLM evaluates the request against the NPC's personality, goals, and disposition toward the player. A hostile NPC will not join. A cowardly NPC may refuse a dangerous quest.
2. **No mid-combat recruitment.** NPCs cannot be recruited while combat is active. The conversation must happen in exploration mode.
3. **Party size limit: 4 total.** If the party already has 4 members (player + 3 companions), the player must dismiss a companion before recruiting a new one.
4. **Recruitable flag.** NPC profiles include a `recruitable` field. Some NPCs are essential to the world (e.g., Barkeep Marta runs the tavern) and cannot be recruited. The DM enforces this narratively -- Marta will refuse because she has a tavern to run.
5. **Disposition threshold.** NPCs require a minimum disposition toward the player before they will consider joining. Hostile or indifferent NPCs must be warmed up first.

### Recruitment Flow

```
Player initiates conversation with NPC
  -> Player asks NPC to join (freeform text)
  -> LLM evaluates: personality, disposition, recruitable flag, party size
  -> NPC accepts or refuses (with in-character reasoning)
  -> If accepted:
     -> NPC stat block converts to full CharacterData (see spec 22)
     -> NPC added to party roster
     -> NPC removed from world location
     -> DM narrates the moment
```

---

## Party Management

### Party Roster

The party roster is a JSON array stored in the game state. Maximum 4 entries (player + up to 3 companions).

```json
{
  "party": [
    {
      "id": "player",
      "name": "Thorin Ironforge",
      "is_player": true,
      "character_data": { ... }
    },
    {
      "id": "old_tom",
      "name": "Old Tom",
      "is_player": false,
      "source_npc_id": "old_tom",
      "recruited_turn": 42,
      "character_data": { ... }
    }
  ]
}
```

### Camp Model

When the player recruits more than 3 companions total (across the game), excess companions wait at the tavern -- the **camp**. The player can swap active companions when visiting the tavern, similar to BG3's camp system.

- **Active party**: Up to 3 companions traveling with the player.
- **Camp**: Companions left at the tavern. They remain at the Welcome Wench, interacting with other NPCs. Their NPC profile is restored (with updated stats) so the LLM can generate their dialogue.
- **Swapping**: At the tavern, the player can ask companions to join or stay behind through dialogue. No menu -- conversation only.

### Formation & Movement

During exploration, companions follow the player automatically:

- Companions trail 1-2 tiles behind the player in a loose formation.
- Companions pathfind around obstacles using A* (same algorithm as monster movement).
- Companions do not trigger traps or block doorways.
- If the player moves too far ahead, companions teleport to catch up (off-screen, no visible pop-in).

---

## Companion AI

### Exploration Behavior

Outside of combat, companions are **fully automated**:

- Follow the player at 1-2 tile distance.
- Idle animations when the player stops.
- React to nearby events (turn toward threats, face NPCs being spoken to).
- Do not initiate combat independently -- only the player bumping into a hostile starts a fight.

### Combat Control

In combat, the **player controls all party members**. Each companion gets their own turn in initiative order with full action economy (movement, action, bonus action, reaction).

- The active combatant is highlighted in the initiative tracker.
- When it is a companion's turn, the player selects actions for them.
- Companions use the same input scheme as the player (WASD movement, bump-to-attack).
- The UI shows which character is currently active.

### No Autonomous Combat

Companions do not make their own combat decisions. The player is the tactician. This avoids the frustration of bad AI decisions in combat and preserves the tactical feel.

---

## Companion Death

### Individual Death

When a companion reaches 0 HP:

1. **Death saves** apply (same as player character). Three successes = stabilized. Three failures = dead.
2. **Other party members can stabilize** a downed companion with a Medicine check (DC 10) as an action, or by using a healing spell/potion.
3. **Dead companions are permanently dead.** Their body remains on the map. Equipment can be looted.
4. **DM narrates the death** with appropriate gravity. The companion's story ends.

### Game Over Condition

The game continues as long as **any party member is alive**. This is a key change from the base game's single-character model:

- If the player character dies but a companion survives, **the game continues**. The player takes control of a surviving companion.
- If multiple companions survive, the player chooses which one to control.
- **Game over occurs only when ALL party members are dead** (Total Party Kill / TPK).
- The "last stand" mechanic (from spec 08) applies to the **final surviving party member**, not just the player character.

### Control Transfer on Player Death

```
Player character dies
  -> If companions alive:
     -> "Your vision fades... but [companion name] fights on."
     -> Player selects surviving companion to control
     -> Game continues with reduced party
  -> If no companions alive:
     -> TPK -- game over
     -> Death flow from spec 08 triggers
```

---

## Dialogue System

### Speaker Selection

The DM panel includes a **speaker dropdown** that lets the player choose which party member is talking. This affects:

- **NPC responses**: NPCs react differently based on who is speaking. A guard may respond better to a Paladin than a Rogue.
- **Skill checks**: Persuasion, Intimidation, Deception checks use the speaking character's modifiers.
- **Personality**: The LLM factors in the speaking companion's personality when generating the NPC's response.

### Dialogue Target Selection

When multiple NPCs are present, a **target dropdown** lets the player select who they are speaking to. Combined with the speaker dropdown, this creates a full `[Speaker] -> [Target]` dialogue system.

### DM Panel Extensions

```
┌─────────────────────────────┐
│  Speaker: [Thorin      v]   │
│  To:      [Barkeep Marta v] │
│                             │
│  [Narrative text area]      │
│                             │
│  > "What do you know about  │
│    the crypt?"              │
│  ___________________________│
│  [Free-text input field]    │
└─────────────────────────────┘
```

### Companion Banter

Between player-initiated conversations, companions may interject with **ambient dialogue** -- short comments triggered by game events:

- Entering a new room: *"This place gives me the creeps." -- Old Tom*
- Finding loot: *"Dibs on the shiny one." -- Elara*
- Low HP: *"I could use a rest..." -- Old Tom*

Banter is generated by the local LLM using each companion's personality profile. It appears in the DM panel as attributed dialogue.

---

## NPC Profile Extensions

### New Fields for Companion System

The NPC profile format (from `npc_profiles.json`) is extended with companion-related fields. Existing profiles remain backward-compatible -- all new fields are optional.

```json
{
  "old_tom": {
    "name": "Old Tom",
    "role": "retired adventurer and tavern regular",
    "personality": "Grizzled veteran who tells tall tales...",
    "knowledge": "Old dungeon layouts, monster weaknesses...",
    "greeting": "Eh? Another young fool looking for glory?",
    "location": "Seated at a dining table",

    "recruitable": true,
    "recruitment_disposition_threshold": 10,
    "class_predisposition": "fighter",
    "race": "human",
    "backstory_hooks": [
      "Claims to have fought a dragon — did he really?",
      "Why did he retire? What drove him from adventuring?"
    ],
    "companion_quest": {
      "id": "old_toms_last_adventure",
      "title": "One Last Ride",
      "trigger": "recruited + party reaches dungeon floor 2",
      "summary": "Old Tom recognizes the dungeon. He's been here before — and he left something behind."
    },
    "stat_block": {
      "str": 14,
      "dex": 10,
      "con": 13,
      "int": 10,
      "wis": 12,
      "cha": 11,
      "max_hp": 15,
      "ac": 12,
      "speed": 30,
      "cr": 0.5
    }
  }
}
```

### Field Descriptions

| Field | Type | Description |
|---|---|---|
| `recruitable` | `bool` | Whether this NPC can join the party. Default `false`. |
| `recruitment_disposition_threshold` | `int` | Minimum disposition score required for recruitment. Default `0`. |
| `class_predisposition` | `string` | Preferred DndClass slug when the NPC earns their first class (see spec 22). Optional -- if absent, class is inferred from stats. |
| `race` | `string` | Race slug matching `CharacterData.Race` enum. Required for character sheet conversion. |
| `backstory_hooks` | `string[]` | Story threads that can be explored through companion conversation. Used by the LLM for dialogue. |
| `companion_quest` | `object\|null` | A personal quest tied to this companion. Unlocks after recruitment + trigger condition. |
| `stat_block` | `object` | D&D 5e ability scores and combat stats. Used to create the companion's `CharacterData` on recruitment. Format matches `dnd_monsters.json` ability score fields. |

### NPCs Without Stat Blocks

Some NPCs (especially townsfolk) may not have explicit stat blocks in their profile. When recruited, the orchestrator generates a stat block using the **commoner template**:

```json
{
  "str": 10, "dex": 10, "con": 10,
  "int": 10, "wis": 10, "cha": 10,
  "max_hp": 4, "ac": 10, "speed": 30, "cr": 0
}
```

The commoner template ensures any NPC can be recruited, even if they are mechanically weak. This supports emergent gameplay where players recruit unlikely companions.
