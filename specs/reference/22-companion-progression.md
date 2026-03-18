# 22 — Companion Progression

## Overview

When an NPC is recruited into the party, their simple stat block (from `npc_profiles.json` or `dnd_monsters.json`) converts into a full `CharacterData` resource. Companions then level up independently using D&D 5e rules, with XP tracked per character.

**Status: Planned**

---

## Stat Block to Character Sheet Conversion

### When It Happens

Conversion occurs at the moment of recruitment. The orchestrator reads the NPC's stat block and creates a new `CharacterData` instance.

### Mapping Rules

The NPC stat block format (shared with `dnd_monsters.json`) maps to `CharacterData` fields as follows:

| Stat Block Field | CharacterData Field | Notes |
|---|---|---|
| `str` | `strength` | Direct copy |
| `dex` | `dexterity` | Direct copy |
| `con` | `constitution` | Direct copy |
| `int` | `intelligence` | Direct copy |
| `wis` | `wisdom` | Direct copy |
| `cha` | `charisma` | Direct copy |
| `max_hp` | `max_hp`, `current_hp` | Both set to `max_hp` (recruited at full health) |
| `ac` | `base_ac` | Direct copy. Equipment-based AC replaces this later when the companion equips armor. |
| `speed` | `speed_feet` | Direct copy. Default 30 if absent. |
| `cr` | (used for level estimate) | See level assignment below |

### Race Assignment

The NPC profile's `race` field maps to a `CharacterData.Race` enum value:

```gdscript
# Mapping from profile string to Race enum
var race_map: Dictionary = {
    "human": CharacterData.Race.HUMAN,
    "elf": CharacterData.Race.ELF,
    "dwarf": CharacterData.Race.DWARF,
    "halfling": CharacterData.Race.HALFLING,
    "half_orc": CharacterData.Race.HALF_ORC,
    "gnome": CharacterData.Race.GNOME,
    "dragonborn": CharacterData.Race.DRAGONBORN,
    "half_elf": CharacterData.Race.HALF_ELF,
    "tiefling": CharacterData.Race.TIEFLING,
}
```

If the NPC's race is not in the map (e.g., a goblin), default to `HUMAN` for mechanical purposes. Race ability bonuses are **not** applied during conversion -- the NPC's stat block already represents their final scores.

### Initial Level

Companions start at **level 0** -- no class. They have ability scores, HP, and AC from their stat block, but no class features, saving throw proficiencies, or skill proficiencies beyond what the DM assigns narratively.

The `level` field in `CharacterData` is set to `0` until the companion earns their first XP and gains a class.

### Conversion Example

Old Tom's NPC profile stat block:
```json
{
  "str": 14, "dex": 10, "con": 13,
  "int": 10, "wis": 12, "cha": 11,
  "max_hp": 15, "ac": 12, "speed": 30
}
```

Resulting `CharacterData`:
```
character_name = "Old Tom"
race = Race.HUMAN
dnd_class = (unset until first XP)
level = 0
experience_points = 0
strength = 14
dexterity = 10
constitution = 13
intelligence = 10
wisdom = 12
charisma = 11
max_hp = 15
current_hp = 15
base_ac = 12
speed_feet = 30
```

---

## First Class Assignment

### When It Triggers

When a companion earns their **first XP** (from any source -- combat, quest, exploration), they gain level 1 in a player class. This represents the companion discovering their calling through adventure.

### Class Selection

Class assignment uses a priority system:

1. **`class_predisposition` field** -- If the NPC profile specifies a preferred class, use it. This takes absolute priority.
2. **Player choice** -- If no predisposition is set, the DM presents 2-3 class options to the player based on the companion's stats. The player chooses.
3. **Stat-based inference** -- If automated (e.g., during playtest), the highest ability score determines class:

| Highest Ability Score | Assigned Class |
|---|---|
| STR (sole highest or tied with CON) | Fighter |
| DEX (sole highest) | Rogue |
| CON (sole highest) | Barbarian |
| INT (sole highest) | Wizard |
| WIS (sole highest) | Cleric |
| CHA (sole highest) | Bard |
| STR + CHA both high | Paladin |
| DEX + WIS both high | Ranger |
| WIS + CON both high | Druid |
| DEX + INT both high | Rogue |
| CHA + CON both high | Sorcerer |
| All scores equal | Fighter (default) |

### Class Assignment Flow

```
Companion earns first XP
  -> DM narrates the moment:
     "Old Tom hefts his sword with renewed purpose.
      The old instincts are coming back."
  -> If class_predisposition exists:
     -> Assign that class at level 1
  -> Else:
     -> DM presents options:
        "Tom's fighting experience suggests Fighter,
         but his wisdom could make him a Ranger.
         What path does he take?"
     -> Player selects class
  -> Initialize class features via CharacterData.initialize_class_features()
  -> Update HP to class-based calculation:
     max_hp = hit_die + CON modifier (level 1 formula)
  -> Apply saving throw and skill proficiencies from CLASS_DATA
```

### HP on Class Assignment

When a companion gains their first class level, their HP is recalculated using the standard formula:

```
Level 1 HP = class hit_die + CON modifier
```

This **replaces** the stat block HP. If the stat block HP was higher (e.g., a tough NPC with 15 HP becoming a Wizard with hit die 6), the companion keeps the higher value. HP never decreases on class assignment.

```gdscript
var class_hp: int = CLASS_DATA[dnd_class]["hit_die"] + get_modifier(Ability.CONSTITUTION)
max_hp = maxi(max_hp, class_hp)
current_hp = max_hp
```

---

## XP Tracking

### Per-Character XP

Each character in the party tracks XP independently. There is no shared XP pool.

```json
{
  "party": [
    {"id": "player", "xp": 450},
    {"id": "old_tom", "xp": 300},
    {"id": "elara", "xp": 150}
  ]
}
```

### XP Sources and Distribution

| Source | Distribution Rule |
|---|---|
| **Combat XP** | Total monster XP divided equally among **surviving party members** who participated in the encounter. Dead/unconscious members do not receive combat XP. |
| **Quest XP** | Given to **all party members present** when the quest is completed. Companions left at camp do not receive quest XP. |
| **Exploration XP** | Given to **all active party members**. Discovering a secret room, solving a puzzle, etc. |
| **Roleplay XP** | Given to the **specific character** who performed the noteworthy action. If Old Tom convinces a guard to let the party pass, Old Tom gets the roleplay XP. |

### Combat XP Example

Party of 3 (player + 2 companions) defeats 3 goblins (50 XP each = 150 XP total):
- Each surviving member receives: `150 / 3 = 50 XP`

If one companion was downed during the fight:
- Each surviving member receives: `150 / 2 = 75 XP`
- Downed companion receives: `0 XP`

---

## Leveling Up

### XP Thresholds

Companions use the same XP threshold table as the player character, defined in `CharacterData.XP_THRESHOLDS`:

```
Level 1:  0 XP
Level 2:  300 XP
Level 3:  900 XP
Level 4:  2,700 XP
Level 5:  6,500 XP
...
Level 20: 355,000 XP
```

### Level-Up Flow for Companions

1. **XP threshold reached** -- The orchestrator detects that a companion's XP has crossed the next level threshold.
2. **DM narrates** -- *"Old Tom's movements grow more confident. Years of dormant skill resurface."*
3. **Level increments** -- `level += 1`
4. **HP increases** -- Roll hit die (or use average: `hit_die / 2 + 1`) + CON modifier. Minimum 1 HP gained per level.
5. **Class features** -- New features for the level are unlocked via `initialize_class_features()`.
6. **Player choices** -- If the level grants choices (ASI at level 4, subclass at level 3, etc.), the DM presents options and the player decides for the companion.
7. **Spell slots** -- Caster companions gain spell slots per `CLASS_DATA` spell slot tables.

### Companion Level-Up vs Player Level-Up

Companion level-ups are identical to player level-ups mechanically. The only difference is narrative framing -- the DM describes the companion's growth in terms of their personality and backstory rather than generic mechanics.

---

## Equipment

### Shared Inventory

The party shares a single inventory pool. Any party member can equip any item they are proficient with.

### Equipment Slots

Companions have the same equipment slots as the player character:

- **Weapon** (main hand)
- **Off-hand** (shield or second weapon)
- **Armor** (body)
- **Head**
- **Hands** (gloves/gauntlets)
- **Feet** (boots)
- **Ring** (x2)
- **Neck** (amulet/necklace)

### Proficiency Restrictions

Companions can only equip items they are proficient with (determined by their class):

- A Fighter companion can equip heavy armor. A Wizard cannot.
- A Rogue can equip light armor and finesse weapons. Not heavy armor or martial weapons outside their proficiency list.
- Proficiencies come from `CLASS_DATA[dnd_class]["armor_proficiencies"]` and `weapon_proficiencies`.

### Equipment on Recruitment

When an NPC is recruited, they keep whatever equipment they had as an NPC. If the NPC profile does not specify equipment, they start with:

- A simple weapon appropriate to their stat block (highest melee stat determines weapon type)
- Common clothes (no armor unless their AC suggests it)

Equipment is added to the shared inventory and auto-equipped on the companion.

---

## Class Restrictions and Predispositions

### Narrative Predispositions

Some NPCs have backgrounds that strongly suggest a class. The `class_predisposition` field in NPC profiles captures this:

| NPC Type | Predisposition | Reasoning |
|---|---|---|
| Town guard | `fighter` | Trained in martial combat |
| Temple acolyte | `cleric` | Devoted to a deity, knows sacred rites |
| Scholar/librarian | `wizard` | Studied arcane texts |
| Street urchin | `rogue` | Learned to survive through stealth and cunning |
| Wilderness hunter | `ranger` | Skilled tracker and bowman |
| Tavern brawler | `barbarian` | Fights with raw fury, not technique |
| Traveling performer | `bard` | Entertains with music and stories |
| Hermit herbalist | `druid` | Connected to nature |
| Noble's bodyguard | `paladin` | Sworn oath of protection |
| Mysterious stranger | (none) | Player chooses -- could be anything |

### No Multi-Classing

Companions cannot multi-class. Their class is set at first XP and remains fixed for the rest of the game. This simplifies the system and avoids combinatorial complexity with companion AI.

### All 12 Classes Available

Companions can be any of the 12 classes defined in `CharacterData.DndClass`:

```
FIGHTER, WIZARD, ROGUE, CLERIC, RANGER, PALADIN,
BARBARIAN, BARD, DRUID, MONK, SORCERER, WARLOCK
```

Note: The orchestrator's `enums.py` currently defines only 6 classes (Fighter, Wizard, Rogue, Cleric, Ranger, Paladin). The remaining 6 (Barbarian, Bard, Druid, Monk, Sorcerer, Warlock) exist in the GDScript `CharacterData` but need to be added to the Python enums for full companion support. **Status: Partially Implemented** (GDScript has all 12, Python has 6).
