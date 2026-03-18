# Edit NPC

Edit an existing NPC — update knowledge, change disposition, add secrets, or update greeting.

## Arguments
- `$ARGUMENTS` — NPC ID and operation (e.g., "marta update_knowledge 'Learned about the dragon attack'")

## Steps

1. **Parse** the target NPC ID and operation from `$ARGUMENTS`
   - Supported operations: `update_knowledge`, `change_disposition`, `add_secrets`, `update_greeting`

2. **Find the NPC file**:
   - Check `../forge_output/npcs/{npc_id}.json` first
   - Fall back to `../game/assets/data/npc_profiles.json`

3. **Apply the edit**:
   - `update_knowledge`: Append new knowledge to the knowledge string (and knowledge_list if rich format)
   - `change_disposition`: Update disposition_default field
   - `add_secrets`: Append to secrets array (rich format)
   - `update_greeting`: Replace greeting text

4. **Write** updated NPC to `../forge_output/npcs/{npc_id}.json`

5. **Validate**: Run `python3 validate.py npc ../forge_output/npcs/{npc_id}.json`
