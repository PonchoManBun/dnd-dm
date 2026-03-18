# Dungeon Design Guide

Read this guide before generating any dungeon content. These are the design principles for The Welcome Wench. They override generic D&D defaults where specified.

---

## 1. Encounter Difficulty (Standard D&D, Party of 4)

This game uses a BG3-style party system (1 player + up to 3 companions). Use standard D&D 5e encounter budgets for a party of 4.

### XP Thresholds Per Character Level

| Level | Easy | Medium | Hard | Deadly |
|-------|------|--------|------|--------|
| 1     | 25   | 50     | 75   | 100    |
| 2     | 50   | 100    | 150  | 200    |
| 3     | 75   | 150    | 225  | 400    |
| 4     | 125  | 250    | 375  | 500    |
| 5     | 250  | 500    | 750  | 1100   |
| 6     | 300  | 600    | 900  | 1400   |
| 7     | 350  | 750    | 1100 | 1700   |
| 8     | 450  | 900    | 1400 | 2100   |
| 9     | 550  | 1100   | 1600 | 2400   |
| 10    | 600  | 1200   | 1900 | 2800   |

**Party threshold** = sum of individual thresholds. For 4 characters at level 1: Easy = 100, Medium = 200, Hard = 300, Deadly = 400.

### XP by Challenge Rating (from SRD)

| CR   | XP    | CR  | XP     |
|------|-------|-----|--------|
| 0    | 10    | 5   | 1,800  |
| 1/8  | 25    | 6   | 2,300  |
| 1/4  | 50    | 7   | 2,900  |
| 1/2  | 100   | 8   | 3,900  |
| 1    | 200   | 9   | 5,000  |
| 2    | 450   | 10  | 5,900  |
| 3    | 700   | 11  | 7,200  |
| 4    | 1,100 | 12  | 8,400  |

### Encounter Multipliers (Multiple Monsters)

When an encounter has multiple monsters, multiply total XP by:

| Monster Count | Multiplier |
|---------------|------------|
| 1             | x1         |
| 2             | x1.5       |
| 3-6           | x2         |
| 7-10          | x2.5       |
| 11-14         | x3         |
| 15+           | x4         |

**Example**: 3 goblins (CR 1/4) = 3 x 50 = 150 XP, multiplied by x2 = 300 adjusted XP. For a level 1 party of 4, that's a Hard encounter (threshold 300).

### Early Game Balance (Level 1-3)

At level 1, characters are fragile. A single critical hit can down a player.

- **Floor 1 combat rooms**: Easy to Medium encounters only (100-200 adjusted XP for 4 level-1 characters)
- **Max monsters per room at level 1**: 2-3 CR 1/8 or 1-2 CR 1/4
- **Boss encounters**: Medium to Hard (200-300 adjusted XP). One CR 1/2 or CR 1 creature.
- **Never put CR 2+ monsters against level 1 parties** unless it's a scripted "you're supposed to run" moment

---

## 2. Room Design Philosophy

### Every Room Tells a Story

No empty filler rooms. Every room must have at least one of:
- A narrative beat (environmental storytelling — skeleton clutching a note, bloodstains leading to a secret door)
- Loot (scaled to depth)
- A choice or puzzle
- An NPC or monster encounter
- Lore (inscriptions, murals, journals)

### Room Type Ratio (per floor, ~5 rooms)

| Room | Type | Purpose |
|------|------|---------|
| 1    | Entrance (safe*) | Set the scene, orient the party, establish atmosphere |
| 2    | Combat | Primary encounter for the floor |
| 3    | Puzzle/Trap | Skill checks, environmental hazard, player agency |
| 4    | Treasure | Reward exploration, gear up before boss |
| 5    | Boss/Special | Climactic encounter with choices and on_clear |

*Entrance safety depends on DM archetype (see section 6).

### Room Narrative Requirements

Every room MUST have a `narrative` field with:
- 1-3 sentences of atmospheric description
- Environmental details that hint at what the room contains
- BBCode formatting for emphasis: `[color=red]danger[/color]`, `[b]bold[/b]`

---

## 3. Dungeon Layout

### Topology: Linear with Optional Branches

The main path is always clear: entrance → combat → puzzle → treasure → boss. But side rooms branch off for extra exploration rewards.

```
[Entrance] → [Combat Room] → [Boss Room]
                 ↓                ↑
           [Side Treasure]   [Trap Room]
```

### Layout Rules

- **Corridors** connect rooms via L-shaped paths (how `DungeonLoader` generates them)
- **Main path** must be traversable from entrance to boss via corridors
- **Optional branches** are dead ends with treasure, lore, or side encounters
- **Floor size**: 30 x 20 tiles (standard). Rooms typically 5-8 tiles wide, 4-7 tiles tall.
- **Room spacing**: Leave at least 2 tiles between rooms for corridor walls

### Multi-Floor Structure

- **Floor 1**: Introduction — easiest encounters, most lore, establishes dungeon theme
- **Floor 2**: Escalation — harder fights, traps appear, environmental hazards
- **Floor 3 (final)**: Climax — boss encounter, best loot, narrative resolution

---

## 4. Difficulty Ramping: Wave Pattern

Difficulty follows a tension-and-release curve, NOT a steady climb.

### Per-Floor Wave

```
Tension
  ▲
  │    ╱╲
  │   ╱  ╲      ╱╲
  │  ╱    ╲    ╱  ╲
  │ ╱      ╲  ╱    ╲╱ Boss
  │╱        ╲╱
  └──────────────────→ Room progression
  Entrance  Combat  Breather  Trap  Boss
```

- **Room 1 (Entrance)**: Low tension. Atmosphere and orientation.
- **Room 2 (Combat)**: Spike. The main fight for this floor.
- **Room 3 (Puzzle/Trap)**: Different kind of tension. Skill-based, not HP-draining.
- **Room 4 (Treasure)**: Release. Reward, heal up, prepare.
- **Room 5 (Boss)**: Climax. Hardest encounter, choices, resolution.

### Across Floors

| Floor | Overall Difficulty | Encounter Range | Loot Quality |
|-------|-------------------|-----------------|--------------|
| 1     | Easy–Medium       | Mostly Easy     | Common items  |
| 2     | Medium–Hard       | Medium with 1 Hard | Uncommon items |
| 3     | Hard–Deadly (boss) | Hard with Deadly boss | Rare items |

---

## 5. Monster Placement: Logical and Context-Aware

**This is critical.** Do NOT scatter monsters randomly. Think about WHY each monster is WHERE it is.

### Placement Principles

| Monster Role | Placement Logic | Example |
|---|---|---|
| Guards | Near doors and entrances | 2 skeletons flanking the doorway |
| Scouts/Sentries | In corners with sightlines | Goblin lookout on elevated rubble |
| Pack animals | Clustered in the room center | 3 giant rats nesting together |
| Ambushers | Behind obstacles, near walls | Rogues hiding behind pillars |
| Bosses | Center-back of room, on a throne/altar | Ogre at the far end of the hall |
| Ranged units | Back of room behind melee | Goblin archer behind skeleton warriors |

### Spacing Rules

- **No monster within 2 tiles of a corridor connection point** — prevents the "spawn into death" problem
- **Ranged monsters**: Place 4+ tiles from the nearest door
- **Melee monsters**: Place 3+ tiles from doors to give party approach distance
- **Boss monsters**: Center or back of room, at least 5 tiles from entrance

### Post-Generation Review Step

After placing monsters, the Forge MUST review each combat room and answer:
1. Does each monster's position make narrative sense? (guards guard, scouts watch, animals nest)
2. Can the party enter the room and see the threats before engaging?
3. Is there tactical terrain? (cover, chokepoints, elevation)
4. Would an intelligent monster actually stand where I placed it?

Include this review rationale in the generation manifest.

---

## 6. DM Archetype Effects on Dungeon Design

### Entrance Room Safety

| Archetype | Entrance Room |
|---|---|
| Storyteller | Safe — rich narrative, set the scene |
| Guide | Safe — hints about what's ahead |
| Historian | Safe — lore-heavy, inscriptions and murals |
| Taskmaster | Light resistance — 1-2 weak guards |
| Trickster | Appears safe — hidden trap or disguised enemy |

### Monster Placement by Archetype

| Archetype | Placement Style |
|---|---|
| Storyteller | Fair — monsters visible, space to prepare, balanced groups |
| Guide | Generous — weaker monsters, more spread out, obvious positioning |
| Historian | Thematic — undead in crypts, constructs in temples, placement tells a story |
| Taskmaster | Tactically optimized — monsters in advantageous positions, ranged behind melee, flanking |
| Trickster | Deceptive — ambushes, hidden enemies, monsters that look like furniture/corpses |

### Encounter Difficulty by Archetype

| Archetype | Adjustment |
|---|---|
| Storyteller | Standard (Medium encounters, Hard boss) |
| Guide | Easier (Easy-Medium encounters, Medium boss) |
| Historian | Standard (encounters tied to lore, not just CR) |
| Taskmaster | Harder (Hard encounters, Deadly boss) |
| Trickster | Deceptive (Easy-looking encounters that are secretly Hard — traps + monsters combined) |

### Loot by Archetype

| Archetype | Loot Style |
|---|---|
| Storyteller | Balanced — standard loot tables |
| Guide | Generous — extra potions, better gear drops |
| Historian | Thematic — historical artifacts, lore items, named weapons |
| Taskmaster | Scarce — less loot, more consumables, earned through difficulty |
| Trickster | Booby-trapped — mimics, cursed items mixed with real treasure |

---

## 7. Loot Distribution

### Loot Everywhere, Scaling with Depth

Every room can have loot. Rarity increases with depth.

| Room Type | Loot Expectation |
|---|---|
| Entrance | 0-1 minor items (a dagger, some arrows — "left behind by previous adventurers") |
| Combat | 1-2 items appropriate to the monsters (weapons they were using, ammo) |
| Puzzle/Trap | Reward for disarming/solving — slightly better than combat loot |
| Treasure | 2-4 items, best non-boss loot on the floor |
| Boss | Best single item on the floor + gold + consumables |

### Item Rarity by Dungeon Depth

| Floor | Common | Uncommon | Rare | Very Rare |
|-------|--------|----------|------|-----------|
| 1     | 80%    | 20%      | 0%   | 0%        |
| 2     | 50%    | 40%      | 10%  | 0%        |
| 3     | 30%    | 40%      | 25%  | 5%        |

### Item Placement

Items should be placed narratively, not just at random coordinates:
- Weapons near fallen warriors or weapon racks
- Potions on shelves or in crates
- Armor on stands or on defeated enemies
- Food in storage areas or on tables
- Gold in chests, pouches, or scattered around treasure rooms

---

## 8. Trap Design

### Hidden but Detectable

Traps are NOT announced in room narrative. They are discovered through:
- **Passive Perception** checks (auto-detect if score >= trap DC)
- **Active Investigation** checks (player chooses to search)
- **Triggering the trap** (fail to detect, take damage)

### Trap Severity (from SRD)

| Severity | Save DC | Attack Bonus | Damage (Level 1-4) |
|----------|---------|--------------|---------------------|
| Setback  | 10-11   | +3 to +5     | 1d10                |
| Dangerous | 12-15  | +6 to +8     | 2d10                |
| Deadly   | 16-20   | +9 to +12    | 4d10                |

### Trap Placement Rules

- **Puzzle/Trap rooms**: 1 main trap, telegraphed by room type
- **Corridors**: Optional traps on non-main paths (reward caution)
- **Treasure rooms**: Trapped chests or floor plates (risk/reward)
- **Never trap the main path exit** — player should always be able to leave

### Trap Types for Dungeon Themes

| Theme | Common Traps |
|---|---|
| Crypt/Undead | Falling rubble, poison gas from urns, animated skeleton ambush |
| Cave/Natural | Pit traps, falling rocks, quicksand, spider webs |
| Temple/Holy | Divine wards, holy fire, collapsing pillars |
| Sewer/Urban | Poison darts, flooding, acid pools |
| Arcane/Wizard | Glyph of warding, teleportation traps, illusion traps |

---

## 9. Environmental Storytelling

Every dungeon has a history. The rooms should tell that story through their contents.

### Techniques

- **Corpses and remains**: A skeleton clutching a journal, a dead adventurer with a map
- **Property damage**: Scorch marks from old battles, collapsed walls, flooded passages
- **Written clues**: Inscriptions, warnings carved into walls, torn notes
- **Progression of decay**: Rooms closer to the entrance are more damaged/looted; deeper rooms are more preserved
- **Monster ecology**: Why are these monsters HERE? Goblins set up camp, undead haunt their own tombs, beasts lair near water
- **NPC traces**: Signs of other adventurers who came before (and didn't make it back)

### Narrative Continuity

Rooms on the same floor should tell a connected story. Examples:
- Floor 1 guard room → guard barracks → chapel (a military outpost that fell)
- Floor 2 burial hall → ossuary → armory (the dead soldiers' resting place)
- Floor 3 antechamber → treasury → throne room (what the soldiers were guarding)

---

## 10. Generation Manifest

After generating a dungeon, include design rationale in the manifest at `forge_output/manifests/gen_{timestamp}.json`:

```json
{
  "timestamp": "2026-03-18T12:00:00",
  "content_type": "dungeon",
  "file": "forge_output/dungeons/shadow_keep.json",
  "dm_archetype": "storyteller",
  "player_level": 3,
  "party_size": 4,
  "validation": "passed",
  "design_notes": {
    "theme": "Abandoned military outpost overrun by undead",
    "difficulty_curve": "wave",
    "encounter_budget": "Standard 4-player, level 3: Easy=300, Medium=600, Hard=900",
    "monster_placement_review": [
      "Room 1: Safe entrance, atmospheric",
      "Room 2: 2 skeleton guards flanking doorway, 1 zombie patrol in center — Medium encounter (450 adj XP)",
      "Room 3: Trap room — falling rubble DC 12, no monsters",
      "Room 4: Treasure room — 1 mimic disguised as chest (Trickster archetype)",
      "Room 5: Boss — wight on raised platform at back of room, 2 skeletons flanking — Hard encounter (800 adj XP)"
    ],
    "loot_summary": "3 common items, 2 uncommon, 1 rare (boss drop)"
  }
}
```
