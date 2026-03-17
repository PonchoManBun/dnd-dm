# Character Creation — Phase 2 Spec

> **Source GDD:** [04 — Character Creation](../reference/04-character-creation.md)
> **Phase 1 code:** `game/scenes/character_creation/character_creation.gd`, `game/src/character_data.gd`
> **Depends on:** [DM Orchestrator](../phase-1-core/dm-orchestrator.md), [DM Integration](../phase-1-core/dm-integration.md)

## Overview

Phase 1 ships a 4-step offline character creation UI (Race, Class, Roll Abilities, Name & Confirm). Phase 2 keeps that UI skeleton, extends it to the full 7-step GDD flow, and wires each step to the DM Orchestrator so the local LLM narrates the process in character.

The player still clicks buttons and rolls dice in Godot. The difference is that every choice now triggers an HTTP call to the orchestrator, which returns DM narration displayed in a panel alongside the mechanical UI. The DM reacts to your choices, comments on your stats, and ultimately writes a backstory.

## What Exists (Phase 1)

| Component | File | Status |
|-----------|------|--------|
| 4-step UI | `character_creation.gd` | Done — Race, Class, Abilities, Name & Confirm |
| Character model | `character_data.gd` | Done — `Race`, `DndClass`, `Ability`, `Skill` enums; `RACE_DATA`, `CLASS_DATA` with `num_skills` and `skill_choices`; `skill_proficiencies` array |
| Race data | `assets/data/races.json` | Done — 6 races with descriptions, traits |
| Class data | `assets/data/classes.json` | Done — 6 classes with descriptions, saving throws |
| DM archetype selection | `dm_selection.gd` | Done — 5 archetypes, selected before character creation |

Key Phase 1 details in `CharacterData` already relevant to Phase 2:

- `CLASS_DATA[*]["num_skills"]` — number of skill picks per class (Fighter: 2, Rogue: 4, Ranger: 3, etc.)
- `CLASS_DATA[*]["skill_choices"]` — array of `Skill` enum values the class can choose from
- `skill_proficiencies: Array[Skill]` — empty array, ready to be populated
- `SKILL_ABILITIES` — maps every `Skill` to its governing `Ability`

## What's New (Phase 2)

### 1. Expanded Step Flow

Phase 1 has 4 steps. Phase 2 has 7:

| Step | Phase 1 | Phase 2 |
|------|---------|---------|
| 1. Choose Race | Exists | + DM narration |
| 2. Choose Class | Exists | + DM narration |
| 3. Roll Abilities | Exists | + DM narration |
| 4. Choose Alignment | **Not implemented** | New step, new UI |
| 5. Choose Skills | **Not implemented** | New step, new UI |
| 6. Backstory | **Not implemented** | LLM-generated, displayed in DM panel |
| 7. Name & Confirm | Exists (was step 4) | + backstory display in summary |

### 2. DM Narration Panel

Each step displays DM narration alongside the mechanical UI. The creation screen layout changes from a single centered panel to a split view:

```
┌──────────────────────────────────────────────┐
│  Step 3 / 7                                  │
│  Roll Abilities                              │
│──────────────────────────────────────────────│
│                         │                    │
│   [Mechanical UI]       │   [DM Narration]   │
│   Buttons, grids,       │   "The barkeep     │
│   scores, etc.          │   watches as you   │
│                         │   crack your       │
│                         │   knuckles..."     │
│                         │                    │
│──────────────────────────────────────────────│
│         [ Back ]            [ Next ]         │
└──────────────────────────────────────────────┘
```

The narration panel is a scrollable `RichTextLabel` on the right side of each step. It updates asynchronously — the player can interact with the mechanical UI immediately while narration streams in.

### 3. Orchestrator Integration

Each step transition triggers a call to the orchestrator. The orchestrator calls the local LLM, which returns narration flavored by the selected DM archetype.

### 4. New Data Fields

`CharacterData` gets two new fields (Phase 2 additions):

```gdscript
# In character_data.gd — Phase 2 additions
@export var alignment: Alignment = Alignment.TRUE_NEUTRAL
@export var backstory: String = ""

enum Alignment {
    LAWFUL_GOOD,
    NEUTRAL_GOOD,
    CHAOTIC_GOOD,
    LAWFUL_NEUTRAL,
    TRUE_NEUTRAL,
    CHAOTIC_NEUTRAL,
    LAWFUL_EVIL,
    NEUTRAL_EVIL,
    CHAOTIC_EVIL,
}
```

## HTTP Flow

### Endpoint

```
POST /character/create/step
```

All creation steps use a single endpoint. The `step` field in the request body tells the orchestrator which step the player just completed.

### Request Schema

```json
{
  "session_id": "uuid",
  "dm_archetype": "storyteller",
  "step": "race",
  "choices": {
    "race": "half_orc"
  },
  "character_state": {
    "race": "half_orc",
    "class": null,
    "abilities": null,
    "alignment": null,
    "skills": null,
    "name": null
  }
}
```

The `step` field is one of: `"race"`, `"class"`, `"abilities"`, `"alignment"`, `"skills"`, `"backstory"`, `"confirm"`.

The `choices` object contains only the choice made in the current step. The `character_state` accumulates all choices made so far.

### Response Schema

```json
{
  "narration": "A half-orc shoulders through the tavern door, knocking a chair sideways without noticing. The barkeep looks up, unimpressed. He's seen worse walk in — and most of them didn't walk out.",
  "step_data": {
    "valid": true
  }
}
```

For the `backstory` step, the response includes the generated backstory:

```json
{
  "narration": "The DM scribbles something in a leather journal, then reads aloud...",
  "step_data": {
    "valid": true,
    "backstory": "Born in the Bloodfang Mountains to a human mother who never spoke of your father, you learned to fight before you learned to read. The village feared you — all except old Marta, who taught you that strength without purpose is just violence. When she died, you found a map in her belongings, marked with a single word: Hommlet."
  }
}
```

### Full Step-by-Step Flow

**Step 1 — Race selected:**
```json
// Request
{
  "session_id": "abc-123",
  "dm_archetype": "taskmaster",
  "step": "race",
  "choices": { "race": "elf" },
  "character_state": { "race": "elf" }
}

// Response
{
  "narration": "An elf. The Taskmaster nods slowly. 'Keen eyes won't save you from what lurks below. But they might buy you an extra second. Use it wisely.'",
  "step_data": { "valid": true }
}
```

**Step 2 — Class selected:**
```json
// Request
{
  "session_id": "abc-123",
  "dm_archetype": "taskmaster",
  "step": "class",
  "choices": { "class": "rogue" },
  "character_state": { "race": "elf", "class": "rogue" }
}

// Response
{
  "narration": "A rogue. 'Interesting. You'd rather slide a knife between ribs than face an enemy head-on. Down in the crypt, there'll be plenty of shadows to hide in — and plenty of things hiding in them.'",
  "step_data": { "valid": true }
}
```

**Step 3 — Abilities rolled:**
```json
// Request
{
  "session_id": "abc-123",
  "dm_archetype": "taskmaster",
  "step": "abilities",
  "choices": {
    "base_scores": [14, 16, 11, 13, 12, 8],
    "final_scores": { "str": 14, "dex": 18, "con": 11, "int": 13, "wis": 12, "cha": 8 }
  },
  "character_state": {
    "race": "elf",
    "class": "rogue",
    "abilities": { "str": 14, "dex": 18, "con": 11, "int": 13, "wis": 12, "cha": 8 }
  }
}

// Response
{
  "narration": "The Taskmaster studies the numbers. 'Quick hands. Good. But that constitution won't do you any favors when you take a hit — and you will take hits. Every rogue does, eventually.'",
  "step_data": { "valid": true }
}
```

**Step 4 — Alignment chosen:**
```json
// Request
{
  "session_id": "abc-123",
  "dm_archetype": "taskmaster",
  "step": "alignment",
  "choices": { "alignment": "chaotic_neutral" },
  "character_state": {
    "race": "elf",
    "class": "rogue",
    "abilities": { "str": 14, "dex": 18, "con": 11, "int": 13, "wis": 12, "cha": 8 },
    "alignment": "chaotic_neutral"
  }
}

// Response
{
  "narration": "'Chaotic neutral.' The Taskmaster writes it down without looking up. 'A polite way of saying you'll do whatever serves you in the moment. Fine. Just know that the dungeon doesn't care about your philosophy.'",
  "step_data": { "valid": true }
}
```

**Step 5 — Skills chosen:**
```json
// Request
{
  "session_id": "abc-123",
  "dm_archetype": "taskmaster",
  "step": "skills",
  "choices": {
    "skills": ["stealth", "perception", "sleight_of_hand", "investigation"]
  },
  "character_state": {
    "race": "elf",
    "class": "rogue",
    "abilities": { "str": 14, "dex": 18, "con": 11, "int": 13, "wis": 12, "cha": 8 },
    "alignment": "chaotic_neutral",
    "skills": ["stealth", "perception", "sleight_of_hand", "investigation"]
  }
}

// Response
{
  "narration": "'Stealth, perception, sleight of hand, investigation.' The Taskmaster taps the table. 'A proper thief's toolkit. You'll need every one of those — and you'll wish you had more.'",
  "step_data": { "valid": true }
}
```

**Step 6 — Backstory generation (no player choice — auto-triggered):**
```json
// Request
{
  "session_id": "abc-123",
  "dm_archetype": "taskmaster",
  "step": "backstory",
  "choices": {},
  "character_state": {
    "race": "elf",
    "class": "rogue",
    "abilities": { "str": 14, "dex": 18, "con": 11, "int": 13, "wis": 12, "cha": 8 },
    "alignment": "chaotic_neutral",
    "skills": ["stealth", "perception", "sleight_of_hand", "investigation"]
  }
}

// Response
{
  "narration": "The Taskmaster sets down a quill and slides a page across the table. 'Every thief has a story. Here's yours.'",
  "step_data": {
    "valid": true,
    "backstory": "You left the Silverwood a century ago — young by elven standards, ancient by human ones. The guild in Greyhawk took you in, taught you to pick locks and pockets with equal finesse. But you got greedy, lifted a ring from the wrong wizard, and had to disappear fast. Hommlet seemed like nowhere — which was exactly what you needed. The Welcome Wench serves decent ale, and nobody here asks questions."
  }
}
```

**Step 7 — Name confirmed:**
```json
// Request
{
  "session_id": "abc-123",
  "dm_archetype": "taskmaster",
  "step": "confirm",
  "choices": { "name": "Vaelith" },
  "character_state": {
    "race": "elf",
    "class": "rogue",
    "abilities": { "str": 14, "dex": 18, "con": 11, "int": 13, "wis": 12, "cha": 8 },
    "alignment": "chaotic_neutral",
    "skills": ["stealth", "perception", "sleight_of_hand", "investigation"],
    "name": "Vaelith"
  }
}

// Response
{
  "narration": "'Vaelith.' The Taskmaster closes the journal. 'The crypt beneath Hommlet has swallowed better adventurers than you. But none of them were you. Yet. Let's see what you're made of.'",
  "step_data": {
    "valid": true,
    "character_json": { ... }
  }
}
```

The `character_json` in the final response is the complete character record that the orchestrator writes to game state. See **Data Model** below.

## New UI Steps

### Step 4: Choose Alignment

A 3x3 grid of the D&D alignment matrix. Each cell is a button. Selecting one highlights it and shows a brief description on the right.

```
        Lawful       Neutral      Chaotic
Good    [LG]         [NG]         [CG]
Neutral [LN]         [TN]         [CN]
Evil    [LE]         [NE]         [CE]
```

Layout matches the existing race/class selection pattern: grid on the left, description on the right. The description panel explains both the mechanical and narrative implications (e.g., "Chaotic Neutral — You follow your own whims. The DM may present tempting moral dilemmas.").

### Step 5: Choose Skill Proficiencies

The class determines how many skills the player picks and from which list. This data already exists in `CharacterData.CLASS_DATA`:

| Class | Picks | Options |
|-------|-------|---------|
| Fighter | 2 | Acrobatics, Animal Handling, Athletics, History, Insight, Intimidation, Perception, Survival |
| Wizard | 2 | Arcana, History, Insight, Investigation, Medicine, Religion |
| Rogue | 4 | Acrobatics, Athletics, Deception, Insight, Intimidation, Investigation, Perception, Performance, Persuasion, Sleight of Hand, Stealth |
| Cleric | 2 | History, Insight, Medicine, Persuasion, Religion |
| Ranger | 3 | Animal Handling, Athletics, Insight, Investigation, Nature, Perception, Stealth, Survival |
| Paladin | 2 | Athletics, Insight, Intimidation, Medicine, Persuasion, Religion |

UI: A list of toggle buttons for each available skill. A counter shows "N / M selected". The Next button is disabled until exactly the right number are selected. Each skill button shows the skill name and its governing ability in dim text (e.g., "Stealth (DEX)").

### Step 6: Backstory

This step has no player input — it is an automatic LLM generation step. When the player advances from Step 5, Godot sends the backstory request and shows a "The DM is writing your story..." loading state. When the response arrives, the backstory is displayed in the narration panel. The mechanical panel shows a read-only summary of all choices made so far.

This is a **local LLM task** (Ollama), not Forge. The backstory is 2-4 sentences, well within the local model's capability. The orchestrator includes the full character context (race, class, alignment, ability scores) in the LLM prompt to generate a unique, contextual backstory.

## Data Model

### CharacterData GDScript to JSON Mapping

The orchestrator's character JSON maps directly to `CharacterData` fields:

```json
{
  "name": "Vaelith",
  "race": "elf",
  "class": "rogue",
  "level": 1,
  "xp": 0,
  "alignment": "chaotic_neutral",
  "backstory": "You left the Silverwood a century ago...",

  "abilities": {
    "str": 14,
    "dex": 18,
    "con": 11,
    "int": 13,
    "wis": 12,
    "cha": 8
  },

  "hp": {
    "max": 9,
    "current": 9,
    "temp": 0,
    "hit_dice_remaining": 1
  },

  "ac": 14,
  "speed": 30,
  "initiative_bonus": 4,
  "proficiency_bonus": 2,

  "saving_throw_proficiencies": ["dex", "int"],
  "skill_proficiencies": ["stealth", "perception", "sleight_of_hand", "investigation"],
  "armor_proficiencies": ["light"],
  "weapon_proficiencies": ["simple", "hand_crossbow", "longsword", "rapier", "shortsword"],

  "conditions": [],
  "equipment": {},
  "inventory": [],
  "gold": 0
}
```

### Mapping Table

| JSON field | GDScript field | Type | Notes |
|------------|---------------|------|-------|
| `name` | `character_name` | `String` | |
| `race` | `race` | `Race` enum | JSON uses lowercase string key (`"elf"`, `"half_orc"`) |
| `class` | `dnd_class` | `DndClass` enum | JSON uses lowercase string key (`"rogue"`, `"fighter"`) |
| `level` | `level` | `int` | Always 1 at creation |
| `xp` | `experience_points` | `int` | Always 0 at creation |
| `alignment` | `alignment` | `Alignment` enum | **New in Phase 2** |
| `backstory` | `backstory` | `String` | **New in Phase 2** |
| `abilities.str` | `strength` | `int` | Includes racial bonus |
| `abilities.dex` | `dexterity` | `int` | Includes racial bonus |
| `abilities.con` | `constitution` | `int` | Includes racial bonus |
| `abilities.int` | `intelligence` | `int` | Includes racial bonus |
| `abilities.wis` | `wisdom` | `int` | Includes racial bonus |
| `abilities.cha` | `charisma` | `int` | Includes racial bonus |
| `hp.max` | `max_hp` | `int` | hit_die + CON mod |
| `hp.current` | `current_hp` | `int` | Equals max at creation |
| `hp.temp` | `temp_hp` | `int` | 0 at creation |
| `hp.hit_dice_remaining` | `hit_dice_remaining` | `int` | 1 at creation |
| `ac` | `base_ac` | `int` | 10 + DEX mod (no armor) |
| `speed` | `speed_feet` | `int` | From `RACE_DATA` |
| `saving_throw_proficiencies` | `saving_throw_proficiencies` | `Array[Ability]` | From `CLASS_DATA` |
| `skill_proficiencies` | `skill_proficiencies` | `Array[Skill]` | **Populated in Phase 2** (Step 5) |
| `armor_proficiencies` | `armor_proficiencies` | `Array[ArmorCategory]` | From `CLASS_DATA` |
| `conditions` | `conditions` | `Array[Condition]` | Empty at creation |

### JSON String Keys for Enums

The orchestrator uses lowercase string keys for all enums in JSON:

```python
RACE_KEYS = {"human", "elf", "dwarf", "halfling", "half_orc", "gnome"}
CLASS_KEYS = {"fighter", "wizard", "rogue", "cleric", "ranger", "paladin"}
ABILITY_KEYS = {"str", "dex", "con", "int", "wis", "cha"}
ALIGNMENT_KEYS = {
    "lawful_good", "neutral_good", "chaotic_good",
    "lawful_neutral", "true_neutral", "chaotic_neutral",
    "lawful_evil", "neutral_evil", "chaotic_evil"
}
SKILL_KEYS = {
    "acrobatics", "animal_handling", "arcana", "athletics",
    "deception", "history", "insight", "intimidation",
    "investigation", "medicine", "nature", "perception",
    "performance", "persuasion", "religion", "sleight_of_hand",
    "stealth", "survival"
}
ARCHETYPE_KEYS = {"storyteller", "taskmaster", "trickster", "historian", "guide"}
```

Godot converts between enum values and these string keys when serializing/deserializing.

## DM Archetype Influence

The chosen DM archetype (from `DMSelection`) is passed in every creation step request. The orchestrator includes it in the LLM system prompt, which shapes how narration is generated.

### Archetype System Prompts for Character Creation

The orchestrator prepends an archetype-specific system prompt to the LLM call:

| Archetype | System Prompt Fragment |
|-----------|----------------------|
| **Storyteller** | "You are a warm, narrative-focused Dungeon Master guiding a new adventurer through character creation. Treat each choice as the opening chapter of an epic story. Find the drama in their race, the destiny in their class, the potential in their abilities." |
| **Taskmaster** | "You are a no-nonsense Dungeon Master who respects competence and punishes weakness. During character creation, evaluate the player's choices tactically. Point out vulnerabilities. Make them understand that the dungeon will test every stat." |
| **Trickster** | "You are a mischievous, witty Dungeon Master who delights in surprises. During character creation, find the humor and irony in the player's choices. Make unexpected observations. Nothing is straightforward with you." |
| **Historian** | "You are a scholarly Dungeon Master steeped in lore. During character creation, connect each choice to the world's history. Every race has an ancient lineage, every class a storied tradition, every alignment a philosophical school." |
| **Guide** | "You are a patient, encouraging Dungeon Master helping a new adventurer. During character creation, explain what each choice means mechanically and narratively. Offer gentle suggestions without being prescriptive." |

### Example: Same Choice, Different Archetypes

Player chooses Half-Orc:

- **Storyteller:** "A half-orc steps into The Welcome Wench. The firelight catches the scar tissue on her knuckles, each mark a story she hasn't told yet. The other patrons glance, then look away. They know better."
- **Taskmaster:** "Half-orc. Strength and Constitution bonuses — you'll need both. But 30-foot speed means you can't outrun trouble when it comes, and with a half-orc face, trouble always comes. Relentless Endurance will save your life exactly once. Make it count."
- **Trickster:** "A half-orc! Wonderful. The last half-orc who came through here arm-wrestled the tavern cat and lost. To be fair, it's a very large cat. Savage Attacks is nice — when you crit, you really crit. Let's hope you crit before whatever you're fighting crits you."
- **Historian:** "The half-orcs of this region descend from the Broken Tusk clan, who fought on both sides of the War of the Silver Crown. Your people carry orc blood and human ambition in equal measure — a combination that has produced both tyrants and liberators."
- **Guide:** "Half-orcs get +2 Strength and +1 Constitution, making them excellent front-line fighters. Relentless Endurance lets you drop to 1 HP instead of 0 once per long rest — a great safety net. Savage Attacks gives extra damage on critical hits."

## Orchestrator Implementation

### Character Creation Handler

```python
from pydantic import BaseModel
from typing import Optional

class CreationStepRequest(BaseModel):
    session_id: str
    dm_archetype: str  # "storyteller", "taskmaster", etc.
    step: str          # "race", "class", "abilities", "alignment", "skills", "backstory", "confirm"
    choices: dict
    character_state: dict

class CreationStepResponse(BaseModel):
    narration: str
    step_data: dict

@app.post("/character/create/step")
async def character_creation_step(req: CreationStepRequest) -> CreationStepResponse:
    # 1. Validate the step and choices
    validate_creation_step(req.step, req.choices, req.character_state)

    # 2. Build LLM prompt
    system_prompt = get_archetype_creation_prompt(req.dm_archetype)
    user_prompt = build_creation_narration_prompt(
        step=req.step,
        choices=req.choices,
        character_state=req.character_state,
    )

    # 3. Call local LLM
    llm_response = await ollama.chat(
        model="llama3.2:3b",
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ]
    )

    narration = llm_response["message"]["content"]

    # 4. For backstory step, extract and store the backstory
    step_data = {"valid": True}
    if req.step == "backstory":
        backstory = await generate_backstory(req.dm_archetype, req.character_state)
        step_data["backstory"] = backstory

    # 5. For confirm step, finalize the character
    if req.step == "confirm":
        character_json = finalize_character(req.character_state, req.choices["name"])
        step_data["character_json"] = character_json
        save_character(req.session_id, character_json)

    return CreationStepResponse(narration=narration, step_data=step_data)
```

### Backstory Generation

```python
async def generate_backstory(archetype: str, character_state: dict) -> str:
    system_prompt = get_archetype_creation_prompt(archetype)

    user_prompt = f"""Generate a unique backstory (2-4 sentences) for this character:
- Race: {character_state['race']}
- Class: {character_state['class']}
- Alignment: {character_state['alignment']}
- Abilities: {character_state['abilities']}
- Skills: {character_state.get('skills', [])}

The backstory should explain why this character arrived at The Welcome Wench tavern
in the village of Hommlet. It should hint at their past without being too specific,
leaving room for the adventure to fill in details. Write in second person ("you")."""

    response = await ollama.chat(
        model="llama3.2:3b",
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ]
    )

    return response["message"]["content"]
```

This is a local LLM call, not a Forge invocation. Backstory generation is fast (2-4 sentences, ~50-100 tokens output) and doesn't require Claude's quality. The LLM has enough context from the character choices to produce a serviceable backstory.

## Godot Client Changes

### Modified Files

| File | Change |
|------|--------|
| `character_creation.gd` | Expand from 4 to 7 steps; add DM narration panel; add HTTP calls on step transitions |
| `character_data.gd` | Add `Alignment` enum, `alignment` field, `backstory` field |

### New Constants in `character_creation.gd`

```gdscript
const STEP_COUNT: int = 7
const STEP_TITLES: Array[String] = [
    "Choose Race",
    "Choose Class",
    "Roll Abilities",
    "Choose Alignment",
    "Choose Skills",
    "Your Story",
    "Name & Confirm",
]
```

### HTTP Integration Pattern

Each step transition calls the orchestrator. The UI does not block — the player sees the mechanical UI immediately, and narration appears asynchronously.

```gdscript
# Called when transitioning to the next step
func _request_narration(step: String, choices: Dictionary) -> void:
    var request := {
        "session_id": _session_id,
        "dm_archetype": _dm_archetype,
        "step": step,
        "choices": choices,
        "character_state": _build_character_state(),
    }
    var http := HTTPRequest.new()
    add_child(http)
    http.request_completed.connect(_on_narration_received.bind(http))
    http.request(
        "http://localhost:8000/character/create/step",
        ["Content-Type: application/json"],
        HTTPClient.METHOD_POST,
        JSON.stringify(request)
    )

func _on_narration_received(result: int, code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
    http.queue_free()
    if code != 200:
        _dm_narration_label.text = "[i]The DM is silent.[/i]"
        return
    var json := JSON.new()
    if json.parse(body.get_string_from_utf8()) == OK:
        var data: Dictionary = json.data
        _dm_narration_label.text = data.get("narration", "")
        if data.has("step_data"):
            var step_data: Dictionary = data["step_data"]
            if step_data.has("backstory"):
                _backstory_text = step_data["backstory"]
```

### Offline Fallback

If the orchestrator is unreachable (Phase 1 mode, or orchestrator not running), character creation works without narration. The DM panel shows a placeholder message. All mechanical functionality (race/class/skill selection, ability rolls, etc.) remains fully local.

```gdscript
func _on_narration_received(result: int, code: int, ...) -> void:
    if result != HTTPRequest.RESULT_SUCCESS or code != 200:
        _dm_narration_label.text = "[color=#666666][i]No DM connected. Choices are yours alone.[/i][/color]"
        return
    # ... normal handling
```

## Validation Rules

The orchestrator validates each step server-side:

| Step | Validation |
|------|-----------|
| `race` | Race key is in `RACE_KEYS` |
| `class` | Class key is in `CLASS_KEYS` |
| `abilities` | Six scores, each 3-18 before racial bonuses |
| `alignment` | Alignment key is in `ALIGNMENT_KEYS` |
| `skills` | Exactly `CLASS_DATA[class].num_skills` skills chosen, all from `CLASS_DATA[class].skill_choices` |
| `backstory` | No validation needed (auto-generated) |
| `confirm` | Name is 1-24 characters, non-empty after stripping whitespace |

Invalid requests return HTTP 422 with an error message. Godot displays the error in the narration panel.

## Sequence Diagram

```
Player          Godot             Orchestrator       Ollama (LLM)
  |               |                    |                  |
  |  Select Race  |                    |                  |
  |──────────────>|                    |                  |
  |               | POST /create/step  |                  |
  |               | {step: "race"}     |                  |
  |               |───────────────────>|                  |
  |               |                    | chat(prompt)     |
  |               |                    |─────────────────>|
  |               |                    |     narration    |
  |               |                    |<─────────────────|
  |               |  {narration: "..."}|                  |
  |               |<───────────────────|                  |
  |  See narration|                    |                  |
  |<──────────────|                    |                  |
  |               |                    |                  |
  | [repeat for each step 2-5]        |                  |
  |               |                    |                  |
  |  Advance to   |                    |                  |
  |  Backstory    | POST /create/step  |                  |
  |──────────────>| {step: "backstory"}|                  |
  |               |───────────────────>|                  |
  |               |                    | chat(backstory   |
  |               |                    |      prompt)     |
  |               |                    |─────────────────>|
  |               |                    |    backstory     |
  |               |                    |<─────────────────|
  |               | {backstory: "..."} |                  |
  |               |<───────────────────|                  |
  | See backstory |                    |                  |
  |<──────────────|                    |                  |
  |               |                    |                  |
  |  Enter name   |                    |                  |
  |  & Confirm    | POST /create/step  |                  |
  |──────────────>| {step: "confirm"}  |                  |
  |               |───────────────────>|                  |
  |               |                    | [finalize char]  |
  |               |  {character_json}  |                  |
  |               |<───────────────────|                  |
  | Enter tavern  |                    |                  |
  |<──────────────|                    |                  |
```

## Implementation Checklist

### Godot Client

- [ ] Add `Alignment` enum and `alignment`, `backstory` fields to `CharacterData`
- [ ] Expand `CharacterCreation` from 4 to 7 steps
- [ ] Build Step 4 UI (alignment 3x3 grid)
- [ ] Build Step 5 UI (skill proficiency toggles with counter)
- [ ] Build Step 6 UI (backstory display with loading state)
- [ ] Update Step 7 summary to include alignment, skills, backstory
- [ ] Add DM narration panel (right-side `RichTextLabel`) to all steps
- [ ] Add `HTTPRequest` calls on step transitions
- [ ] Handle offline fallback (no orchestrator)
- [ ] Populate `skill_proficiencies` in `_confirm_character()`
- [ ] Populate `alignment` in `_confirm_character()`
- [ ] Store `backstory` in `CharacterData`

### Orchestrator

- [ ] Implement `POST /character/create/step` endpoint
- [ ] Build archetype-aware system prompts for creation narration
- [ ] Build per-step user prompts (race description, class description, etc.)
- [ ] Implement backstory generation via local LLM
- [ ] Implement `finalize_character()` — compute HP, AC, saves, proficiencies
- [ ] Implement step validation
- [ ] Store session state (track creation progress per session)

### Data

- [ ] Add `alignment` and `backstory` fields to save/load serialization
- [ ] Update `GameState` JSON schema to include new fields
