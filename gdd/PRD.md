# The Welcome Wench — Product Requirements

## Elevator Pitch

The Welcome Wench is a single-player 2D pixel art game that blends Minecraft's freeform building, Stardew Valley's seasonal farming and NPC relationships, and Baldur's Gate 3's tactical D&D combat — all narrated by a dual-model AI Dungeon Master. You manage a frontier village called Oakhaven, farm crops, build structures block by block, befriend townsfolk, and venture into dangerous expeditions where combat follows D&D 5e rules. Death is soft: you lose your expedition gear but your village, relationships, and farm persist. The AI DM makes every playthrough unique — narrating your day, generating quests, voicing NPCs in freeform conversation, and shaping the world around your choices.

## Design Pillars

### 1. Building & Crafting (from Minecraft)

**What we take:** Freeform block-by-block placement, material gathering, tool progression, the joy of creating something from nothing.

**What we skip:** Infinite procedural worlds, first-person perspective, redstone/automation complexity. Our world is a curated 2D region, not an infinite sandbox.

### 2. Social & Seasonal (from Stardew Valley)

**What we take:** Seasonal crop cycles, NPC schedules and relationships, gift-giving, festivals, the cozy rhythm of village life, farming as a core loop.

**What we skip:** Pixel-perfect fishing minigames, rigid romance paths. Our NPCs are freeform conversational agents powered by LLM — no canned dialogue trees.

### 3. Tactical Combat (from Baldur's Gate 3)

**What we take:** D&D 5e rules, party-based combat, positioning matters, action economy (action + bonus action + movement + reaction), companion recruitment, meaningful character builds.

**What we skip:** Full 3D, cinematic cutscenes, voice acting (TTS instead), dialogue skill checks with fixed outcomes. Our skill checks are DM-adjudicated, not scripted.

### 4. AI Dungeon Master

**What we take:** A living narrator that responds to everything you do. The local LLM handles real-time narration, NPC conversation, and contextual choices. Claude generates high-quality content on demand — dungeons, quests, items, story arcs.

**What we skip:** Nothing — this is our unique differentiator. No other game has a dual-model AI DM that combines fast local inference with on-demand quality generation.

## Comparison Matrix

| Feature | Minecraft | Stardew Valley | Baldur's Gate 3 | The Welcome Wench |
|---------|-----------|----------------|-----------------|-------------------|
| Building | 3D blocks, infinite | Farm layout, fixed buildings | None | 2D blocks, freeform structures |
| Farming | Basic crops | Deep seasonal system | None | Seasonal crops, irrigation |
| Combat | Action, simple | Basic weapons | D&D 5e, tactical | D&D 5e, party-based tactical |
| NPCs | Villagers, basic | Schedules, gifts, romance | Companions, dialogue trees | LLM-powered freeform conversation |
| Death | Drop items, respawn | Pass out, lose gold | Reload save | Lose expedition gear, keep village |
| Narration | None | Event text | Scripted + VO | AI DM, unique every time |
| World | Infinite procedural | Fixed farm + town | Handcrafted regions | Curated regions + AI generation |
| Perspective | First-person 3D | Top-down 2D | Isometric 3D | Top-down 2D pixel art |
| Seasons | None | 4 seasons, 28 days each | None | 4 seasons, affect crops/events |
| Multiplayer | Yes | Co-op | Co-op | Single-player only |

## Death & Consequences

**Soft death model.** When the player falls in combat during an expedition:

- **Lost:** All items carried on the expedition (not stored in village), expedition map progress
- **Kept:** Village state (all buildings, farms, stored items), NPC relationships and affinity, character level and XP, seasonal progress, quest knowledge
- **Narrative:** The DM narrates the party limping back to Oakhaven. Companions who fell are injured for several days (unavailable). The village remembers what happened.
- **Recovery:** Player wakes in their home. Can re-equip from village storage, recruit replacement companions, and try again. The dungeon may have changed (AI-regenerated).

This creates stakes without frustration — you fear losing good expedition loot but never lose hours of village building.

## Daily Cycle

Each in-game day follows a natural rhythm that guides but doesn't restrict player activity:

| Time | Phase | Primary Activities | DM Behavior |
|------|-------|-------------------|-------------|
| **Morning** | Farm & Build | Tend crops, water plants, harvest, build structures, craft items | Narrates weather, seasonal changes, NPC greetings |
| **Midday** | Explore & Gather | Venture into nearby areas, gather resources, visit other locations | Describes terrain, hints at dangers, offers side tasks |
| **Evening** | Expedition & Combat | Dungeon delving, wilderness encounters, boss fights | Full combat narration, tactical situation descriptions |
| **Night** | Craft & Socialize | Return to village, craft at stations, talk to NPCs, visit tavern | NPC conversations, story progression, rest narration |

The player can do anything at any time — the cycle affects NPC availability, monster spawns, crop growth, and DM narration tone.

## Seasonal Cycle

Four seasons, each lasting 28 in-game days (7 days × 4 weeks):

| Season | Crops | Weather | Events | Gameplay Effect |
|--------|-------|---------|--------|-----------------|
| **Spring** | Turnips, potatoes, strawberries | Rain common | Planting Festival (Day 7) | New crops available, ground thaws |
| **Summer** | Wheat, tomatoes, melons | Hot, dry spells | Midsummer Fair (Day 14) | Fastest crop growth, heat exhaustion risk |
| **Autumn** | Pumpkins, grapes, corn | Cool, windy | Harvest Festival (Day 21) | Best harvest yields, leaves change |
| **Winter** | Greenhouse only | Snow, blizzards | Winterfest (Day 28) | No outdoor farming, dungeon focus, NPC indoor schedules |

Seasons affect: crop availability, NPC schedules, monster types in the wild, building materials available, festival events, and DM narration flavor.

## Expedition Loop

1. **Prepare** — Equip gear from village storage, select party (up to 4), pack supplies
2. **Depart** — Choose destination from world map. DM narrates the journey.
3. **Explore** — Navigate dungeon/wilderness on a grid. Fog of war. Encounter monsters, traps, puzzles, loot.
4. **Fight** — Tactical D&D 5e combat when hostiles are encountered. Turn-based, positioning matters.
5. **Loot** — Collect materials, equipment, quest items, rare finds
6. **Return** — Head back to Oakhaven. DM narrates the return. Loot goes to village storage.
7. **Recover** — Injured party members heal over time. Craft with gathered materials. Plan next expedition.

Expeditions are the primary source of rare materials, combat XP, and quest progression. The village is where you spend what you earn.

## Building Loop

1. **Gather** — Harvest trees, mine rocks, collect materials from expeditions
2. **Plan** — Enter Build Mode (B key). Browse block palette by category.
3. **Place** — Ghost cursor shows placement preview. Consume materials. Walls, floors, furniture, decorations.
4. **Upgrade** — Structures unlock better crafting stations, storage, and NPC housing
5. **Attract** — Better buildings attract new NPCs to Oakhaven. Quality of buildings affects NPC happiness.

Buildings serve functional purposes: crafting stations for gear, storage for materials, housing for NPCs, farms for food, defenses for village events.

## Economy

### Materials
- **Wood** — From trees (Oakwood). Basic building, fuel, tools.
- **Stone** — From quarries and rocks. Durable building, advanced tools.
- **Iron** — From mines (Whispering Ruins). Weapons, armor, advanced building.
- **Crystal** — From deep dungeons. Magical items, enchanting.
- **Crops** — From farming. Food, trade, NPC gifts, brewing.

### Currency
- **Gold pieces** — Standard D&D currency. Earned from trade, quests, selling loot.
- **Trade goods** — Barter system with NPCs. Some prefer crops, others prefer crafted items.

### Trade
- NPC merchants have rotating stock influenced by season and relationship level
- Better affinity = better prices and rare items
- Player can set up a market stall to sell crafted goods
- Supply and demand: flooding the market with one item lowers its value

## NPC System

### Schedules
Every NPC has a daily schedule that varies by season. The blacksmith works the forge by day, visits the tavern at night. The herbalist gathers in the forest at morning, tends her shop at midday. Schedules are data-driven (JSON) and rendered by the client.

### Relationships
- **Affinity** — -100 to +100 scale. Starts at 0 (neutral). Affected by gifts, conversation, quests, and player actions.
- **Thresholds:** Stranger (< -20) → Acquaintance (-20 to 20) → Friend (20 to 50) → Close Friend (50 to 80) → Trusted (80+)
- Higher affinity unlocks: better shop prices, personal quests, companion recruitment, village leadership roles, secret information

### Gifts
Each NPC has liked, loved, and disliked items. Giving gifts affects affinity. The DM narrates reactions. Loved gifts from a close friend trigger special dialogue.

### Companion Recruitment
Any NPC with affinity 50+ can be recruited as a companion for expeditions. They bring their skills and personality. If they fall in combat, they're injured and unavailable for several days. Losing a companion's trust (affinity drop below 20) means they leave the party.

### Freeform Conversation
All NPC dialogue is LLM-generated. No dialogue trees. Players can say anything. The DM maintains NPC personality, knowledge, and relationship context. NPCs remember past conversations and react to world events.

## World Regions

### Oakhaven Village (Home Base)
The player's village. Starts as a few buildings — grows based on player construction. Central hub for all activities. Contains the Welcome Wench tavern, player's home, and initial NPC buildings.

### The Oakwood (Forest)
Dense forest surrounding Oakhaven. Source of wood, herbs, and wild game. Low-level monsters (wolves, goblins). Hidden groves and ruins. Best explored in spring and summer.

### Whispering Ruins (Dungeon)
Ancient underground complex beneath the forest. Multiple levels of increasing difficulty. Source of stone, iron, and ancient artifacts. Undead, constructs, and traps. Changes between visits (AI-regenerated).

### Dragon's Peak (Mountain)
Volcanic mountain to the north. High-level area with fire elementals, drakes, and a dragon lair. Source of rare metals and crystal. Extreme weather. Endgame content.

### Serpent Creek (Swamp)
Marshy lowlands to the south. Poisonous flora, reptilian monsters, hidden treasure. Source of alchemical ingredients. Difficult terrain. Best avoided in spring (flooding).

### The Great Lake (Water)
Large lake to the east. Fishing, water travel, lake monsters. Island dungeons. Source of fish (food/trade) and aquatic materials. Seasonal ice in winter enables new areas.
