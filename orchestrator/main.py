"""DM Orchestrator — The Welcome Wench Phase 2

Central backend service coordinating between Godot client, local LLM (Ollama),
and the deterministic D&D 5e rules engine. All game logic flows through here.

See specs/phase-1-core/dm-orchestrator.md for the full design spec.
"""

import logging
from contextlib import asynccontextmanager
from pathlib import Path
from typing import AsyncIterator

from fastapi import FastAPI

from orchestrator.routes.action import router as action_router
from orchestrator.routes.character import router as character_router
from orchestrator.routes.debug import router as debug_router
from orchestrator.routes.npc import router as npc_router
from orchestrator.routes.srd import router as srd_router
from orchestrator.routes.state import router as state_router

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    """Startup/shutdown lifecycle: load NPC profiles on boot."""
    from orchestrator.engine.npc_context import load_npc_profiles

    project_root = Path(__file__).resolve().parent.parent
    npc_path = project_root / "game" / "assets" / "data" / "npc_profiles.json"
    if npc_path.exists():
        load_npc_profiles(npc_path)
        logger.info("NPC profiles loaded from %s", npc_path)
    else:
        load_npc_profiles()
        logger.info("Using default NPC profiles (game data not found)")

    # Auto-select best LLM model and log GPU status
    from orchestrator.engine.ollama_client import OllamaClient

    client = OllamaClient()
    try:
        selected = await client.select_best_model()
        logger.info("LLM model selected: %s", selected)
        status = await client.check_gpu_status()
        logger.info("Ollama GPU status: %s", status)
    except Exception:
        logger.warning("Could not check Ollama GPU status")
    yield


app = FastAPI(
    title="TWW DM Orchestrator",
    description="D&D 5e DM Orchestrator for The Welcome Wench",
    version="0.1.0",
    lifespan=lifespan,
)

app.include_router(action_router)
app.include_router(character_router)
app.include_router(debug_router)
app.include_router(npc_router)
app.include_router(srd_router)
app.include_router(state_router)


@app.get("/health")
async def health_check() -> dict:
    """Health check endpoint."""
    return {"status": "ok", "phase": 2}
