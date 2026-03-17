"""DM Orchestrator — The Welcome Wench Phase 2

Central backend service coordinating between Godot client, local LLM (Ollama),
and the deterministic D&D 5e rules engine. All game logic flows through here.

See specs/phase-1-core/dm-orchestrator.md for the full design spec.
"""

from fastapi import FastAPI

from orchestrator.routes.action import router as action_router
from orchestrator.routes.character import router as character_router
from orchestrator.routes.debug import router as debug_router
from orchestrator.routes.srd import router as srd_router
from orchestrator.routes.state import router as state_router

app = FastAPI(
    title="TWW DM Orchestrator",
    description="D&D 5e DM Orchestrator for The Welcome Wench",
    version="0.1.0",
)

app.include_router(action_router)
app.include_router(character_router)
app.include_router(debug_router)
app.include_router(srd_router)
app.include_router(state_router)


@app.get("/health")
async def health_check() -> dict:
    """Health check endpoint."""
    return {"status": "ok", "phase": 2}
