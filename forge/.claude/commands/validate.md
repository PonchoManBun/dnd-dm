# Validate Content

Run validation on generated content to ensure it matches game schemas.

## Arguments
- `$ARGUMENTS` — Content type and file path (e.g., "dungeon ../forge_output/dungeons/shadow_keep.json")

## Steps

1. **Parse** content type and file path from `$ARGUMENTS`
   - Supported types: `dungeon`, `npc`, `quest`

2. **Run validation**:
   ```bash
   python3 validate.py $CONTENT_TYPE $FILE_PATH
   ```

3. **Report results**:
   - If validation passes, confirm the file is ready
   - If validation fails, list all errors clearly
   - Suggest fixes for common issues (invalid slugs, out-of-bounds positions, missing fields)

4. **For dungeons, run simulation**:
   ```bash
   python3 simulate.py $FILE_PATH --level 1 --party-size 4 --runs 50
   ```
   Report simulation results alongside validation results.

5. **Optionally validate all**: If `$ARGUMENTS` is "all", validate everything in `../forge_output/`:
   - All `.json` files in `dungeons/` as type `dungeon`
   - All `.json` files in `npcs/` as type `npc`
   - All `.json` files in `narrative/` (excluding `pools/`) as type `quest`
