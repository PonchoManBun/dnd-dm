# Generate NPC

Generate an NPC profile in both simple (game-compatible) and rich (Phase 2+) formats.

## Arguments
- `$ARGUMENTS` — NPC description (e.g., "dwarf blacksmith in the village, gruff but fair")

## Steps

1. **Parse parameters** from `$ARGUMENTS`:
   - Extract: role, location, race, personality hints
   - Generate a unique `npc_id` (lowercase, underscored)

2. **Load existing NPCs** to avoid duplicates:
   - Read `../game/assets/data/npc_profiles.json`
   - Read `../forge_output/npcs/` for previously generated NPCs

3. **Load game state** (optional):
   - Try `curl -s http://localhost:8000/state` for DM archetype context

4. **Generate NPC JSON** with BOTH formats in one file:

   Simple format (top-level, game-compatible):
   ```json
   {
     "npc_id": {
       "name": "Display Name",
       "role": "...",
       "personality": "Single string",
       "knowledge": "Single string",
       "greeting": "...",
       "location": "..."
     }
   }
   ```

   Rich format fields (additional, for Phase 2+):
   `race`, `personality_traits`, `dialogue_style`, `knowledge_list`, `goals`, `secrets`, `disposition_default`, `schedule`, `position`, `sprite`, `faction`, `quest_hooks`

5. **Write** to `../forge_output/npcs/{npc_id}.json`

6. **Validate**: Run `python3 validate.py npc ../forge_output/npcs/{npc_id}.json`
