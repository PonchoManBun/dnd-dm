"""Debug dashboard endpoints for the DM orchestrator.

GET /debug/history — recent request/response log
GET /debug/stats   — aggregate statistics
"""

from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Query

from orchestrator.engine.debug_logger import get_debug_logger

router = APIRouter(prefix="/debug", tags=["debug"])


@router.get("/history")
async def debug_history(
    limit: int = Query(default=50, ge=1, le=100, description="Max entries to return"),
) -> dict[str, Any]:
    """Return the most recent request/response log entries (newest first)."""
    logger = get_debug_logger()
    entries = logger.get_history(limit=limit)
    return {"entries": entries, "count": len(entries)}


@router.get("/stats")
async def debug_stats() -> dict[str, Any]:
    """Return aggregate statistics across all logged requests."""
    logger = get_debug_logger()
    return logger.get_stats()
