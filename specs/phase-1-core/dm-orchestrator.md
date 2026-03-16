# DM Orchestrator Design

## What It Is

The DM Orchestrator is a Python/FastAPI service running on the Jetson that coordinates between the Godot game client, the local LLM (Ollama), and Forge Mode (Claude Code CLI). It is the central nervous system of the game.

## Responsibilities

1. **Accept player actions** from Godot via HTTP (localhost)
2. **Apply deterministic rules** — dice rolls, combat math, SRD lookups
3. **Build LLM prompts** — assemble context (game state, archetype, history, rules results)
4. **Route to local LLM** — send prompt to Ollama, receive narration
5. **Maintain game state** — read/write JSON state files
6. **Manage conversation history** — sliding window with compression
7. **Forge trigger detection** — decide when to invoke Forge Mode (blocking, player waits)
8. **Deliver responses** — send combined result (narration + state changes) to Godot

## API Endpoints

```
POST /action          — Player takes an action
  Body: { "type": "move|attack|interact|speak|custom", "target": "...", "text": "..." }
  Response: { "narration": "...", "choices": [...], "state_delta": {...} }

GET  /state           — Current game state
  Response: Full GameState JSON

POST /character/create — Start character creation
  Body: { "name": "...", "race": "...", "class": "..." }
```

## DM Response Flow (Detailed)

```python
async def handle_action(action: PlayerAction) -> DmResponse:
    # 1. Load current game state
    state = load_game_state()

    # 2. Apply deterministic rules
    rules_result = rules_engine.resolve(action, state)
    # e.g., { "attack_roll": 17, "hits": True, "damage": 8, "target_hp": 12 }

    # 3. Update game state with rules results
    state = apply_rules_result(state, rules_result)

    # 4. Check forge triggers BEFORE narration
    forge_triggers = check_forge_triggers(action, state)
    if forge_triggers:
        # Blocking call — player sees "Generating..." in-game
        for trigger in forge_triggers:
            forge_content = invoke_forge(trigger)  # sends to persistent CLI session
            load_forge_content(state, forge_content)

    # 5. Build LLM prompt
    prompt = build_dm_prompt(
        archetype=state.dm_archetype,
        action=action,
        rules_result=rules_result,
        state_summary=summarize_state(state),
        recent_history=get_recent_history(n=5),
        npc_context=get_npc_context(action.target) if action.involves_npc else None
    )

    # 6. Call local LLM
    llm_response = await ollama.chat(
        model="llama3.2:3b",
        messages=[{"role": "user", "content": prompt}]
    )

    # 7. Parse LLM response (narration + choices)
    narration, choices = parse_dm_response(llm_response)

    # 8. Save updated state + conversation history
    save_game_state(state)
    append_history(action, narration)

    # 9. Return response to Godot
    return DmResponse(
        narration=narration,
        choices=choices,
        state_delta=compute_state_delta(old_state, state)
    )
```

## Forge Invocation

The orchestrator communicates with a **persistent Claude Code CLI session** running in the `forge/` subdirectory:

```python
def invoke_forge(trigger: ForgeTrigger) -> ForgeContent:
    # 1. Send /clear to reset CLI context
    cli_session.send("/clear")

    # 2. Build the forge prompt
    prompt = build_forge_prompt(trigger)

    # 3. Send prompt to CLI session
    cli_session.send(prompt)

    # 4. Wait for output files in forge_output/
    content = wait_for_forge_output(trigger.expected_output)

    return content
```

The CLI session is started once at game boot and persists for the game's lifetime. Each forge request does `/clear` first, so Claude re-reads `forge/CLAUDE.md` and starts with a clean context.

## Forge Trigger Detection

```python
def check_forge_triggers(action, state) -> list[ForgeTrigger]:
    triggers = []

    # New dungeon floor
    if action.type == "descend" and not state.has_floor(state.current_floor + 1):
        triggers.append(ForgeTrigger("dungeon", {
            "theme": state.dungeon_theme,
            "difficulty": state.player_level,
            "floor": state.current_floor + 1
        }))

    # Boss encounter approaching
    if state.rooms_explored_this_floor >= state.total_rooms * 0.8:
        if not state.boss_generated_this_floor:
            triggers.append(ForgeTrigger("monster", {
                "cr": state.player_level + 2,
                "type": "boss",
                "context": state.narrative_summary
            }))

    # Level up
    if state.player.xp >= state.player.xp_to_next_level:
        triggers.append(ForgeTrigger("narrative", {
            "type": "level_up",
            "class": state.player.character_class,
            "new_level": state.player.level + 1
        }))

    return triggers
```

## Rules Engine

The rules engine handles all deterministic D&D 5e mechanics:

```python
class RulesEngine:
    def __init__(self, srd_path: str):
        self.srd = load_srd_rules(srd_path)

    def roll_dice(self, notation: str) -> DiceResult:
        """Roll dice: '2d6+3', '1d20', etc."""

    def attack_roll(self, attacker, target) -> AttackResult:
        """d20 + attack_bonus vs AC"""

    def damage_roll(self, damage_dice: str, damage_type: str) -> DamageResult:
        """Roll damage, apply resistances/vulnerabilities"""

    def saving_throw(self, target, ability: str, dc: int) -> SaveResult:
        """d20 + save_modifier vs DC"""

    def apply_condition(self, target, condition: str) -> None:
        """Apply SRD condition (poisoned, prone, stunned, etc.)"""

    def check_ability(self, character, ability: str, dc: int) -> CheckResult:
        """Ability check: d20 + modifier vs DC"""
```

## Context Management

The local LLM has limited context (2048 tokens). The orchestrator carefully manages what goes in:

| Segment | Tokens | Content |
|---------|--------|---------|
| System prompt | ~300 | DM archetype + behavior rules |
| Current state | ~200 | Player stats, location, conditions |
| Recent history | ~500-800 | Last 3-5 exchanges (compressed) |
| Action context | ~200 | Current action + dice results |
| NPC context | ~200 | If interacting with NPC |
| Available for response | ~500-800 | LLM generates here |

### History Compression

When conversation history exceeds the window:
1. Oldest exchanges get summarized into 1-2 bullet points
2. Key events (combat outcomes, quest progress, NPC meetings) are preserved
3. Routine exchanges (movement, basic exploration) are discarded

## Tech Stack

- **Python 3.10+** — async/await throughout
- **FastAPI** — HTTP API framework
- **Ollama Python SDK** — local LLM communication
- **Claude Code CLI** — persistent session for Forge Mode content generation
- **JSON files** — game state persistence (simple, readable by all layers)
- **D&D 5e SRD** — markdown files loaded and indexed for rules lookups
