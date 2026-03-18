#!/bin/bash
set -e
echo "=== The Welcome Wench ==="

# Max GPU/CPU clocks
echo "[1/4] Setting max clocks..."
sudo jetson_clocks
GPU_MHZ=$(($(cat /sys/devices/platform/bus@0/17000000.gpu/devfreq/17000000.gpu/cur_freq) / 1000000))
echo "  GPU: ${GPU_MHZ} MHz"

# Memory check
FREE=$(free -m | awk '/^Mem:/{print $7}')
echo "[2/4] Available memory: ${FREE} MB"
[ "$FREE" -lt 2000 ] && echo "  WARNING: <2GB free. Close other apps for best LLM performance."

# Restart Ollama for fresh GPU allocation
echo "[3/4] Warming up LLM..."
sudo systemctl restart ollama
sleep 2
ollama run gemma3:1b "ready" > /dev/null 2>&1
ollama ps

# Start orchestrator + game
echo "[4/4] Launching..."
cd /home/jetson/dnd-dm
source orchestrator/.venv/bin/activate
PYTHONPATH=/home/jetson/dnd-dm uvicorn orchestrator.main:app --host 0.0.0.0 --port 8000 &
ORCH_PID=$!
sleep 2
godot --path game/
kill $ORCH_PID 2>/dev/null
