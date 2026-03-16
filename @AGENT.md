# Build / Run / Test Instructions

## Prerequisites

- Godot 4.6.1 — installed on Windows via winget (`godot` or `godot_console` in PATH after shell restart)
- Godot 4 ARM64 — not yet installed on Jetson (LOW priority, Phase 1 task)
- Python 3.10+ (Jetson: 3.10.12, Windows: 3.13.12)
- Ollama 0.18.0 (Jetson: installed, running, Llama 3.2 3B on GPU)
- Anthropic API Key (for Phase 3+ Forge Mode)

## Development Workflow (Windows → Jetson)

Development happens on a **Windows 11 laptop**. Deployment and play happen on the **Jetson Orin Nano**.

```bash
# Push from Windows
git push origin master

# Pull on Jetson
ssh jetson "cd ~/dnd-dm && git pull origin master"

# Or rsync for fast iteration (from WSL)
rsync -avz --exclude='.git' --exclude='__pycache__' --exclude='.venv' \
  /mnt/c/dev/dnd-dm/ jetson:~/dnd-dm/
```

See `specs/research/dev-workflow.md` for full SSH, VS Code Remote-SSH, Godot export, and rsync details.

## Project Structure

```
specs/            # Phase specs, research docs, and reference GDDs
  phase-1-core/   # Current phase specs (architecture, DM, forge, orchestrator)
  research/       # Research documents (legal, base game, file formats, Jetson, MCP, dev workflow)
  reference/      # 20 GDD documents (game design reference, read-only)
rules/            # D&D 5e SRD markdown files
forge/            # Forge Mode working directory (has its own CLAUDE.md)
game/             # Godot 4 project (Phase 1+, forked from base game)
orchestrator/     # Python/FastAPI DM orchestrator (Phase 2+)
forge_output/     # Claude-generated content (Phase 3+)
game_state/       # JSON game state files (Phase 2+)
```

## Commands

### Phase 1 (Current — Godot Game, No AI)
```bash
# Open in Godot editor (Windows)
godot --path game/

# Run the game
godot --path game/ --main-scene scenes/main.tscn

# Export for ARM64 Linux (Jetson) from Windows Godot editor
godot --path game/ --export-release "Linux/ARM64"
```

### Phase 2 (Local LLM Integration)
```bash
# On Jetson — Start Ollama
ollama serve

# Pull the model
ollama pull llama3.2:3b

# Start the orchestrator
cd orchestrator/
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000

# Run tests
pytest orchestrator/tests/
```

### Phase 3 (Forge Mode)
```bash
# On Jetson — Set API key
export ANTHROPIC_API_KEY="sk-ant-..."

# Start persistent Claude Code CLI session for Forge Mode
cd forge/
claude
# Claude reads forge/CLAUDE.md automatically
# Orchestrator communicates with this session during gameplay

# For development/testing: manual forge generation
cd forge/
claude -p "Generate a crypt-themed dungeon for a level 3 party" --output-format json
```

## Key Conventions

- **GDScript** — strictly typed, `class_name` declarations, gdtoolkit linting
- **Python** — type hints, async/await, FastAPI conventions
- **JSON** — all state files and communication
- **No game logic in client** — Godot renders JSON. Orchestrator + LLM decide everything.
- **Test integration points** — orchestrator API, LLM routing, forge pipeline, JSON schema validation
- **Data-driven content** — CSV/JSON for game data, .tres for Godot resources
- **Never copy venvs** between Windows and Jetson — always create fresh per platform
