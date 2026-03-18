# Generate Quest

Generate a quest arc with stages, branching outcomes, and rewards.

## Arguments
- `$ARGUMENTS` — Quest description (e.g., "side quest, investigate missing merchants on the east road, level 2")

## Steps

1. **Parse parameters** from `$ARGUMENTS`:
   - Extract: type (main_quest|side_quest|encounter|lore), difficulty/level, location, involved NPCs
   - Generate unique `quest_id`

2. **Load context**:
   - Read `../forge_output/narrative/` for existing quests (avoid ID collisions)
   - Read `../game/assets/data/npc_profiles.json` and `../forge_output/npcs/` for valid NPC IDs
   - Read `../game/assets/data/dungeons/` and `../forge_output/dungeons/` for valid location IDs

3. **Load game state** (optional):
   - Try `curl -s http://localhost:8000/state` for DM archetype and player context

4. **Generate quest JSON**:
   ```json
   {
     "quest_id": "unique_id",
     "type": "main_quest|side_quest|encounter|lore",
     "title": "Quest Title",
     "description": "Summary",
     "giver_npc": "npc_id",
     "location": "dungeon_or_area_id",
     "prerequisite_quests": [],
     "stages": [
       {
         "id": "stage_01",
         "title": "Stage Title",
         "description": "What to do",
         "trigger": "trigger_condition",
         "objectives": ["objective text"],
         "outcomes": {
           "success": {"next_stage": "stage_02", "narrative": "..."},
           "failure": {"narrative": "..."}
         }
       }
     ],
     "rewards": {"xp": 500, "gold": 100, "items": ["item_slug"], "reputation": {"faction": 10}},
     "failure_consequences": {"narrative": "...", "reputation": {"faction": -5}}
   }
   ```

5. **Write** to `../forge_output/narrative/{quest_id}.json`

6. **Validate**: Run `python3 validate.py quest ../forge_output/narrative/{quest_id}.json`
