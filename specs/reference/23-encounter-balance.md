# 23 — Encounter Balance

## Overview

The Welcome Wench uses standard **D&D 5e encounter building rules** balanced for a party of 4 (1 player + 3 companions). All encounter budgets, XP thresholds, and CR tables come from the SRD and DMG. This spec consolidates the rules into a single reference and adds game-specific guidance for the early levels where characters are most fragile.

These tables are also present in `forge/design_guide.md` -- both sources must remain consistent. The design guide is the Forge agent's primary reference; this spec is the system-of-record for the game engine and orchestrator.

**Status: Partially Implemented** (tables exist in `forge/design_guide.md`; not yet consumed by orchestrator encounter generation)

---

## XP Threshold Table

Each character level has four difficulty thresholds. The **party threshold** is the sum of individual thresholds for all party members.

| Level | Easy | Medium | Hard | Deadly |
|-------|------|--------|------|--------|
| 1     | 25   | 50     | 75   | 100    |
| 2     | 50   | 100    | 150  | 200    |
| 3     | 75   | 150    | 225  | 400    |
| 4     | 125  | 250    | 375  | 500    |
| 5     | 250  | 500    | 750  | 1,100  |
| 6     | 300  | 600    | 900  | 1,400  |
| 7     | 350  | 750    | 1,100| 1,700  |
| 8     | 450  | 900    | 1,400| 2,100  |
| 9     | 550  | 1,100  | 1,600| 2,400  |
| 10    | 600  | 1,200  | 1,900| 2,800  |
| 11    | 800  | 1,600  | 2,400| 3,600  |
| 12    | 1,000| 2,000  | 3,000| 4,500  |
| 13    | 1,100| 2,200  | 3,400| 5,100  |
| 14    | 1,250| 2,500  | 3,800| 5,700  |
| 15    | 1,400| 2,800  | 4,300| 6,400  |
| 16    | 1,600| 3,200  | 4,800| 7,200  |
| 17    | 2,000| 3,900  | 5,900| 8,800  |
| 18    | 2,100| 4,200  | 6,300| 9,500  |
| 19    | 2,400| 4,900  | 7,300| 10,900 |
| 20    | 2,800| 5,700  | 8,500| 12,700 |

### Party Threshold Calculation

```
Party threshold (difficulty) = sum of individual thresholds for each party member
```

**Example**: Party of 4 at level 1:
- Easy: 4 x 25 = **100 XP**
- Medium: 4 x 50 = **200 XP**
- Hard: 4 x 75 = **300 XP**
- Deadly: 4 x 100 = **400 XP**

**Example**: Mixed-level party (player level 3, companions level 1, 2, 2):
- Easy: 75 + 25 + 50 + 50 = **200 XP**
- Medium: 150 + 50 + 100 + 100 = **400 XP**
- Hard: 225 + 75 + 150 + 150 = **600 XP**
- Deadly: 400 + 100 + 200 + 200 = **900 XP**

---

## XP by Challenge Rating

The standard SRD XP values for each challenge rating:

| CR   | XP     | CR   | XP      |
|------|--------|------|---------|
| 0    | 10     | 9    | 5,000   |
| 1/8  | 25     | 10   | 5,900   |
| 1/4  | 50     | 11   | 7,200   |
| 1/2  | 100    | 12   | 8,400   |
| 1    | 200    | 13   | 10,000  |
| 2    | 450    | 14   | 11,500  |
| 3    | 700    | 15   | 13,000  |
| 4    | 1,100  | 16   | 15,000  |
| 5    | 1,800  | 17   | 18,000  |
| 6    | 2,300  | 18   | 20,000  |
| 7    | 2,900  | 19   | 22,000  |
| 8    | 3,900  | 20   | 25,000  |

Higher CRs (21-30) exist in the SRD but are beyond the scope of this game's level range.

These XP values are also stored per-monster in `dnd_monsters.json` (the `xp` field) and accessed via `DndMonsterFactory.get_xp(slug)`.

---

## Encounter Multipliers

When an encounter has multiple monsters, the **adjusted XP** is higher than the raw total because managing more enemies is harder due to action economy. Multiply total monster XP by:

| Monster Count | Multiplier |
|---------------|------------|
| 1             | x1         |
| 2             | x1.5       |
| 3-6           | x2         |
| 7-10          | x2.5       |
| 11-14         | x3         |
| 15+           | x4         |

**Important**: The multiplier only affects the **adjusted XP** used to determine encounter difficulty. The actual XP awarded to players is the **raw total** (no multiplier).

### Adjusted XP Examples

| Encounter | Raw XP | Multiplier | Adjusted XP | Difficulty (4 level-1 PCs) |
|---|---|---|---|---|
| 1 goblin (CR 1/4) | 50 | x1 | 50 | Easy (< 100) |
| 2 goblins (CR 1/4) | 100 | x1.5 | 150 | Medium (100-200) |
| 3 goblins (CR 1/4) | 150 | x2 | 300 | Hard (200-300) |
| 4 goblins (CR 1/4) | 200 | x2 | 400 | Deadly (300-400) |
| 1 ogre (CR 2) | 450 | x1 | 450 | Deadly (> 400) |

---

## Building an Encounter

### Step-by-Step Process

1. **Determine party composition.** Count party members and note each character's level.
2. **Look up XP thresholds.** Sum individual thresholds for each difficulty category.
3. **Select monsters.** Choose monsters from `dnd_monsters.json` whose CR is appropriate.
4. **Calculate raw XP.** Sum the XP values of all selected monsters.
5. **Apply encounter multiplier.** Based on the number of monsters, multiply raw XP.
6. **Compare to thresholds.** The adjusted XP determines the encounter difficulty.

### Algorithm (Python pseudocode)

```python
def classify_encounter(
    party_levels: list[int],
    monster_xp_values: list[int],
) -> str:
    """Classify an encounter as Easy/Medium/Hard/Deadly."""
    # Step 1-2: Sum party thresholds
    thresholds = {"easy": 0, "medium": 0, "hard": 0, "deadly": 0}
    for level in party_levels:
        thresholds["easy"] += XP_THRESHOLD_TABLE[level]["easy"]
        thresholds["medium"] += XP_THRESHOLD_TABLE[level]["medium"]
        thresholds["hard"] += XP_THRESHOLD_TABLE[level]["hard"]
        thresholds["deadly"] += XP_THRESHOLD_TABLE[level]["deadly"]

    # Step 3-4: Sum raw monster XP
    raw_xp = sum(monster_xp_values)

    # Step 5: Apply multiplier
    count = len(monster_xp_values)
    if count == 1:
        multiplier = 1.0
    elif count == 2:
        multiplier = 1.5
    elif count <= 6:
        multiplier = 2.0
    elif count <= 10:
        multiplier = 2.5
    elif count <= 14:
        multiplier = 3.0
    else:
        multiplier = 4.0

    adjusted_xp = int(raw_xp * multiplier)

    # Step 6: Classify
    if adjusted_xp >= thresholds["deadly"]:
        return "deadly"
    elif adjusted_xp >= thresholds["hard"]:
        return "hard"
    elif adjusted_xp >= thresholds["medium"]:
        return "medium"
    elif adjusted_xp >= thresholds["easy"]:
        return "easy"
    else:
        return "trivial"
```

---

## Solo vs Party Scaling

### Fewer Than 4 Party Members

If the party has fewer than 4 members (e.g., before companions are recruited, or after companion deaths), encounters must be adjusted. The key principle: **reduce monster count, not monster CR**.

Action economy matters more than raw power. A single CR 2 ogre is manageable for 4 level-1 characters because they get 4 attacks per round. The same ogre against a solo level-1 character is nearly impossible -- 1 attack vs the ogre's 1, but the ogre hits much harder.

| Party Size | Adjustment |
|---|---|
| 4 (standard) | Use encounter tables as-is |
| 3 | Remove 1 monster from multi-monster encounters. Solo encounters stay the same. |
| 2 | Halve the monster count. Solo encounters: reduce CR by 1-2 steps. |
| 1 (solo) | Use at most 1-2 monsters at CR equal to party level minus 2. See early game rules below. |

### Encounter Multiplier Adjustment for Small Parties

The DMG suggests adjusting the encounter multiplier table for parties smaller or larger than the standard 3-5:

| Party Size | Multiplier Adjustment |
|---|---|
| 1-2 players | Use the next higher multiplier bracket |
| 3-5 players | Standard multipliers |
| 6+ players | Use the next lower multiplier bracket |

For a solo player, 2 monsters would use the x2 multiplier instead of x1.5. This makes the encounter look harder on paper, which is correct -- a solo character struggles with action economy against multiple foes.

---

## Dungeon Encounter Budget

### Adventuring Day XP Budget

The standard adventuring day assumes 6-8 medium-difficulty encounters with 2 short rests. The total XP budget per character per day:

| Character Level | Daily XP Budget (per character) |
|---|---|
| 1 | 300 |
| 2 | 600 |
| 3 | 1,200 |
| 4 | 1,700 |
| 5 | 3,500 |
| 6 | 4,000 |
| 7 | 5,000 |
| 8 | 6,000 |
| 9 | 7,500 |
| 10 | 9,000 |

**Party daily budget** = sum of individual budgets. For 4 level-1 characters: 4 x 300 = **1,200 adjusted XP** across all encounters in the dungeon.

### Dungeon Floor Budget

In The Welcome Wench, each dungeon floor has approximately 5 rooms with 1-2 combat encounters. A 3-floor dungeon represents roughly one adventuring day:

| Floor | Encounters | XP Budget (4 level-1 PCs) |
|---|---|---|
| Floor 1 | 1-2 combats | ~300-400 adjusted XP |
| Floor 2 | 1-2 combats | ~400-500 adjusted XP |
| Floor 3 | 1 boss combat | ~300-400 adjusted XP |
| **Total** | **3-5 combats** | **~1,000-1,300 adjusted XP** |

### Short Rest Placement

- After Floor 1 boss/final room: opportunity for a short rest
- After Floor 2 boss/final room: opportunity for a short rest
- Long rest only at the tavern

---

## Boss Encounters

### Difficulty Range

Boss encounters should be **Hard to Deadly**. They are the climax of a dungeon floor and should feel dangerous.

### Boss Design Patterns

| Pattern | Description | Example |
|---|---|---|
| **Solo boss** | One powerful creature | 1 ogre (CR 2) vs 4 level-1 PCs = Deadly |
| **Boss + minions** | Strong creature with weak helpers | 1 bugbear (CR 1) + 2 goblins (CR 1/4) = Hard |
| **Elite group** | 2-3 above-average creatures | 2 hobgoblins (CR 1/2) + 1 hobgoblin captain (CR 3) |
| **Wave encounter** | Reinforcements arrive mid-fight | 2 skeletons, then 2 more after round 3 |

### Solo Boss Action Economy Fix

A single boss monster against 4 players suffers from **action economy disadvantage** -- it gets 1 turn per round while the party gets 4. Mitigations:

- **Legendary actions** (for CR 3+ bosses)
- **Lair actions** (environmental hazards on initiative count 20)
- **Minions** (1-2 weak allies to absorb party actions)
- **Multi-attack** (most bosses should have 2+ attacks per turn)

---

## Early Game Balance (Level 1-3)

### Level 1: Extreme Fragility

At level 1, a Fighter has ~12 HP (10 hit die + 2 CON mod). A single critical hit from a goblin (2d6 + 2 = avg 9, max 14) can down a character. Rules for level 1 encounters:

- **Floor 1 combat rooms**: Easy to Medium encounters only (100-200 adjusted XP for 4 level-1 characters)
- **Max monsters per room**: 2-3 CR 1/8 or 1-2 CR 1/4
- **Boss encounters**: Medium to Hard (200-300 adjusted XP). One CR 1/2 or CR 1 creature.
- **Never CR 2+ monsters** against level 1 parties unless it is a scripted "you should run" moment

### Level 1 Encounter Examples (Party of 4)

| Encounter | Monsters | Raw XP | Adjusted XP | Difficulty |
|---|---|---|---|---|
| Guard room | 2 kobolds (CR 1/8) | 50 | 75 | Easy |
| Rat nest | 3 giant rats (CR 1/8) | 75 | 150 | Medium |
| Goblin patrol | 2 goblins (CR 1/4) | 100 | 150 | Medium |
| Skeleton crypt | 3 skeletons (CR 1/4) | 150 | 300 | Hard |
| Floor 1 boss | 1 bugbear (CR 1) | 200 | 200 | Medium |
| Hard boss | 1 bugbear + 2 goblins | 300 | 600 | Deadly |

### Level 2: Still Fragile

Characters gain a level's worth of HP (~7-8 more) and possibly a key feature (Action Surge, Cunning Action). Encounters can be slightly harder:

- **Combat rooms**: Medium encounters (200-400 adjusted XP)
- **Boss**: Hard to Deadly (400-600 adjusted XP)

### Level 3: Subclass Unlocks

Level 3 is a power spike -- subclasses unlock. Encounters can be noticeably harder:

- **Combat rooms**: Medium to Hard (400-600 adjusted XP)
- **Boss**: Hard to Deadly (600-900 adjusted XP)

### CR Ceiling by Party Level

A guideline for the maximum individual monster CR in any encounter:

| Party Level (all 4 members) | Max Monster CR | Notes |
|---|---|---|
| 1 | CR 1 | CR 2 is a potential TPK |
| 2 | CR 2 | Solo only, with minions max CR 1 |
| 3 | CR 3 | Subclass features help survive |
| 4 | CR 4 | ASI level, characters toughen up |
| 5 | CR 6 | Extra Attack / 3rd-level spells |

---

## Implementation Notes

### Where These Tables Live

| Location | Purpose | Status |
|---|---|---|
| `forge/design_guide.md` | Forge agent reference for dungeon generation | **Implemented** |
| `game/src/character_data.gd` | `XP_THRESHOLDS` array for leveling | **Implemented** |
| `game/assets/data/dnd_monsters.json` | Per-monster `xp` and `cr` fields | **Implemented** |
| `game/src/dnd_monster_factory.gd` | `get_xp()` and `get_cr()` accessors | **Implemented** |
| `orchestrator/models/enums.py` | `XP_THRESHOLDS` constant (Python mirror) | **Implemented** |
| Orchestrator encounter builder | Automated encounter classification | **Planned** |

### Consistency Requirements

The XP threshold tables in this spec, `forge/design_guide.md`, `character_data.gd`, and `enums.py` must remain identical. If one changes, all must be updated.

The XP-by-CR table in this spec must match the `xp` field values in `dnd_monsters.json`.
