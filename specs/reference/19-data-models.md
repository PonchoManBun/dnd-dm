# 19 — Data Models

## State Contract

The orchestrator (Python/FastAPI) is authoritative for game state. It maintains the canonical state and serves it as JSON. The Godot client reads JSON and renders pixels — it never modifies game state directly. All field names use snake_case, matching both GDScript and Python conventions.

## Client-Side Models (GDScript)

### CharacterData (Resource)

Defined in `game/src/character_data.gd`. Used for both player characters and NPCs with full stat blocks.

```gdscript
# Identity
character_name: String
race: Race           # enum: HUMAN, ELF, DWARF, HALFLING, HALF_ORC, GNOME, DRAGONBORN, HALF_ELF, TIEFLING
dnd_class: DndClass  # enum: FIGHTER, WIZARD, ROGUE, CLERIC, RANGER, PALADIN, BARBARIAN, BARD, DRUID, MONK, SORCERER, WARLOCK
level: int
experience_points: int

# Ability Scores (3-20 for PCs, 1-30 for monsters)
strength: int
dexterity: int
constitution: int
intelligence: int
wisdom: int
charisma: int

# Hit Points
max_hp: int
current_hp: int
temp_hp: int
hit_dice_remaining: int

# Combat
base_ac: int
speed_feet: int          # Movement speed in feet (tiles = speed / 5)
initiative_bonus: int

# Death Saves
death_save_successes: int
death_save_failures: int

# Proficiencies
saving_throw_proficiencies: Array[Ability]
skill_proficiencies: Array[Skill]
skill_expertise: Array[Skill]
armor_proficiencies: Array[ArmorCategory]
weapon_proficiencies: Array[StringName]

# Conditions
conditions: Array[Condition]

# Class-specific resources
class_features: Dictionary    # { feature_name: { "active": bool, "uses": int, "max_uses": int } }
rage_charges: int             # Barbarian
rage_active: bool
sneak_attack_dice: int        # Rogue
action_surge_charges: int     # Fighter
spell_slots: Array[int]       # Casters (index 0 = 1st-level slots)
spell_slots_used: Array[int]
ki_points: int                # Monk
ki_points_max: int
channel_divinity_charges: int # Cleric
bardic_inspiration_charges: int # Bard
bardic_inspiration_die: int
wild_shape_charges: int       # Druid
lay_on_hands_pool: int        # Paladin
sorcery_points: int           # Sorcerer
sorcery_points_max: int
```

### Enums (GDScript)

All defined as inner enums on `CharacterData`:

- **Race** (9): HUMAN, ELF, DWARF, HALFLING, HALF_ORC, GNOME, DRAGONBORN, HALF_ELF, TIEFLING
- **DndClass** (12): FIGHTER, WIZARD, ROGUE, CLERIC, RANGER, PALADIN, BARBARIAN, BARD, DRUID, MONK, SORCERER, WARLOCK
- **Ability** (6): STRENGTH, DEXTERITY, CONSTITUTION, INTELLIGENCE, WISDOM, CHARISMA
- **Skill** (18): ACROBATICS through SURVIVAL
- **Condition** (14): BLINDED through UNCONSCIOUS
- **ArmorCategory** (4): LIGHT, MEDIUM, HEAVY, SHIELDS

### Game State Serialization (GDScript)

Defined in `game/src/game_state_serializer.gd`. Serializes and deserializes the full game state to/from a JSON-compatible Dictionary.

```json
{
  "version": 1,
  "timestamp": 1710000000.0,
  "current_turn": 42,
  "max_depth": 3,
  "game_over": false,
  "current_map_id": "crypt_f2",
  "current_map_depth": 2,
  "faction_affinities": { "0": 10, "1": -5 },
  "player": {
    "slug": "player",
    "name": "Thrain",
    "role": 0,
    "species": 0,
    "variant": "",
    "hp": 28,
    "max_hp": 34,
    "energy": 100,
    "is_dead": false,
    "nutrition": 900,
    "position_x": 5,
    "position_y": 8,
    "sight_radius": 6,
    "character_data": {
      "character_name": "Thrain",
      "race": 2,
      "dnd_class": 0,
      "level": 3,
      "experience_points": 900,
      "strength": 16,
      "dexterity": 12,
      "constitution": 14,
      "intelligence": 8,
      "wisdom": 13,
      "charisma": 10,
      "max_hp": 34,
      "current_hp": 28,
      "temp_hp": 0,
      "hit_dice_remaining": 3,
      "base_ac": 16,
      "speed_feet": 25,
      "initiative_bonus": 1,
      "death_save_successes": 0,
      "death_save_failures": 0,
      "saving_throw_proficiencies": [0, 2],
      "skill_proficiencies": [3, 11],
      "skill_expertise": [],
      "armor_proficiencies": [0, 1, 2, 3],
      "weapon_proficiencies": [],
      "conditions": []
    },
    "skill_levels": {},
    "status_effects": [],
    "inventory": [
      { "slug": "health_potion", "name": "Health Potion", "type": 5, "quantity": 2, "enhancement": 0, "is_armed": false, "turns_to_activate": 0, "is_open": false }
    ],
    "equipment": {
      "8": { "slug": "longsword", "name": "Longsword", "type": 0, "quantity": 1, "enhancement": 0, "is_armed": false, "turns_to_activate": 0, "is_open": false }
    }
  }
}
```

Note: Enum values are serialized as integers. Equipment slots are keyed by slot enum integer. Maps are regenerated from the world plan seed on load (not serialized).

## Orchestrator-Side Models (Python/Pydantic)

### CharacterState

Defined in `orchestrator/models/character.py`.

```python
class AbilityScores(BaseModel):
    strength: int = 10
    dexterity: int = 10
    constitution: int = 10
    intelligence: int = 10
    wisdom: int = 10
    charisma: int = 10

class CharacterState(BaseModel):
    name: str
    race: Race                    # str enum: "human", "elf", etc.
    dnd_class: DndClass           # str enum: "fighter", "wizard", etc.
    level: int = 1
    experience_points: int = 0
    ability_scores: AbilityScores
    max_hp: int
    current_hp: int
    temp_hp: int = 0
    hit_dice_remaining: int = 1
    base_ac: int = 10
    speed_feet: int = 30
    initiative_bonus: int = 0
    death_save_successes: int = 0
    death_save_failures: int = 0
    saving_throw_proficiencies: list[Ability]
    skill_proficiencies: list[Skill]
    skill_expertise: list[Skill]
    armor_proficiencies: list[ArmorCategory]
    weapon_proficiencies: list[str]
    conditions: list[Condition]
    spell_slots: dict[int, int]       # { spell_level: remaining_slots }
    spell_slots_max: dict[int, int]   # { spell_level: max_slots }
    alignment: str = ""
    backstory: str = ""
```

### GameState

Defined in `orchestrator/models/game_state.py`.

```python
class GameState(BaseModel):
    version: int = 1
    timestamp: float
    character: CharacterState
    location: LocationState
    narrative: NarrativeState
    combat: CombatState | None = None
    inventory: list[ItemState]
    equipment: dict[EquipmentSlot, ItemState | None]

class LocationState(BaseModel):
    location_id: str
    location_name: str
    position_x: int
    position_y: int
    map_type: str           # "tavern", "dungeon", "overworld"

class NarrativeState(BaseModel):
    dm_archetype: DmArchetype   # "storyteller", "taskmaster", "trickster", "historian", "guide"
    history: list[dict]
    current_narration: str
    current_choices: list[str]
    turn_number: int

class CombatState(BaseModel):
    active: bool = False
    combatants: list[CombatantState]
    current_turn_index: int
    round_number: int

class CombatantState(BaseModel):
    combatant_id: str
    name: str
    is_player: bool
    current_hp: int
    max_hp: int
    armor_class: int
    position_x: int
    position_y: int
    initiative: int
    conditions: list[Condition]

class ItemState(BaseModel):
    slug: str
    name: str
    quantity: int = 1
    weight: float = 0.0
    properties: dict[str, Any]
```

### Enums (Python)

Defined in `orchestrator/models/enums.py`. All use `(str, Enum)` for clean lowercase JSON serialization.

- **Race** (6 in orchestrator, 9 in client): "human", "elf", "dwarf", "halfling", "half_orc", "gnome"
  - Note: The orchestrator enums have not yet been updated to include Dragonborn, Half-Elf, and Tiefling. The GDScript client has all 9.
- **DndClass** (6 in orchestrator, 12 in client): "fighter", "wizard", "rogue", "cleric", "ranger", "paladin"
  - Note: The orchestrator enums have not yet been updated to include Barbarian, Bard, Druid, Monk, Sorcerer, and Warlock. The GDScript client has all 12.
- **Ability** (6): "strength" through "charisma"
- **Skill** (18): "acrobatics" through "survival"
- **Condition** (14): "blinded" through "unconscious"
- **ArmorCategory** (4): "light", "medium", "heavy", "shields"
- **DamageType** (13): "slashing" through "psychic"
- **DmArchetype** (5): "storyteller", "taskmaster", "trickster", "historian", "guide"
- **ActionType** (9): "move", "attack", "speak", "use_item", "cast_spell", "interact", "rest", "look", "custom"
- **EquipmentSlot** (11): "head", "body", "cloak", "gloves", "boots", "ring_1", "ring_2", "amulet", "main_hand", "off_hand", "belt"

### Equipment Slot Enum

```python
class EquipmentSlot(str, Enum):
    HEAD = "head"
    BODY = "body"
    CLOAK = "cloak"
    GLOVES = "gloves"
    BOOTS = "boots"
    RING_1 = "ring_1"
    RING_2 = "ring_2"
    AMULET = "amulet"
    MAIN_HAND = "main_hand"
    OFF_HAND = "off_hand"
    BELT = "belt"
```

## Party / Companion Data Model (Planned)

When the party system is implemented, the game state will expand to include:

```json
{
  "party": {
    "members": [
      { /* CharacterState for player */ },
      { /* CharacterState for companion 1 */ },
      { /* CharacterState for companion 2 */ },
      { /* CharacterState for companion 3 */ }
    ],
    "max_size": 4,
    "formation": "default"
  }
}
```

Companions will use the same `CharacterState` / `CharacterData` model as the player character. NPCs being recruited will have their monster stat block converted to a full character sheet.

## Design Principles

- **Orchestrator is authoritative** — it maintains the canonical game state; the client only reads and renders
- **Client is a dumb renderer** — it reads JSON and draws pixels, never modifying game state
- **snake_case everywhere** — both GDScript and Python use snake_case field names
- **Schemas evolve** — these are current shapes, refined during development
- **Enum serialization** — GDScript uses integer enum values; Python uses lowercase string enum values

## Source Files

- `game/src/character_data.gd` — Client-side character data Resource with all enums and data tables
- `game/src/game_state_serializer.gd` — Client-side save/load serialization
- `orchestrator/models/game_state.py` — Orchestrator game state Pydantic models
- `orchestrator/models/character.py` — Orchestrator character state Pydantic model
- `orchestrator/models/enums.py` — Orchestrator enum definitions and constants
