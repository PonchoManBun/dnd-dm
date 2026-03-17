# Character Sheet Spec

## Overview

The character sheet is the canonical representation of a player character. It flows as JSON between the Python orchestrator (source of truth) and the Godot client (renderer). Godot never mutates the character sheet directly; it receives the full state from the orchestrator on every update and renders it as a toggleable overlay (C hotkey).

This spec defines the JSON schema, the field mapping between GDScript and Python, all enum tables, derived stat formulas, spell slot tracking, encumbrance rules, and how Godot renders the sheet.

---

## JSON Schema

The orchestrator sends this JSON to Godot via `GET /state` (inside `player` field) and accepts it via `POST /character/create`. All fields are present on every response; Godot never has to handle missing keys.

```json
{
  "identity": {
    "name": "Torvin Ironfist",
    "race": "dwarf",
    "dnd_class": "fighter",
    "level": 3,
    "experience_points": 900,
    "xp_to_next_level": 2700,
    "proficiency_bonus": 2
  },
  "ability_scores": {
    "strength":     { "score": 16, "modifier": 3 },
    "dexterity":    { "score": 12, "modifier": 1 },
    "constitution": { "score": 14, "modifier": 2 },
    "intelligence": { "score": 10, "modifier": 0 },
    "wisdom":       { "score": 13, "modifier": 1 },
    "charisma":     { "score":  8, "modifier": -1 }
  },
  "hit_points": {
    "current": 28,
    "max": 34,
    "temp": 0,
    "hit_dice_total": 3,
    "hit_dice_remaining": 3,
    "hit_die_size": 10
  },
  "death_saves": {
    "successes": 0,
    "failures": 0
  },
  "combat": {
    "armor_class": 18,
    "initiative_bonus": 1,
    "speed_feet": 25,
    "speed_tiles": 5,
    "passive_perception": 13
  },
  "saving_throws": {
    "strength":     { "modifier": 5, "proficient": true },
    "dexterity":    { "modifier": 1, "proficient": false },
    "constitution": { "modifier": 4, "proficient": true },
    "intelligence": { "modifier": 0, "proficient": false },
    "wisdom":       { "modifier": 1, "proficient": false },
    "charisma":     { "modifier": -1, "proficient": false }
  },
  "skills": {
    "acrobatics":       { "modifier": 1, "proficient": false, "expertise": false, "ability": "dexterity" },
    "animal_handling":  { "modifier": 1, "proficient": false, "expertise": false, "ability": "wisdom" },
    "arcana":           { "modifier": 0, "proficient": false, "expertise": false, "ability": "intelligence" },
    "athletics":        { "modifier": 5, "proficient": true,  "expertise": false, "ability": "strength" },
    "deception":        { "modifier": -1, "proficient": false, "expertise": false, "ability": "charisma" },
    "history":          { "modifier": 0, "proficient": false, "expertise": false, "ability": "intelligence" },
    "insight":          { "modifier": 1, "proficient": false, "expertise": false, "ability": "wisdom" },
    "intimidation":     { "modifier": 1, "proficient": true,  "expertise": false, "ability": "charisma" },
    "investigation":    { "modifier": 0, "proficient": false, "expertise": false, "ability": "intelligence" },
    "medicine":         { "modifier": 1, "proficient": false, "expertise": false, "ability": "wisdom" },
    "nature":           { "modifier": 0, "proficient": false, "expertise": false, "ability": "intelligence" },
    "perception":       { "modifier": 3, "proficient": true,  "expertise": false, "ability": "wisdom" },
    "performance":      { "modifier": -1, "proficient": false, "expertise": false, "ability": "charisma" },
    "persuasion":       { "modifier": -1, "proficient": false, "expertise": false, "ability": "charisma" },
    "religion":         { "modifier": 0, "proficient": false, "expertise": false, "ability": "intelligence" },
    "sleight_of_hand":  { "modifier": 1, "proficient": false, "expertise": false, "ability": "dexterity" },
    "stealth":          { "modifier": 1, "proficient": false, "expertise": false, "ability": "dexterity" },
    "survival":         { "modifier": 1, "proficient": false, "expertise": false, "ability": "wisdom" }
  },
  "equipment": {
    "head":      null,
    "body":      { "slug": "chain_mail", "name": "Chain Mail", "ac_base": 16, "armor_category": "heavy", "weight": 55.0, "properties": [] },
    "cloak":     null,
    "gloves":    null,
    "boots":     null,
    "ring_1":    null,
    "ring_2":    null,
    "amulet":    null,
    "main_hand": { "slug": "longsword", "name": "Longsword", "damage_dice": "1d8", "damage_type": "slashing", "weight": 3.0, "properties": ["versatile"] },
    "off_hand":  { "slug": "shield", "name": "Shield", "ac_bonus": 2, "weight": 6.0, "properties": [] },
    "belt":      null
  },
  "inventory": [
    { "slug": "healing_potion", "name": "Potion of Healing", "quantity": 2, "weight": 0.5 },
    { "slug": "rations", "name": "Rations (1 day)", "quantity": 5, "weight": 2.0 }
  ],
  "encumbrance": {
    "current_weight": 72.0,
    "carry_capacity": 240.0,
    "encumbered": false
  },
  "spellcasting": null,
  "conditions": [],
  "armor_proficiencies": ["light", "medium", "heavy", "shields"],
  "weapon_proficiencies": ["simple", "martial"]
}
```

### Spellcasting block (present for casters, `null` for non-casters)

```json
{
  "spellcasting": {
    "ability": "wisdom",
    "spell_save_dc": 13,
    "spell_attack_bonus": 5,
    "cantrips_known": ["sacred_flame", "guidance", "light"],
    "spell_slots": {
      "1": { "total": 4, "used": 1 },
      "2": { "total": 3, "used": 0 },
      "3": { "total": 0, "used": 0 },
      "4": { "total": 0, "used": 0 },
      "5": { "total": 0, "used": 0 },
      "6": { "total": 0, "used": 0 },
      "7": { "total": 0, "used": 0 },
      "8": { "total": 0, "used": 0 },
      "9": { "total": 0, "used": 0 }
    },
    "prepared_spells": [
      { "slug": "cure_wounds", "name": "Cure Wounds", "level": 1, "school": "evocation" },
      { "slug": "bless", "name": "Bless", "level": 1, "school": "enchantment" },
      { "slug": "spiritual_weapon", "name": "Spiritual Weapon", "level": 2, "school": "evocation" }
    ],
    "max_prepared": 4,
    "spellbook": null
  }
}
```

For Wizards, the `spellbook` field is an array of all spells in the spellbook (a superset of `prepared_spells`). Losing the spellbook inventory item removes access to `prepared_spells` until recovered.

```json
{
  "spellbook": [
    { "slug": "magic_missile", "name": "Magic Missile", "level": 1, "school": "evocation" },
    { "slug": "shield", "name": "Shield", "level": 1, "school": "abjuration" },
    { "slug": "detect_magic", "name": "Detect Magic", "level": 1, "school": "divination" }
  ]
}
```

---

## Field Mapping: GDScript CharacterData to Python Pydantic

The orchestrator stores the authoritative character state in a Pydantic model. Godot stores a mirror in `CharacterData` resource. The serializer (`GameStateSerializer`) bridges the two via JSON. This table maps every field.

### Identity Fields

| JSON field | GDScript field | Python field | Type | Notes |
|---|---|---|---|---|
| `identity.name` | `CharacterData.character_name` | `identity.name` | `str` | Display name |
| `identity.race` | `CharacterData.race` | `identity.race` | `Race` enum | String in JSON, enum in code |
| `identity.dnd_class` | `CharacterData.dnd_class` | `identity.dnd_class` | `DndClass` enum | String in JSON, enum in code |
| `identity.level` | `CharacterData.level` | `identity.level` | `int` | 1-20 |
| `identity.experience_points` | `CharacterData.experience_points` | `identity.experience_points` | `int` | Cumulative XP |
| `identity.xp_to_next_level` | Looked up from `XP_THRESHOLDS` | `identity.xp_to_next_level` | `int` | Derived; next threshold |
| `identity.proficiency_bonus` | `CharacterData.get_proficiency_bonus()` | `identity.proficiency_bonus` | `int` | Derived; `2 + (level-1) // 4` |

### Ability Scores

| JSON field | GDScript field | Python field | Type |
|---|---|---|---|
| `ability_scores.strength.score` | `CharacterData.strength` | `ability_scores.strength.score` | `int` |
| `ability_scores.strength.modifier` | `CharacterData.get_modifier(STRENGTH)` | `ability_scores.strength.modifier` | `int` |
| _(same pattern for all 6 abilities)_ | | | |

### Hit Points

| JSON field | GDScript field | Python field | Type | Notes |
|---|---|---|---|---|
| `hit_points.current` | `CharacterData.current_hp` | `hit_points.current` | `int` | |
| `hit_points.max` | `CharacterData.max_hp` | `hit_points.max` | `int` | |
| `hit_points.temp` | `CharacterData.temp_hp` | `hit_points.temp` | `int` | Temporary HP |
| `hit_points.hit_dice_total` | `CharacterData.level` | `hit_points.hit_dice_total` | `int` | Equal to level |
| `hit_points.hit_dice_remaining` | `CharacterData.hit_dice_remaining` | `hit_points.hit_dice_remaining` | `int` | Spent during short rests |
| `hit_points.hit_die_size` | `CLASS_DATA[dnd_class]["hit_die"]` | `hit_points.hit_die_size` | `int` | d6/d8/d10 |

### Death Saves

| JSON field | GDScript field | Python field | Type |
|---|---|---|---|
| `death_saves.successes` | `CharacterData.death_save_successes` | `death_saves.successes` | `int` |
| `death_saves.failures` | `CharacterData.death_save_failures` | `death_saves.failures` | `int` |

### Combat

| JSON field | GDScript field | Python field | Type | Notes |
|---|---|---|---|---|
| `combat.armor_class` | `CharacterData.base_ac` | `combat.armor_class` | `int` | Derived (see formulas) |
| `combat.initiative_bonus` | `CharacterData.initiative_bonus` + DEX mod | `combat.initiative_bonus` | `int` | Derived |
| `combat.speed_feet` | `CharacterData.speed_feet` | `combat.speed_feet` | `int` | |
| `combat.speed_tiles` | `CharacterData.get_movement_tiles()` | `combat.speed_tiles` | `int` | `speed_feet / 5` |
| `combat.passive_perception` | Derived | `combat.passive_perception` | `int` | Derived |

---

## Enum Mapping Tables

Phase 1 GDScript stores enums as integer ordinals. The orchestrator JSON uses lowercase string keys for readability. Both sides must agree on the mapping.

### Race (6 values)

| Ordinal | GDScript | JSON string | Python |
|---|---|---|---|
| 0 | `Race.HUMAN` | `"human"` | `Race.HUMAN` |
| 1 | `Race.ELF` | `"elf"` | `Race.ELF` |
| 2 | `Race.DWARF` | `"dwarf"` | `Race.DWARF` |
| 3 | `Race.HALFLING` | `"halfling"` | `Race.HALFLING` |
| 4 | `Race.HALF_ORC` | `"half_orc"` | `Race.HALF_ORC` |
| 5 | `Race.GNOME` | `"gnome"` | `Race.GNOME` |

### DndClass (6 values)

| Ordinal | GDScript | JSON string | Python |
|---|---|---|---|
| 0 | `DndClass.FIGHTER` | `"fighter"` | `DndClass.FIGHTER` |
| 1 | `DndClass.WIZARD` | `"wizard"` | `DndClass.WIZARD` |
| 2 | `DndClass.ROGUE` | `"rogue"` | `DndClass.ROGUE` |
| 3 | `DndClass.CLERIC` | `"cleric"` | `DndClass.CLERIC` |
| 4 | `DndClass.RANGER` | `"ranger"` | `DndClass.RANGER` |
| 5 | `DndClass.PALADIN` | `"paladin"` | `DndClass.PALADIN` |

### Ability (6 values)

| Ordinal | GDScript | JSON string | Python |
|---|---|---|---|
| 0 | `Ability.STRENGTH` | `"strength"` | `Ability.STRENGTH` |
| 1 | `Ability.DEXTERITY` | `"dexterity"` | `Ability.DEXTERITY` |
| 2 | `Ability.CONSTITUTION` | `"constitution"` | `Ability.CONSTITUTION` |
| 3 | `Ability.INTELLIGENCE` | `"intelligence"` | `Ability.INTELLIGENCE` |
| 4 | `Ability.WISDOM` | `"wisdom"` | `Ability.WISDOM` |
| 5 | `Ability.CHARISMA` | `"charisma"` | `Ability.CHARISMA` |

### Skill (18 values)

| Ordinal | GDScript | JSON string | Governing Ability |
|---|---|---|---|
| 0 | `Skill.ACROBATICS` | `"acrobatics"` | DEX |
| 1 | `Skill.ANIMAL_HANDLING` | `"animal_handling"` | WIS |
| 2 | `Skill.ARCANA` | `"arcana"` | INT |
| 3 | `Skill.ATHLETICS` | `"athletics"` | STR |
| 4 | `Skill.DECEPTION` | `"deception"` | CHA |
| 5 | `Skill.HISTORY` | `"history"` | INT |
| 6 | `Skill.INSIGHT` | `"insight"` | WIS |
| 7 | `Skill.INTIMIDATION` | `"intimidation"` | CHA |
| 8 | `Skill.INVESTIGATION` | `"investigation"` | INT |
| 9 | `Skill.MEDICINE` | `"medicine"` | WIS |
| 10 | `Skill.NATURE` | `"nature"` | INT |
| 11 | `Skill.PERCEPTION` | `"perception"` | WIS |
| 12 | `Skill.PERFORMANCE` | `"performance"` | CHA |
| 13 | `Skill.PERSUASION` | `"persuasion"` | CHA |
| 14 | `Skill.RELIGION` | `"religion"` | INT |
| 15 | `Skill.SLEIGHT_OF_HAND` | `"sleight_of_hand"` | DEX |
| 16 | `Skill.STEALTH` | `"stealth"` | DEX |
| 17 | `Skill.SURVIVAL` | `"survival"` | WIS |

### Condition (14 values)

| Ordinal | GDScript | JSON string | Key Mechanical Effect |
|---|---|---|---|
| 0 | `Condition.BLINDED` | `"blinded"` | Adv on attacks against, disadv on own attacks |
| 1 | `Condition.CHARMED` | `"charmed"` | Cannot attack charmer |
| 2 | `Condition.DEAFENED` | `"deafened"` | Cannot hear, auto-fail hearing checks |
| 3 | `Condition.FRIGHTENED` | `"frightened"` | Disadv on attacks while source visible |
| 4 | `Condition.GRAPPLED` | `"grappled"` | Speed 0 |
| 5 | `Condition.INCAPACITATED` | `"incapacitated"` | Cannot take actions or reactions |
| 6 | `Condition.INVISIBLE` | `"invisible"` | Adv on own attacks, disadv on attacks against |
| 7 | `Condition.PARALYZED` | `"paralyzed"` | Auto-fail STR/DEX saves, adv on attacks against |
| 8 | `Condition.PETRIFIED` | `"petrified"` | Turned to stone, resist all damage |
| 9 | `Condition.POISONED` | `"poisoned"` | Disadv on attacks and ability checks |
| 10 | `Condition.PRONE` | `"prone"` | Disadv on attacks, adv on melee attacks against |
| 11 | `Condition.RESTRAINED` | `"restrained"` | Speed 0, disadv on DEX saves |
| 12 | `Condition.STUNNED` | `"stunned"` | Auto-fail STR/DEX saves, adv on attacks against |
| 13 | `Condition.UNCONSCIOUS` | `"unconscious"` | Falls prone, auto-fail STR/DEX saves, auto-crit in melee |

### ArmorCategory (4 values)

| Ordinal | GDScript | JSON string | Python |
|---|---|---|---|
| 0 | `ArmorCategory.LIGHT` | `"light"` | `ArmorCategory.LIGHT` |
| 1 | `ArmorCategory.MEDIUM` | `"medium"` | `ArmorCategory.MEDIUM` |
| 2 | `ArmorCategory.HEAVY` | `"heavy"` | `ArmorCategory.HEAVY` |
| 3 | `ArmorCategory.SHIELDS` | `"shields"` | `ArmorCategory.SHIELDS` |

---

## Equipment Slots

Phase 1's `Equipment.gd` uses a roguelike-style slot system (UPPER_ARMOR, LOWER_ARMOR, MASK, etc.) that does not match D&D 5e. Phase 2 replaces it with the GDD-defined D&D equipment slots. The old `Equipment.Slot` enum is retired for player characters; monster equipment may retain the old system.

### Slot Definitions

| Slot key | JSON field | Description | Valid item types |
|---|---|---|---|
| `HEAD` | `equipment.head` | Helmets, circlets, headbands | Headwear, magical helms |
| `BODY` | `equipment.body` | Armor, robes, clothing | Light/medium/heavy armor |
| `CLOAK` | `equipment.cloak` | Cloaks, capes, mantles | Cloaks |
| `GLOVES` | `equipment.gloves` | Gauntlets, gloves, bracers | Handwear |
| `BOOTS` | `equipment.boots` | Boots, greaves, sandals | Footwear |
| `RING_1` | `equipment.ring_1` | Magical ring (slot 1) | Rings |
| `RING_2` | `equipment.ring_2` | Magical ring (slot 2) | Rings |
| `AMULET` | `equipment.amulet` | Necklaces, amulets, brooches | Neck items |
| `MAIN_HAND` | `equipment.main_hand` | Primary weapon | Weapons |
| `OFF_HAND` | `equipment.off_hand` | Shield, secondary weapon, torch | Shields, light weapons, tools |
| `BELT` | `equipment.belt` | Utility belt, potion bandolier | Belt items |

### Equipment Item JSON

Each equipped item is either `null` (empty slot) or an object:

```json
{
  "slug": "chain_mail",
  "name": "Chain Mail",
  "ac_base": 16,
  "armor_category": "heavy",
  "damage_dice": null,
  "damage_type": null,
  "ac_bonus": 0,
  "weight": 55.0,
  "properties": ["stealth_disadvantage"],
  "magical": false,
  "attunement_required": false,
  "description": "Made of interlocking metal rings."
}
```

Weapon example:

```json
{
  "slug": "longsword",
  "name": "Longsword",
  "ac_base": null,
  "armor_category": null,
  "damage_dice": "1d8",
  "damage_type": "slashing",
  "ac_bonus": 0,
  "weight": 3.0,
  "properties": ["versatile"],
  "magical": false,
  "attunement_required": false,
  "description": "A martial weapon with a long blade."
}
```

### Two-Handed / Versatile Rules

- **Two-handed weapons**: Occupy `main_hand`; `off_hand` must be `null`. Enforced by orchestrator.
- **Versatile weapons**: In `main_hand` with `off_hand` empty, use the higher damage die (e.g., 1d10 for longsword). When `off_hand` is occupied, use the lower die (1d8).
- **Dual wielding**: Light weapons in both hands. Bonus action attack with `off_hand`, no ability modifier on damage.

---

## Derived Stats: Formulas

The orchestrator computes all derived stats. Godot receives pre-computed values and displays them. These formulas match the existing `RulesEngine.gd` and `CharacterData.gd` implementations.

### Ability Modifier

```
modifier = floor((score - 10) / 2)
```

Source: `CharacterData.ability_modifier(score)` (line 269-270).

### Proficiency Bonus

```
proficiency_bonus = 2 + floor((level - 1) / 4)
```

| Level | Bonus |
|---|---|
| 1-4 | +2 |
| 5-8 | +3 |
| 9-12 | +4 |
| 13-16 | +5 |
| 17-20 | +6 |

Source: `CharacterData.get_proficiency_bonus()` (line 277-278).

### Hit Points (Max)

```
max_hp = hit_die_max + CON_mod                          # Level 1
       + sum(max(1, floor(hit_die/2) + 1 + CON_mod))    # Levels 2+
```

Example (Level 3 Fighter, CON 14, hit die d10):
- Level 1: 10 + 2 = 12
- Level 2: max(1, 5 + 1 + 2) = 8
- Level 3: max(1, 5 + 1 + 2) = 8
- Total: 12 + 8 + 8 = 28

Source: `CharacterData.get_max_hp_for_level()` (lines 285-292).

### Armor Class

```
No armor:    AC = 10 + DEX_mod
Light armor: AC = armor_base + DEX_mod
Medium armor: AC = armor_base + min(DEX_mod, 2)
Heavy armor: AC = armor_base
Shield:      AC += 2
```

Source: `RulesEngine.calculate_ac()` (lines 268-294).

### Initiative

```
initiative_bonus = DEX_mod + initiative_bonus_misc
```

The `initiative_bonus` field on `CharacterData` stores miscellaneous bonuses (e.g., from feats). The total is `DEX modifier + that bonus`. The initiative roll itself is `d20 + initiative_bonus`.

Source: `RulesEngine.initiative_roll()` (lines 255-258).

### Passive Perception

```
passive_perception = 10 + WIS_mod + (proficiency_bonus if proficient_in_perception else 0) + (proficiency_bonus if expertise_in_perception else 0)
```

Expertise doubles the proficiency bonus (added twice total). Disadvantage subtracts 5; advantage adds 5 (applied by orchestrator based on conditions).

### Saving Throw Modifier

```
save_mod = ability_mod + (proficiency_bonus if proficient else 0)
```

Each class grants proficiency in exactly two saving throws:

| Class | Proficient Saves |
|---|---|
| Fighter | STR, CON |
| Wizard | INT, WIS |
| Rogue | DEX, INT |
| Cleric | WIS, CHA |
| Ranger | STR, DEX |
| Paladin | WIS, CHA |

Source: `CLASS_DATA` in `CharacterData.gd` (lines 190-244).

### Skill Check Modifier

```
skill_mod = ability_mod + (proficiency_bonus * multiplier)
  where multiplier = 2 if expertise, 1 if proficient, 0 otherwise
```

Source: `RulesEngine.ability_check()` (lines 226-251).

### Spell Save DC (casters only)

```
spell_save_dc = 8 + proficiency_bonus + spellcasting_ability_mod
```

### Spell Attack Bonus (casters only)

```
spell_attack_bonus = proficiency_bonus + spellcasting_ability_mod
```

### Spellcasting Ability by Class

| Class | Spellcasting Ability |
|---|---|
| Wizard | Intelligence |
| Cleric | Wisdom |
| Paladin | Charisma |
| Ranger | Wisdom |
| Fighter | N/A (non-caster) |
| Rogue | N/A (non-caster) |

---

## Spell Slots

Spell slots follow the SRD table. Paladins and Rangers are half-casters (gain slots at level 2, half progression). Wizard and Cleric are full casters.

### Full Caster Slot Table (Wizard, Cleric)

| Level | 1st | 2nd | 3rd | 4th | 5th | 6th | 7th | 8th | 9th |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 2 | - | - | - | - | - | - | - | - |
| 2 | 3 | - | - | - | - | - | - | - | - |
| 3 | 4 | 2 | - | - | - | - | - | - | - |
| 4 | 4 | 3 | - | - | - | - | - | - | - |
| 5 | 4 | 3 | 2 | - | - | - | - | - | - |
| 6 | 4 | 3 | 3 | - | - | - | - | - | - |
| 7 | 4 | 3 | 3 | 1 | - | - | - | - | - |
| 8 | 4 | 3 | 3 | 2 | - | - | - | - | - |
| 9 | 4 | 3 | 3 | 3 | 1 | - | - | - | - |
| 10 | 4 | 3 | 3 | 3 | 2 | - | - | - | - |

### Half-Caster Slot Table (Paladin, Ranger)

Half-casters use their class level for slot progression, starting at level 2.

| Level | 1st | 2nd | 3rd | 4th | 5th |
|---|---|---|---|---|---|
| 2 | 2 | - | - | - | - |
| 3 | 3 | - | - | - | - |
| 4 | 3 | - | - | - | - |
| 5 | 4 | 2 | - | - | - |
| 6 | 4 | 2 | - | - | - |
| 7 | 4 | 3 | - | - | - |
| 8 | 4 | 3 | - | - | - |
| 9 | 4 | 3 | 2 | - | - |
| 10 | 4 | 3 | 2 | - | - |

### Max Prepared Spells

| Class | Formula |
|---|---|
| Wizard | `INT_mod + wizard_level` (min 1) |
| Cleric | `WIS_mod + cleric_level` (min 1) |
| Paladin | `CHA_mod + floor(paladin_level / 2)` (min 1) |
| Ranger | Per SRD table (level-based, not ability-based) |

### Slot Tracking

The orchestrator tracks `total` and `used` per spell level. Slots reset on long rest. The JSON always includes all 9 levels; unused levels have `total: 0, used: 0`.

### Cantrips

Cantrips are at-will (no slots consumed). The number known scales with level per class. Tracked in `cantrips_known` array.

### Wizard Spellbook

The Wizard's `spellbook` field lists all spells copied into the book. The `prepared_spells` subset is what the Wizard has memorized for the day. If the spellbook inventory item is lost, `prepared_spells` is locked until the book is recovered (orchestrator enforces this by checking inventory).

---

## Encumbrance

```
carry_capacity = STR_score * 15  (in pounds)
current_weight = sum of all inventory item weights + sum of all equipped item weights
encumbered = current_weight > carry_capacity
```

### Encumbrance Effects

| Threshold | Effect |
|---|---|
| `weight <= capacity` | No penalty |
| `weight > capacity` | Speed reduced by 10 feet, disadvantage on STR/DEX/CON ability checks, attack rolls, and saving throws |

The orchestrator computes `encumbrance.current_weight`, `encumbrance.carry_capacity`, and `encumbrance.encumbered` on every state update. Godot displays a warning indicator when encumbered.

---

## How Godot Renders the Sheet

### Overlay Behavior

- **Toggle**: Press `C` to open/close the character sheet overlay.
- **Layer**: Renders on a `CanvasLayer` above the game viewport but below modal dialogs.
- **Input**: While open, game input (WASD movement, combat) is blocked. The sheet consumes mouse clicks for tab switching and scrolling. Press `C` or `Escape` to close.
- **No mutation**: Godot reads JSON fields and populates UI nodes. It never writes back. All changes (equip, level up, rest) go through orchestrator API calls.

### Layout

The character sheet is a single `PanelContainer` divided into sections that map directly to the JSON structure:

```
+-----------------------------------------------+
|  [Name]  Level [N] [Race] [Class]              |
|  XP: [current] / [next]   Prof Bonus: +[N]    |
+-----------------------------------------------+
|  ABILITY SCORES (6 columns)                    |
|  STR  DEX  CON  INT  WIS  CHA                 |
|  [16] [12] [14] [10] [13] [8]                  |
|  +3   +1   +2   +0   +1   -1                  |
+-----------------------------------------------+
|  HP: [28/34]  Temp: [0]  AC: [18]              |
|  Init: +[1]   Speed: [25ft]  PP: [13]          |
|  Hit Dice: [3/3] d10                           |
+-----------------------------------------------+
|  SAVING THROWS         |  SKILLS               |
|  [*] STR  +5           |  [ ] Acrobatics +1    |
|  [ ] DEX  +1           |  [ ] Animal Hand. +1  |
|  [*] CON  +4           |  [ ] Arcana +0        |
|  [ ] INT  +0           |  [*] Athletics +5     |
|  [ ] WIS  +1           |  ...                  |
|  [ ] CHA  -1           |  (scrollable)         |
+-----------------------------------------------+
|  EQUIPMENT                                     |
|  Head: (empty)       Ring 1: (empty)           |
|  Body: Chain Mail    Ring 2: (empty)           |
|  Cloak: (empty)      Amulet: (empty)          |
|  Gloves: (empty)     Main: Longsword          |
|  Boots: (empty)      Off: Shield              |
|  Belt: (empty)                                 |
+-----------------------------------------------+
|  SPELLCASTING (if caster)                      |
|  Save DC: 13  Attack: +5  Ability: WIS         |
|  Slots: [1st: 3/4] [2nd: 3/3]                 |
|  Prepared: Cure Wounds, Bless, ...             |
+-----------------------------------------------+
|  INVENTORY                    Weight: 72/240   |
|  Potion of Healing x2                          |
|  Rations x5                                    |
+-----------------------------------------------+
|  CONDITIONS: (none)                            |
+-----------------------------------------------+
```

### Rendering Rules

1. **Ability scores**: Display score and modifier. Modifier formatted as `+N` or `-N`.
2. **Saving throws and skills**: Filled circle `[*]` for proficient, empty `[ ]` for not. Double circle or highlight for expertise.
3. **HP bar**: Visual bar showing `current / max`. Red when below 25%. Temp HP shown separately.
4. **Equipment slots**: Slot name and item name (or "empty"). Hovering shows item tooltip with stats.
5. **Spellcasting section**: Hidden entirely for Fighter and Rogue. Shown for Wizard, Cleric, Paladin, Ranger.
6. **Spell slots**: Visual pips (filled = available, empty = used). Grouped by level.
7. **Conditions**: Listed as tags/badges. Color-coded (red for severe like paralyzed/stunned, yellow for moderate like frightened/poisoned).
8. **Encumbrance**: Weight display turns red when encumbered. Shows `current / capacity`.
9. **Death saves**: Only shown when `current_hp == 0`. Three success pips, three failure pips.

### Scene Structure

```
CharacterSheet (CanvasLayer)
  +-- PanelContainer
        +-- VBoxContainer
              +-- IdentitySection (HBoxContainer)
              +-- AbilityScoreSection (HBoxContainer, 6 columns)
              +-- CombatSection (HBoxContainer)
              +-- HSplitContainer
              |     +-- SavingThrowList (VBoxContainer)
              |     +-- SkillList (VBoxContainer, scrollable)
              +-- EquipmentGrid (GridContainer, 2 columns)
              +-- SpellcastingSection (VBoxContainer, conditional visibility)
              +-- InventoryList (VBoxContainer, scrollable)
              +-- ConditionTags (HFlowContainer)
```

### Data Flow

1. Orchestrator sends `GET /state` response containing the full character JSON.
2. Godot parses the `player` field into a Dictionary.
3. `CharacterSheet.gd` calls `update_from_json(player_dict)` which walks the Dictionary and sets text/values on each UI node.
4. No `CharacterData` deserialization needed for display -- the JSON contains pre-computed derived stats (modifiers, AC, passive perception, spell save DC). Godot just reads and renders.
5. When the player performs an action that modifies the sheet (equip item, level up, long rest), Godot sends the action to the orchestrator via `POST /action`, receives an updated state, and re-renders.

---

## Python Pydantic Models

The orchestrator defines these models. They serialize directly to the JSON schema above.

```python
from enum import Enum
from pydantic import BaseModel


class Race(str, Enum):
    HUMAN = "human"
    ELF = "elf"
    DWARF = "dwarf"
    HALFLING = "halfling"
    HALF_ORC = "half_orc"
    GNOME = "gnome"


class DndClass(str, Enum):
    FIGHTER = "fighter"
    WIZARD = "wizard"
    ROGUE = "rogue"
    CLERIC = "cleric"
    RANGER = "ranger"
    PALADIN = "paladin"


class Ability(str, Enum):
    STRENGTH = "strength"
    DEXTERITY = "dexterity"
    CONSTITUTION = "constitution"
    INTELLIGENCE = "intelligence"
    WISDOM = "wisdom"
    CHARISMA = "charisma"


class Skill(str, Enum):
    ACROBATICS = "acrobatics"
    ANIMAL_HANDLING = "animal_handling"
    ARCANA = "arcana"
    ATHLETICS = "athletics"
    DECEPTION = "deception"
    HISTORY = "history"
    INSIGHT = "insight"
    INTIMIDATION = "intimidation"
    INVESTIGATION = "investigation"
    MEDICINE = "medicine"
    NATURE = "nature"
    PERCEPTION = "perception"
    PERFORMANCE = "performance"
    PERSUASION = "persuasion"
    RELIGION = "religion"
    SLEIGHT_OF_HAND = "sleight_of_hand"
    STEALTH = "stealth"
    SURVIVAL = "survival"


class Condition(str, Enum):
    BLINDED = "blinded"
    CHARMED = "charmed"
    DEAFENED = "deafened"
    FRIGHTENED = "frightened"
    GRAPPLED = "grappled"
    INCAPACITATED = "incapacitated"
    INVISIBLE = "invisible"
    PARALYZED = "paralyzed"
    PETRIFIED = "petrified"
    POISONED = "poisoned"
    PRONE = "prone"
    RESTRAINED = "restrained"
    STUNNED = "stunned"
    UNCONSCIOUS = "unconscious"


class ArmorCategory(str, Enum):
    LIGHT = "light"
    MEDIUM = "medium"
    HEAVY = "heavy"
    SHIELDS = "shields"


class AbilityScore(BaseModel):
    score: int
    modifier: int


class Identity(BaseModel):
    name: str
    race: Race
    dnd_class: DndClass
    level: int
    experience_points: int
    xp_to_next_level: int
    proficiency_bonus: int


class HitPoints(BaseModel):
    current: int
    max: int
    temp: int
    hit_dice_total: int
    hit_dice_remaining: int
    hit_die_size: int


class DeathSaves(BaseModel):
    successes: int = 0
    failures: int = 0


class Combat(BaseModel):
    armor_class: int
    initiative_bonus: int
    speed_feet: int
    speed_tiles: int
    passive_perception: int


class SavingThrow(BaseModel):
    modifier: int
    proficient: bool


class SkillEntry(BaseModel):
    modifier: int
    proficient: bool
    expertise: bool
    ability: Ability


class SpellSlot(BaseModel):
    total: int
    used: int


class SpellEntry(BaseModel):
    slug: str
    name: str
    level: int
    school: str


class Spellcasting(BaseModel):
    ability: Ability
    spell_save_dc: int
    spell_attack_bonus: int
    cantrips_known: list[str]
    spell_slots: dict[str, SpellSlot]  # Keys: "1" through "9"
    prepared_spells: list[SpellEntry]
    max_prepared: int
    spellbook: list[SpellEntry] | None  # Wizard only


class EquipmentItem(BaseModel):
    slug: str
    name: str
    ac_base: int | None = None
    armor_category: ArmorCategory | None = None
    damage_dice: str | None = None
    damage_type: str | None = None
    ac_bonus: int = 0
    weight: float
    properties: list[str]
    magical: bool = False
    attunement_required: bool = False
    description: str = ""


class EquipmentSlots(BaseModel):
    head: EquipmentItem | None = None
    body: EquipmentItem | None = None
    cloak: EquipmentItem | None = None
    gloves: EquipmentItem | None = None
    boots: EquipmentItem | None = None
    ring_1: EquipmentItem | None = None
    ring_2: EquipmentItem | None = None
    amulet: EquipmentItem | None = None
    main_hand: EquipmentItem | None = None
    off_hand: EquipmentItem | None = None
    belt: EquipmentItem | None = None


class InventoryItem(BaseModel):
    slug: str
    name: str
    quantity: int
    weight: float


class Encumbrance(BaseModel):
    current_weight: float
    carry_capacity: float
    encumbered: bool


class CharacterSheet(BaseModel):
    identity: Identity
    ability_scores: dict[Ability, AbilityScore]
    hit_points: HitPoints
    death_saves: DeathSaves
    combat: Combat
    saving_throws: dict[Ability, SavingThrow]
    skills: dict[Skill, SkillEntry]
    equipment: EquipmentSlots
    inventory: list[InventoryItem]
    encumbrance: Encumbrance
    spellcasting: Spellcasting | None
    conditions: list[Condition]
    armor_proficiencies: list[ArmorCategory]
    weapon_proficiencies: list[str]
```

---

## Migration Notes

### Phase 1 to Phase 2 Changes

1. **Equipment slots**: Replace `Equipment.Slot` enum (UPPER_ARMOR, LOWER_ARMOR, BASE, MASK, etc.) with D&D slots (HEAD, BODY, CLOAK, GLOVES, BOOTS, RING_1, RING_2, AMULET, MAIN_HAND, OFF_HAND, BELT). The old enum remains for monster equipment only.

2. **JSON format**: Phase 1's `GameStateSerializer` uses integer ordinals for enums (e.g., `"race": 2` for Dwarf). Phase 2 JSON uses string keys (`"race": "dwarf"`). The orchestrator handles conversion. Godot's internal `CharacterData` resource continues to use integer enums; the serializer converts at the boundary.

3. **Derived stats**: Phase 1 stores `base_ac` on `CharacterData` as a simple integer. Phase 2 computes AC from equipped armor and DEX mod via `RulesEngine.calculate_ac()`. The `base_ac` field is removed from `CharacterData`; it becomes a derived value in the JSON.

4. **Spellcasting**: `CharacterData.gd` has no spell fields. Phase 2 adds `spellcasting` state to the orchestrator's model. Godot receives it in the JSON and renders it. No GDScript spell logic needed -- the orchestrator handles slot tracking and spell resolution.

5. **Encumbrance**: Not tracked in Phase 1. Phase 2 adds weight to all items and computes carry capacity from STR score.
