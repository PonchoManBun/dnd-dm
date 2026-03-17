#!/usr/bin/env bash
# Visual debugging monitor for The Welcome Wench.
# Runs locally on Jetson Orin Nano.
#
# Usage:
#   scripts/monitor.sh setup      # Create sentinel, clean old screenshots
#   scripts/monitor.sh launch     # Start Godot (background)
#   scripts/monitor.sh grab [N]   # Copy latest N screenshots to /tmp/dnd-screenshots/ (default 3)
#   scripts/monitor.sh kill       # Kill Godot
#   scripts/monitor.sh reload     # kill + launch
#   scripts/monitor.sh teardown   # Remove sentinel, clean screenshots
#   scripts/monitor.sh status     # Check monitoring status

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCREENSHOT_DIR="$PROJECT_DIR/game/screenshots"
LOCAL_SCREENSHOT_DIR="/tmp/dnd-screenshots"

# --- Commands ---

cmd_setup() {
    echo "==> Creating sentinel file..."
    mkdir -p "$SCREENSHOT_DIR"
    touch "$SCREENSHOT_DIR/.monitoring"
    echo "==> Cleaning old screenshots..."
    rm -f "$SCREENSHOT_DIR"/shot_*.png "$SCREENSHOT_DIR"/shot_*.json
    mkdir -p "$LOCAL_SCREENSHOT_DIR"
    echo "==> Setup complete. Monitoring enabled."
}

cmd_launch() {
    local skip_menu=""
    for arg in "$@"; do
        if [ "$arg" = "--skip-menu" ]; then
            skip_menu="-- --skip-menu"
        fi
    done

    echo "==> Launching Godot...${skip_menu:+ (skip-menu mode)}"
    export DISPLAY="${DISPLAY:-:1}"
    export XAUTHORITY="${XAUTHORITY:-/run/user/1000/gdm/Xauthority}"
    cd "$PROJECT_DIR/game"
    nohup godot --path . $skip_menu > /tmp/godot-stdout.log 2>/tmp/godot-stderr.log &
    echo "==> Waiting for game window..."
    local found=0
    for i in $(seq 1 30); do
        sleep 0.5
        if xdotool search --name 'Welcome' 2>/dev/null | head -1 | grep -q .; then
            echo "==> Game window found."
            found=1
            break
        fi
    done
    if [ "$found" -eq 0 ]; then
        echo "WARNING: Game window not found after 15s"
        echo "==> Check logs: cat /tmp/godot-stdout.log"
    fi
}

cmd_grab() {
    local count="${1:-3}"
    mkdir -p "$LOCAL_SCREENSHOT_DIR"

    echo "==> Finding latest $count screenshots..."
    local files
    files=$(ls -t "$SCREENSHOT_DIR"/shot_*.png 2>/dev/null | head -"$count" || true)

    if [ -z "$files" ]; then
        echo "No screenshots found."
        return 1
    fi

    echo "==> Copying to $LOCAL_SCREENSHOT_DIR/ ..."
    rm -f "$LOCAL_SCREENSHOT_DIR"/shot_*.png "$LOCAL_SCREENSHOT_DIR"/shot_*.json
    for f in $files; do
        cp "$f" "$LOCAL_SCREENSHOT_DIR/" 2>/dev/null || true
        local json="${f%.png}.json"
        [ -f "$json" ] && cp "$json" "$LOCAL_SCREENSHOT_DIR/" 2>/dev/null || true
    done

    echo "==> Grabbed screenshots:"
    ls -1 "$LOCAL_SCREENSHOT_DIR"/shot_*.png 2>/dev/null || echo "(none)"
}

cmd_kill() {
    echo "==> Killing Godot..."
    pkill -f 'godot' 2>/dev/null || true
    echo "==> Done."
}

cmd_reload() {
    cmd_kill
    sleep 1
    cmd_launch
}

cmd_teardown() {
    echo "==> Removing sentinel and cleaning screenshots..."
    rm -f "$SCREENSHOT_DIR/.monitoring" "$SCREENSHOT_DIR"/shot_*.png "$SCREENSHOT_DIR"/shot_*.json
    rm -f "$LOCAL_SCREENSHOT_DIR"/shot_*.png "$LOCAL_SCREENSHOT_DIR"/shot_*.json
    echo "==> Teardown complete. Monitoring disabled."
}

cmd_status() {
    echo "==> Checking status..."
    if [ -f "$SCREENSHOT_DIR/.monitoring" ]; then
        echo "    Monitoring: enabled"
    else
        echo "    Monitoring: disabled"
    fi

    local shot_count
    shot_count=$(ls "$SCREENSHOT_DIR"/shot_*.png 2>/dev/null | wc -l || echo "0")
    echo "    Screenshots: $shot_count"

    if pgrep -f godot >/dev/null 2>&1; then
        echo "    Godot: running"
    else
        echo "    Godot: not running"
    fi
}

# --- Dispatch ---

cmd="${1:-help}"
shift || true

case "$cmd" in
    setup)    cmd_setup ;;
    launch)   cmd_launch "$@" ;;
    grab)     cmd_grab "$@" ;;
    kill)     cmd_kill ;;
    reload)   cmd_reload ;;
    teardown) cmd_teardown ;;
    status)   cmd_status ;;
    help|*)
        echo "Usage: scripts/monitor.sh <command> [args]"
        echo ""
        echo "Commands:"
        echo "  setup      Create sentinel, clean old screenshots"
        echo "  launch     Start Godot (background)"
        echo "  grab [N]   Copy latest N screenshots (default 3) to /tmp/dnd-screenshots/"
        echo "  kill       Kill Godot"
        echo "  reload     kill + relaunch"
        echo "  teardown   Remove sentinel, clean screenshots"
        echo "  status     Check monitoring status"
        ;;
esac
