#!/usr/bin/env bash
# E2E testing helper for The Welcome Wench on Jetson Orin Nano.
# Deploy to Jetson, then call functions via SSH one-liners.
#
# Usage from Windows (via SSH):
#   ssh jetson@192.168.2.1 'source ~/tww/scripts/jetson_e2e.sh && send_key w'
#   ssh jetson@192.168.2.1 'source ~/tww/scripts/jetson_e2e.sh && take_screenshot step1'
#   scp jetson@192.168.2.1:/tmp/e2e_step1.png /tmp/

# --- Environment ---
export DISPLAY="${DISPLAY:-:1}"
export XAUTHORITY="${XAUTHORITY:-/run/user/1000/gdm/Xauthority}"

# --- Window discovery ---
find_window() {
    local wid
    wid=$(xdotool search --name 'Welcome' 2>/dev/null | head -1)
    if [ -z "$wid" ]; then
        echo "ERROR: Game window not found" >&2
        return 1
    fi
    echo "$wid"
}

focus_window() {
    local wid
    wid=$(find_window) || return 1
    xdotool windowactivate --sync "$wid"
    echo "Focused window $wid"
}

# --- Input ---
send_key() {
    local key="${1:?Usage: send_key <key>}"
    local wid
    wid=$(find_window) || return 1
    xdotool windowactivate --sync "$wid"
    sleep 0.1
    xdotool key --window "$wid" "$key"
    echo "Sent key '$key' to window $wid"
}

send_keys() {
    # Send multiple keys with a short delay between each
    local wid
    wid=$(find_window) || return 1
    xdotool windowactivate --sync "$wid"
    sleep 0.1
    for key in "$@"; do
        xdotool key --window "$wid" "$key"
        sleep 0.15
    done
    echo "Sent ${#@} keys to window $wid"
}

click_at() {
    local x="${1:?Usage: click_at <x> <y>}"
    local y="${2:?Usage: click_at <x> <y>}"
    local wid
    wid=$(find_window) || return 1
    xdotool windowactivate --sync "$wid"
    sleep 0.1
    xdotool mousemove --window "$wid" "$x" "$y"
    xdotool click --window "$wid" 1
    echo "Clicked at ($x, $y) in window $wid"
}

# --- Screenshots ---
take_screenshot() {
    local name="${1:-screenshot}"
    local path="/tmp/e2e_${name}.png"
    gnome-screenshot -f "$path" 2>/dev/null
    if [ -f "$path" ]; then
        echo "$path"
    else
        echo "ERROR: Screenshot failed" >&2
        return 1
    fi
}

# --- Game lifecycle ---
launch_game() {
    local project_dir="${1:-$HOME/tww/game}"
    cd "$project_dir" || return 1
    # Kill any existing instance
    pkill -f 'godot.*project.godot' 2>/dev/null
    sleep 0.5
    # Launch in background
    godot --path "$project_dir" &
    local pid=$!
    echo "Launched game (PID $pid), waiting for window..."
    # Wait for window to appear (up to 15 seconds)
    for i in $(seq 1 30); do
        sleep 0.5
        if xdotool search --name 'Welcome' >/dev/null 2>&1; then
            echo "Game window found"
            return 0
        fi
    done
    echo "WARNING: Game window not found after 15s" >&2
    return 1
}

kill_game() {
    pkill -f 'godot.*project.godot' 2>/dev/null
    echo "Game killed"
}

# --- Convenience ---
wait_frames() {
    local count="${1:-10}"
    # ~16ms per frame at 60fps
    local seconds
    seconds=$(echo "scale=3; $count * 0.016" | bc)
    sleep "$seconds"
}

status() {
    local wid
    wid=$(find_window 2>/dev/null)
    if [ -n "$wid" ]; then
        echo "Game running (window $wid)"
    else
        echo "Game not found"
    fi
}

# If script is executed directly (not sourced), run the first argument as a function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    "${@}"
fi
