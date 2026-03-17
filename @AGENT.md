# Build / Run / Test Instructions

## Prerequisites

- Godot 4.6.1 — installed at `/usr/local/bin/godot`
- Python 3.10+ (system: 3.10.12)
- Ollama 0.18.0 (installed, running, Llama 3.2 3B on GPU)
- Anthropic API Key (for Phase 3+ Forge Mode)

## Development Platform

Development and play happen directly on the **Jetson Orin Nano**. No separate build machine.

```bash
# Pull latest from GitHub
git pull origin master

# Run the game
godot --path game/
```

See `specs/research/dev-workflow.md` for full Git workflow, orchestrator setup, and Forge details.

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
# Open in Godot editor
godot --path game/ -e

# Run the game
godot --path game/

# Run headless (validation)
godot --path game/ --headless --quit
```

### Phase 2 (Local LLM Integration)
```bash
# Start Ollama (if not already running)
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
# Set API key
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
