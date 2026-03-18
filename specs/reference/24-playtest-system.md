# 24 — Playtest System

## Overview

The Welcome Wench uses a **two-tier automated playtest system** to validate gameplay without manual testing. Both tiers run on the Jetson Orin Nano, the same hardware the game is developed and played on.

- **Tier 1** -- Fast heuristic brain. A Python script reads game state JSON and sends keypresses via `xdotool`. Catches crashes, stuck states, and basic gameplay loops. Runs in under 2 minutes.
- **Tier 2** -- Claude agent ("the-player"). A multimodal AI reads PNG screenshots and JSON state each turn, reasons about strategy, and reports bugs that heuristics miss (UI glitches, narrative issues, balance problems).

Both tiers are built on a shared infrastructure layer: `monitor.sh` manages the game process and `debug_monitor.gd` captures game state.

**Status: Implemented**

---

## Infrastructure

### Component Map

```
scripts/
├── monitor.sh           # Game lifecycle (setup, launch, kill, grab screenshots)
├── playtest.sh           # Tier 1 turn driver (polls state, calls brain, sends keys)
├── playtest_brain.py     # Tier 1 heuristic decision engine
├── the_player_prompt.md  # Tier 2 agent prompt template
└── jetson_e2e.sh         # Shared helper (send_key via xdotool)

game/src/
└── debug_monitor.gd      # In-game autoload: captures PNG + JSON every 2-5 seconds
```

### DebugMonitor (`game/src/debug_monitor.gd`)

An autoload Node that runs inside the Godot process. Captures viewport screenshots and game state metadata at regular intervals.

**Activation**: Only runs when the sentinel file `res://screenshots/.monitoring` exists. Created by `monitor.sh setup`.

**Capture intervals**:
- Normal mode: every 5 seconds (`DEFAULT_CAPTURE_INTERVAL`)
- Playtest mode: every 2 seconds (`PLAYTEST_CAPTURE_INTERVAL`), activated by `--skip-menu` CLI arg

**Output**: Rolling window of the last 100 screenshots in `game/screenshots/`:
- `shot_NNNN.png` -- viewport screenshot
- `shot_NNNN.json` -- game state sidecar

**JSON sidecar fields**:

| Field | Type | Description |
|---|---|---|
| `scene` | `string` | Current screen: `game`, `menu`, `character_creation`, `dm_selection`, `death_screen`, `quit` |
| `timestamp` | `string` | ISO datetime |
| `shot` | `int` | Screenshot counter |
| `turn` | `int` | Current game turn number |
| `game_over` | `bool` | Whether game is over |
| `depth` | `int` | Current dungeon floor depth |
| `max_depth` | `int` | Deepest floor reached this run |
| `player_hp` | `int` | Current player HP |
| `player_max_hp` | `int` | Maximum player HP |
| `player_name` | `string` | Player character name |
| `player_pos` | `[int, int]` | Player grid position `[x, y]` |
| `waiting_for_input` | `bool` | Whether the game is waiting for player input |
| `walkable_neighbors` | `[[int,int], ...]` | List of walkable adjacent tile positions |
| `monsters_visible` | `[{pos, name, hp, hostile}, ...]` | Visible monsters with positions and hostility |
| `monster_count` | `int` | Total monsters on current map (excluding player) |
| `items_at_feet` | `[{name}, ...]` | Items on the player's tile |
| `stairs_down_pos` | `[int, int] \| null` | Position of stairs down on current map |
| `stairs_up_pos` | `[int, int] \| null` | Position of stairs up on current map |
| `dm_text_length` | `int` | Number of entries in narrative history |
| `initiative_visible` | `bool` | Whether initiative tracker UI is showing |
| `modal_visible` | `bool` | Whether a modal dialog is visible |
| `game_mode` | `string` | `exploration` or `combat` |
| `combat_state` | `object \| null` | Combat details when in combat mode |

**Combat state sub-fields** (when `game_mode == "combat"`):

| Field | Type | Description |
|---|---|---|
| `is_player_turn` | `bool` | Whether it is the player's turn |
| `movement_remaining` | `int` | Tiles of movement left this turn |
| `has_action` | `bool` | Whether the player has an action available |
| `combatants` | `[{name, initiative, hp}, ...]` | All combatants in initiative order |

### Monitor Script (`scripts/monitor.sh`)

Shell script that manages the game process lifecycle. Commands:

| Command | Description |
|---|---|
| `setup` | Create sentinel file `.monitoring`, clean old screenshots |
| `launch [--skip-menu]` | Start Godot in background. `--skip-menu` bypasses menus and goes straight to gameplay. Waits up to 15s for the game window to appear. |
| `grab [N]` | Copy latest N screenshots (default 3) to `/tmp/dnd-screenshots/` |
| `kill` | Kill all Godot processes |
| `reload` | Kill + relaunch |
| `teardown` | Remove sentinel, clean screenshots |
| `status` | Report monitoring enabled/disabled, screenshot count, Godot running/not |

**Environment**: Sets `DISPLAY=:1` and `XAUTHORITY` for headless-compatible X11 operation on Jetson.

**Logs**: Godot stdout goes to `/tmp/godot-stdout.log`, stderr to `/tmp/godot-stderr.log`.

---

## Tier 1 -- Fast Heuristic Tests

### Playtest Driver (`scripts/playtest.sh`)

The outer loop that drives a Tier 1 test. Polls `DebugMonitor` JSON sidecars, calls `playtest_brain.py` for decisions, and sends input via `xdotool`.

**Parameters**:
- `--max-turns N` -- Maximum turns before stopping (default: 20)
- Poll interval: 2.5 seconds between action cycles
- Stuck threshold: 10 consecutive identical state fingerprints
- Hard timeout: 600 seconds (10 minutes)

**State fingerprint**: Built from `turn`, `player_pos`, `game_mode`, `player_hp`, `is_player_turn`, `has_action`, and `movement_remaining`. If the fingerprint is unchanged for 10 consecutive polls, the game is declared stuck.

**End conditions** (checked each cycle):

| Condition | Result Code | Description |
|---|---|---|
| Death screen detected | `death` | Scene is `death_screen` |
| `game_over` flag true | `game_over` | Game state reports game over |
| Max turns reached | `max_turns` | Turn count >= `--max-turns` |
| State unchanged 10 cycles | `stuck` | Game is not advancing |
| Godot process died | `crash` | `pgrep -f godot` fails |
| 10 minutes elapsed | `timeout` | Hard time limit exceeded |

**Output**: Results are written to `/tmp/playtest_log.json` as a JSON array:

```json
[
  {
    "run_id": 1710000000,
    "result": "max_turns",
    "turns_survived": 20,
    "max_depth": 2,
    "duration_seconds": 85,
    "godot_errors": []
  }
]
```

### Playtest Brain (`scripts/playtest_brain.py`)

The heuristic decision engine. Reads a single JSON sidecar file and outputs one key name to stdout.

**Decision hierarchy**:

#### Exploration Mode

1. **Pick up items** at feet (key: `p`)
2. **Low HP** (< 30% max) -- wait/rest (key: `x`)
3. **Move toward stairs down** (70% of the time, to progress through the dungeon)
4. **Stand on stairs** -- descend (key: `greater`)
5. **Move toward nearest hostile** (to trigger combat)
6. **Random exploration** -- pick a random walkable neighbor

#### Combat Mode

1. **Not player's turn** -- wait (key: `x`, outputs `__wait__` sentinel)
2. **No visible hostiles** -- end turn (key: `space`)
3. **Adjacent hostile + have action** -- bump to attack (direction key toward monster)
4. **Adjacent hostile + no action** -- end turn (key: `space`)
5. **Have movement + action + not adjacent** -- move toward nearest hostile
6. **Exhausted** -- end turn (key: `space`)

#### Non-Game Screens

- Menu, character creation, death screen, modals: press `Return` to dismiss/advance
- `waiting_for_input` is false: output `__wait__` (don't send input yet)

**Key mapping**:

| Key | Action |
|-----|--------|
| `w/a/s/d` | 4-direction movement (up/left/down/right) |
| `q/e/z/c` | Diagonal movement (up-left/up-right/down-left/down-right) |
| `p` | Pick up item |
| `greater` | Descend stairs (>) |
| `space` | End combat turn |
| `x` | Wait/rest |
| `period` | Wait (fallback) |
| `Return` | Dismiss modal / advance menu |

---

## Tier 2 -- Deep AI Tests (the-player)

### Agent Architecture

Tier 2 spawns a Claude agent ("the-player") that plays the game using **multimodal reasoning** -- it reads both PNG screenshots and JSON state each turn. The agent prompt is defined in `scripts/the_player_prompt.md`.

### What Tier 2 Catches That Tier 1 Misses

| Category | Example |
|---|---|
| **UI bugs** | Initiative tracker overlapping DM panel text |
| **Visual glitches** | Sprite rendering errors, incorrect tile colors |
| **Narrative issues** | DM text that doesn't match game state, broken BBCode |
| **Balance problems** | "Every fight is trivially easy" or "I die instantly every time" |
| **Input responsiveness** | Keys not registering, unexpected delays |
| **State mismatches** | JSON says 3 monsters but screenshot shows 2 |

### Agent Workflow

1. **Setup**: Run `monitor.sh setup` + `monitor.sh launch --skip-menu`
2. **Wait**: 5 seconds for the game to start
3. **Game loop** (repeat each turn):
   - Find latest screenshot: `ls -t game/screenshots/shot_*.json | head -1`
   - Read the JSON state file
   - Read the corresponding PNG screenshot (multimodal vision)
   - Reason about the best action
   - Send key via `source scripts/jetson_e2e.sh && send_key <key>`
   - Wait 3 seconds for the game to process
4. **Termination**: Stop on `game_over`, death, 20 turns, or ~8 minutes elapsed
5. **Cleanup**: Run `monitor.sh kill`

### Agent Report Format

At the end of a Tier 2 test, the agent produces:

- **Turns survived**: N
- **Cause of death**: (if died)
- **Bugs found**: List with description and evidence
- **Balance notes**: Observations about difficulty
- **Suggestions**: Improvements for the game

---

## Test Workflows

### Standalone Tier 1 Test

The most common test. Quick validation that the game runs without crashing or getting stuck.

```bash
scripts/monitor.sh setup
scripts/monitor.sh launch --skip-menu
sleep 5
scripts/playtest.sh --max-turns 20
scripts/monitor.sh kill
# Check results:
cat /tmp/playtest_log.json
```

**Expected duration**: 1-2 minutes.

### Standalone Tier 2 Test

Deeper test with AI reasoning. Used after significant changes or when Tier 1 passes but something still feels wrong.

```python
Agent(
    description="the-player: smart playtest",
    prompt=<contents of scripts/the_player_prompt.md PROMPT section>,
)
```

**Expected duration**: 3-8 minutes.

### Full Validation (3x Tier 1 + 1x Tier 2)

The comprehensive workflow. Run 3 Tier 1 tests to confirm basic stability, then 1 Tier 2 test for depth. If any test finds a bug, spawn a fix agent in a worktree.

```
Run 1 (Tier 1): playtest --max-turns 20  -> expect max_turns or game_over
Run 2 (Tier 1): playtest --max-turns 20  -> expect max_turns or game_over
Run 3 (Tier 1): playtest --max-turns 20  -> expect max_turns or game_over
Run 4 (Tier 2): the-player agent         -> expect clean report

If any run reports crash/stuck/bug:
  -> Spawn fix agent in worktree
  -> Fix agent reads error logs + playtest report
  -> Fix agent patches the bug
  -> Re-run failing test to confirm fix
```

---

## Result Classification

### Test Outcomes

| Result | Meaning | Action |
|---|---|---|
| `max_turns` | Survived all turns without issues | Clean -- no action needed |
| `game_over` | Game ended normally (death or victory) | Clean -- check if death was reasonable |
| `death` | Death screen reached | Clean if intentional. Check balance if too frequent. |
| `crash` | Godot process died | **Critical bug** -- check `/tmp/godot-stderr.log` |
| `stuck` | Game state unchanged for 10+ cycles | **Bug** -- game is hung, likely waiting for impossible input |
| `timeout` | 10 minutes exceeded | **Bug** -- game is running but not progressing |

### Classification Categories

| Category | Criteria | Priority |
|---|---|---|
| **Clean** | `max_turns` or `game_over` with no errors in `godot_errors` | None |
| **Bug** | `stuck` or `timeout`, or `max_turns` with errors in `godot_errors` | HIGH |
| **Critical** | `crash` | HIGHEST |
| **Balance** | Tier 2 reports consistent difficulty issues | MEDIUM |

---

## Protected Files

The playtest infrastructure files are **protected** and should not be modified during bug fixes or feature work (unless the fix is specifically to the playtest system itself):

- `scripts/playtest.sh`
- `scripts/playtest_brain.py`
- `scripts/the_player_prompt.md`
- `scripts/monitor.sh`
- `scripts/jetson_e2e.sh`
- `game/src/debug_monitor.gd`

This prevents accidental breakage of the test harness while fixing game bugs. These files are listed in `@AGENT.md` under "Protected files."
