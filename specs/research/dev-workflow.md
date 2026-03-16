# Development Workflow: Windows 11 Laptop → Jetson Orin Nano

## Overview

TWW is developed on a **Windows 11 laptop** and deployed/played on the **Jetson Orin Nano**. The laptop handles editing, version control, and Godot scene work. The Jetson runs the game with local LLM and Forge Mode.

```
┌─────────────────────┐         ┌─────────────────────────┐
│  Windows 11 Laptop  │  SSH/   │  Jetson Orin Nano       │
│                     │  git/   │                         │
│  - VS Code          │  rsync  │  - Godot 4 (ARM64)     │
│  - Godot Editor     │ ──────▶ │  - Ollama + Llama 3.2  │
│  - Git / GitHub     │         │  - Python Orchestrator  │
│  - Claude Code      │         │  - Claude Code CLI      │
└─────────────────────┘         └─────────────────────────┘
```

## 1. SSH Setup

JetPack 6.2 includes SSH by default. Windows 11 has a built-in OpenSSH client.

### Key-based authentication
```bash
# On Windows (PowerShell)
ssh-keygen -t ed25519 -C "tww-dev"
type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh user@jetson "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

### SSH config (~/.ssh/config)
```
Host jetson
    HostName 192.168.2.1
    User jetson
    IdentityFile C:\Users\ctsul\.ssh\poncho_ed25519
```

**Connection:** Direct ethernet cable between laptop and Jetson. Laptop is 192.168.2.2, Jetson is 192.168.2.1. No router involved.

Then: `ssh jetson`

## 2. VS Code Remote-SSH

VS Code Remote-SSH supports ARM64 targets (the VS Code server runs on the Jetson):

1. Install the **Remote - SSH** extension
2. Connect to `jetson` host
3. Open the project directory on the Jetson
4. Edit Python orchestrator code, GDScript, configs directly on the Jetson

Best for: editing Python orchestrator code, debugging on-device, checking Ollama logs.

## 3. Git Workflow

GitHub is the intermediary between laptop and Jetson:

```
Windows (edit) → git push → GitHub → git pull → Jetson (run)
```

### On Windows
```bash
# Work on feature, commit, push
git add -A && git commit -m "Add feature X"
git push origin master
```

### On Jetson
```bash
# Pull latest and restart services
git pull origin master
# Restart orchestrator, reload Godot, etc.
```

For rapid iteration, use rsync (see below) instead of git for uncommitted changes.

## 4. Godot Export (ARM64 Linux)

Godot 4.2+ supports cross-compilation to ARM64 Linux from the Windows editor:

1. Download **ARM64 Linux export templates** from godotengine.org
2. In Godot Editor (Windows): Project → Export → Add "Linux/ARM64"
3. Export the .pck or standalone binary
4. Transfer to Jetson via rsync or git

For development, you can also run the Godot editor on the Jetson via SSH X11 forwarding or VNC, but the Windows editor is faster for scene/UI work.

## 5. rsync Deploy (via WSL)

For fast file transfer of uncommitted changes, use rsync through WSL:

```bash
# From WSL on Windows
rsync -avz --exclude='.git' --exclude='__pycache__' --exclude='.venv' \
  /mnt/c/dev/dnd-dm/ jetson:~/dnd-dm/
```

This syncs the full project in seconds. Use for rapid iteration when git commits would be too slow.

### Exclude patterns
```
.git/
__pycache__/
.venv/
*.pyc
.godot/imported/
export/
```

## 6. Python Orchestrator

The Python orchestrator runs on the Jetson. Each platform gets its own virtual environment:

```bash
# On Jetson
cd ~/dnd-dm/orchestrator
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000
```

**Never copy venvs between platforms.** ARM64 (Jetson) and x86_64 (Windows) have incompatible compiled packages. Always create a fresh venv per platform from `requirements.txt`.

## 7. Claude Code CLI (Forge Mode)

The persistent Claude Code CLI session for Forge Mode runs on the Jetson:

```bash
# On Jetson — start the forge session
cd ~/dnd-dm/forge
claude
```

The orchestrator communicates with this session during gameplay. See `specs/phase-1-core/forge-mode.md` for details.

For development, Claude Code also runs on the Windows laptop for writing code, specs, and debugging.

## Summary

| Task | Where | Tool |
|------|-------|------|
| Edit code, specs, scenes | Windows laptop | VS Code, Godot Editor |
| Run game, LLM, orchestrator | Jetson | Godot, Ollama, Python |
| Forge Mode (Claude) | Jetson | Claude Code CLI |
| Version control | Both | Git + GitHub |
| Fast deploy | Windows → Jetson | rsync via WSL |
| On-device debugging | Jetson | VS Code Remote-SSH |
