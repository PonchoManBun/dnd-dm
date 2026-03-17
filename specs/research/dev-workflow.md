# Development Workflow: Jetson Orin Nano

## Overview

TWW is developed and played directly on the **Jetson Orin Nano**. All editing, version control, Godot scene work, LLM testing, and gameplay happen on-device.

```
┌─────────────────────────────────────────────┐
│  Jetson Orin Nano (8GB)                      │
│                                              │
│  - Claude Code CLI (development)             │
│  - Godot 4.6.1 (game editor + runtime)       │
│  - Ollama + Llama 3.2 3B (GPU inference)     │
│  - Python Orchestrator (Phase 2+)            │
│  - Git / GitHub                              │
└─────────────────────────────────────────────┘
```

## 1. Git Workflow

GitHub is the remote for the project:

```bash
# Work on feature, commit, push
git add -A && git commit -m "Add feature X"
git push origin master
```

## 2. Running the Game

```bash
# Editor mode
godot --path ~/dnd-dm/game/ -e

# Play mode
godot --path ~/dnd-dm/game/

# Headless validation
godot --path ~/dnd-dm/game/ --headless --quit
```

Godot 4.6.1 is installed at `/usr/local/bin/godot` (ARM64 Linux build).

## 3. Python Orchestrator

The Python orchestrator runs locally on the Jetson:

```bash
cd ~/dnd-dm/orchestrator
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000
```

## 4. Claude Code CLI (Forge Mode)

The persistent Claude Code CLI session for Forge Mode runs locally:

```bash
cd ~/dnd-dm/forge
claude
```

The orchestrator communicates with this session during gameplay. See `specs/phase-1-core/forge-mode.md` for details.

## 5. Remote Access (Optional)

For SSH access from another machine:

```
Host jetson
    HostName 192.168.2.1
    User jetson
```

VS Code Remote-SSH is supported for remote editing when needed.

## Summary

| Task | Tool |
|------|------|
| Edit code, specs, scenes | Claude Code CLI, Godot Editor |
| Run game, LLM, orchestrator | Godot, Ollama, Python |
| Forge Mode (Claude) | Claude Code CLI |
| Version control | Git + GitHub |
