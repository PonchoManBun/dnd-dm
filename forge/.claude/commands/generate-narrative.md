# Generate Narrative Pool

Generate narrative text entries for room descriptions, combat, discoveries, and more.

## Arguments
- `$ARGUMENTS` — Theme and categories (e.g., "swamp theme, room_entry and combat_start, 5 each")

## Steps

1. **Parse parameters** from `$ARGUMENTS`:
   - Extract: theme name, categories to generate, count per category
   - Default: 5 entries per category if not specified

2. **Load existing narratives**:
   - Read `../game/assets/data/narratives.json` for the base format and existing entries
   - Read `../forge_output/narrative/pools/` for previously generated pools

3. **Load game state** (optional):
   - Try `curl -s http://localhost:8000/state` for DM archetype

4. **Generate narrative entries** matching the narratives.json structure:
   - `room_entry.{theme}` — Array of atmospheric room descriptions
   - `combat_start` — Combat initiation descriptions
   - `combat_end` — Combat conclusion descriptions
   - `item_discovery` — Item finding descriptions
   - `choice_scenarios` — Array of {text, choices[]} objects (2-3 choices each)
   - `rest` — Rest descriptions
   - `level_transition` — Floor transition descriptions

5. **Write** to `../forge_output/narrative/pools/{theme}_narratives.json`
