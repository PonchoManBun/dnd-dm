#!/usr/bin/env bash
# Automated playtest driver for The Welcome Wench.
# Polls DebugMonitor JSON sidecars, calls playtest_brain.py for decisions,
# sends input via xdotool, logs results.
#
# Usage: scripts/playtest.sh [--max-turns N]
#
# Requires: monitor.sh already ran setup+launch, game is running.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCREENSHOT_DIR="$PROJECT_DIR/game/screenshots"
BRAIN="$SCRIPT_DIR/playtest_brain.py"
LOG_FILE="/tmp/playtest_log.json"
STDOUT_LOG="/tmp/godot-stdout.log"

# Source e2e helpers for send_key
source "$SCRIPT_DIR/jetson_e2e.sh"

MAX_TURNS="${1:-20}"
if [[ "${1:-}" == "--max-turns" ]]; then
    MAX_TURNS="${2:-20}"
fi

POLL_INTERVAL=2.5  # seconds between action cycles
STUCK_THRESHOLD=10 # consecutive same-state polls before declaring stuck
TIMEOUT_SECONDS=600 # 10 minute hard limit

# --- State tracking ---
last_turn=""
last_pos=""
last_state_fp=""
stuck_counter=0
run_start=$(date +%s)
run_id="$run_start"
turns_survived=0
max_depth_reached=0
result="unknown"
godot_errors=""

echo "==> Playtest started (run_id=$run_id, max_turns=$MAX_TURNS)"

find_latest_json() {
    # Find the most recent shot JSON
    ls -t "$SCREENSHOT_DIR"/shot_*.json 2>/dev/null | head -1 || true
}

check_godot_alive() {
    pgrep -f godot >/dev/null 2>&1
}

collect_errors() {
    # Grep for errors in godot stdout log
    if [ -f "$STDOUT_LOG" ]; then
        grep -i -E 'ERROR|SCRIPT ERROR|push_error|assertion|FATAL' "$STDOUT_LOG" 2>/dev/null | tail -20 || true
    fi
}

write_log() {
    local end_time
    end_time=$(date +%s)
    local duration=$(( end_time - run_start ))

    # Collect any godot errors into a temp file
    collect_errors > /tmp/playtest_errors.txt 2>/dev/null || true

    # Write JSON log entry via Python (reads errors from temp file)
    python3 << PYEOF
import json

errors = []
try:
    with open("/tmp/playtest_errors.txt") as f:
        errors = [l.strip() for l in f if l.strip()]
except FileNotFoundError:
    pass

entry = {
    "run_id": $run_id,
    "result": "$result",
    "turns_survived": $turns_survived,
    "max_depth": $max_depth_reached,
    "duration_seconds": $duration,
    "godot_errors": errors
}

try:
    with open("$LOG_FILE", "r") as f:
        log = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    log = []

log.append(entry)
with open("$LOG_FILE", "w") as f:
    json.dump(log, f, indent=2)

print(json.dumps(entry, indent=2))
PYEOF
}

# --- Main loop ---
cycle=0
while true; do
    cycle=$((cycle + 1))

    # Check timeout (10 min hard limit)
    elapsed=$(( $(date +%s) - run_start ))
    if [ "$elapsed" -ge "$TIMEOUT_SECONDS" ]; then
        echo "==> Timeout after ${TIMEOUT_SECONDS}s"
        result="timeout"
        break
    fi

    # Check if godot is still running
    if ! check_godot_alive; then
        echo "==> Godot process died — crash detected"
        result="crash"
        break
    fi

    # Find latest JSON sidecar
    json_file=$(find_latest_json)
    if [ -z "$json_file" ]; then
        echo "    [cycle $cycle] No screenshots yet, waiting..."
        sleep "$POLL_INTERVAL"
        continue
    fi

    # Read key state fields in one Python call
    eval "$(python3 -c "
import json
try:
    d = json.load(open('$json_file'))
    print('scene=%s' % d.get('scene','unknown'))
    print('turn=%s' % d.get('turn',0))
    print('game_over=%s' % d.get('game_over',False))
    print('pos=\"%s\"' % d.get('player_pos','[-1,-1]'))
    print('depth=%s' % d.get('depth',0))
    print('max_depth_val=%s' % d.get('max_depth',0))
    # Build state fingerprint for stuck detection (changes during combat too)
    cs = d.get('combat_state') or {}
    fp_parts = [str(d.get('turn',0)), str(d.get('player_pos','')),
                str(d.get('game_mode','')), str(d.get('player_hp','')),
                str(cs.get('is_player_turn','')), str(cs.get('has_action','')),
                str(cs.get('movement_remaining',''))]
    print('state_fp=\"%s\"' % '|'.join(fp_parts))
except Exception:
    print('scene=unknown')
    print('turn=0')
    print('game_over=False')
    print('pos=\"[-1,-1]\"')
    print('depth=0')
    print('max_depth_val=0')
    print('state_fp=\"unknown\"')
" 2>/dev/null)"

    turns_survived="$turn"
    max_depth_reached="$max_depth_val"

    # End conditions
    if [ "$scene" = "death_screen" ]; then
        echo "==> Death screen detected at turn $turn"
        result="death"
        break
    fi

    if [ "$game_over" = "True" ]; then
        echo "==> Game over at turn $turn"
        result="game_over"
        break
    fi

    if [ "$turn" -ge "$MAX_TURNS" ] 2>/dev/null; then
        echo "==> Max turns ($MAX_TURNS) reached"
        result="max_turns"
        break
    fi

    # Stuck detection — same state fingerprint for too many cycles means game isn't advancing
    if [ "$state_fp" = "$last_state_fp" ]; then
        stuck_counter=$((stuck_counter + 1))
        if [ "$stuck_counter" -ge "$STUCK_THRESHOLD" ]; then
            echo "==> Stuck detected (state unchanged for $STUCK_THRESHOLD cycles: $state_fp)"
            result="stuck"
            break
        fi
    else
        stuck_counter=0
        last_state_fp="$state_fp"
    fi
    last_turn="$turn"

    # Ask the brain what to do
    key=$(python3 "$BRAIN" "$json_file" 2>/dev/null || echo "x")

    # __wait__ means game isn't ready for input — don't count toward stuck
    if [ "$key" = "__wait__" ]; then
        stuck_counter=$((stuck_counter > 0 ? stuck_counter - 1 : 0))
        sleep 1
        continue
    fi

    echo "    [cycle $cycle] turn=$turn pos=$pos depth=$depth key=$key"

    # Send the key
    send_key "$key" >/dev/null 2>&1 || true

    sleep "$POLL_INTERVAL"
done

echo "==> Playtest ended: result=$result turns=$turns_survived depth=$max_depth_reached"
write_log
