# Generate NPC

## Parameters
- **Role:** {{role}}
- **Location:** {{location}}
- **Race:** {{race}}
- **DM Archetype:** {{dm_archetype}}

## Context
{{narrative_context}}

## Existing NPCs
{{existing_npcs}}

## Instructions
Generate an NPC profile in **both** formats:

### Simple format (game-compatible, for npc_profiles.json):
```json
{
  "{{npc_id}}": {
    "name": "Display Name",
    "role": "role description",
    "personality": "Single string personality description",
    "knowledge": "Single string of what they know",
    "greeting": "What they say when first approached",
    "location": "Where they are"
  }
}
```

### Rich format (Phase 2+ orchestrator/LLM):
Include additional fields: `race`, `personality_traits` (array), `dialogue_style`, `knowledge_list` (array), `goals` (array), `secrets` (array), `disposition_default`, `schedule`, `position`, `sprite`, `faction`, `quest_hooks`.

### Requirements
1. Do NOT duplicate existing NPC names or roles
2. Personality and knowledge must be single strings in the simple format
3. Greeting should be in-character
4. Match tone to DM archetype: {{dm_archetype}}

### Output
Write to `forge_output/npcs/{{npc_id}}.json`
Run `python3 forge/validate.py npc forge_output/npcs/{{npc_id}}.json` to verify.
