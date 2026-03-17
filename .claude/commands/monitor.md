---
description: "Visual debugging monitor — capture, analyze, and fix game visuals on Jetson remotely"
allowed-tools: Bash, Read, Edit, Write, Glob, Grep, Agent
---

# Visual Debugging Monitor

You are monitoring The Welcome Wench running on the Jetson Orin Nano. The game's `DebugMonitor` autoload captures viewport screenshots (576x324) every 5 seconds with JSON metadata sidecars when monitoring is active.

## Command: $ARGUMENTS

Parse the first word of the arguments to determine the subcommand. Default to `grab` if no arguments given.

---

### Subcommand: `start`

Start a monitoring session. Run these steps:

```bash
scripts/monitor.sh setup
scripts/monitor.sh sync
scripts/monitor.sh launch
```

Wait for each to complete. Report success/failure. If launch fails, show the user how to check logs.

After launch succeeds, wait 8 seconds, then automatically run a `grab` to verify screenshots are being captured. If screenshots appear, report "Monitoring active" with the first screenshot. If not, troubleshoot (check sentinel file, check Godot logs).

---

### Subcommand: `grab` (default if no args)

Grab and analyze the latest screenshots:

1. Run `scripts/monitor.sh grab 3` to fetch the latest 3 screenshots + JSON sidecars to `/tmp/dnd-screenshots/`
2. List the files that were fetched
3. For each screenshot (newest first):
   a. Read the JSON sidecar first — note the scene, turn, HP, monster count, and UI state
   b. Read the PNG with the Read tool — visually analyze the viewport
4. Analyze each screenshot against the expected visuals for that screen:

**Expected visuals by scene:**

| Scene | Expected |
|-------|----------|
| `menu` | Dark background, "The Welcome Wench" title, Play/Continue/Quit buttons |
| `character_creation` | Step indicator at top, race/class/ability/name panels with pixel art |
| `dm_selection` | DM persona selection cards |
| `game` | Left ~2/3 is dungeon tilemap + HUD (HP bar, messages), right ~1/3 is DM panel. Initiative tracker visible only if combat. SRD overlay covers screen when visible. |
| `death_screen` | Dark overlay with "YOU HAVE FALLEN" text, memorial stats |

5. Report findings concisely. Flag any of these issues:
   - **Black/blank screen** — crash or failed scene load
   - **Missing UI elements** — no HUD, no DM panel, no initiative in combat
   - **UI overlap/clipping** — elements overlapping incorrectly
   - **Raw BBCode visible** — `[color=...]` tags showing as text
   - **State mismatch** — JSON says combat but no initiative tracker, JSON says game but screenshot shows menu
   - **Frozen game** — multiple consecutive screenshots are identical (same turn, same state)
   - **Missing textures** — pink/magenta rectangles (Godot's missing texture indicator)
   - **Z-order bugs** — shader effects rendering on top of UI elements
   - **Unexpected modal** — modal_visible=true when nothing should be open

If everything looks good, say so briefly with the key state (scene, turn, HP, monsters).

---

### Subcommand: `watch`

Continuous monitoring mode. Run `grab` analysis, then tell the user you'll continue monitoring. Ask them to run `/monitor grab` or `/monitor watch` again when they want the next check. (Claude Code can't loop autonomously, so this is manual polling.)

---

### Subcommand: `fix`

The user has identified or you have detected a visual bug. Run the fix cycle:

1. Grab the latest screenshot as evidence: `scripts/monitor.sh grab 1`
2. Read the screenshot and JSON — describe the bug clearly
3. Ask the user to confirm the bug diagnosis before proceeding
4. Search the codebase for the likely cause (use Agent for broad searches if needed)
5. Apply the fix via Edit tool
6. Reload the game: `scripts/monitor.sh reload`
7. Wait 8 seconds for the game to start and DebugMonitor to capture
8. Grab a new screenshot: `scripts/monitor.sh grab 1`
9. Read the new screenshot — verify the fix
10. Report whether the fix worked. If not, iterate.

---

### Subcommand: `reload`

Quick code sync and game restart without full analysis:

```bash
scripts/monitor.sh reload
```

Wait 8 seconds, then run a `grab` to verify the game restarted.

---

### Subcommand: `stop`

Tear down the monitoring session:

```bash
scripts/monitor.sh teardown
```

Report that monitoring is disabled.

---

### Subcommand: `status`

Check the current state of the Jetson:

```bash
scripts/monitor.sh status
```

Report results.

---

## Important Notes

- Screenshots are 576x324 pixel art — small and low-res is expected, not a bug.
- The game uses a CanvasModulate with a cold desaturated tint — slightly blue/purple colors are intentional.
- The ambient vignette shader darkens edges — this is intentional, not a rendering bug.
- DM panel takes the rightmost ~1/3 of the viewport in the game scene.
- Screenshots land in `/tmp/dnd-screenshots/`.
- Never guess at bugs — only flag things you can clearly see in the screenshot.
- Be concise. The user is playing the game and doesn't want walls of text.
