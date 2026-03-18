# Generate Quest

## Parameters
- **Type:** {{quest_type}}
- **Difficulty:** {{difficulty}}
- **Location:** {{location}}
- **Involved NPCs:** {{involved_npcs}}
- **DM Archetype:** {{dm_archetype}}
- **Player level:** {{player_level}}

## Context
{{narrative_context}}

## Instructions
Generate a quest arc JSON with stages and branching outcomes.

### Requirements
1. Quest ID must be unique (check `forge_output/narrative/` for existing quests)
2. Include 2-4 stages with clear triggers and objectives
3. Each stage needs success and failure outcomes
4. Reference valid NPC IDs for `giver_npc`
5. Reference valid dungeon/location IDs for `location`
6. Rewards should be appropriate for player level {{player_level}}
7. Match tone to DM archetype: {{dm_archetype}}

### Output
Write to `forge_output/narrative/{{quest_id}}.json`
Run `python3 forge/validate.py quest forge_output/narrative/{{quest_id}}.json` to verify.
