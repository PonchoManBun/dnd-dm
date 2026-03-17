"""In-memory debug logger for the DM orchestrator.

Stores recent request/response entries in a fixed-size ring buffer (last 100)
and provides aggregate statistics. No persistence — data lives only as long
as the process.
"""

from __future__ import annotations

import time
from collections import deque
from dataclasses import dataclass, field, asdict
from datetime import datetime, timezone
from typing import Any


# ---------------------------------------------------------------------------
# Data model
# ---------------------------------------------------------------------------

@dataclass
class DebugEntry:
    """A single logged request/response cycle."""

    timestamp: str
    action_type: str
    target: str | None = None
    prompt_tokens_est: int = 0
    response_tokens_est: int = 0
    latency_ms: float = 0.0
    narration_snippet: str = ""
    error: str | None = None

    def to_dict(self) -> dict[str, Any]:
        """Serialise to a plain dict for JSON responses."""
        return asdict(self)


# ---------------------------------------------------------------------------
# Ring-buffer logger (singleton)
# ---------------------------------------------------------------------------

_MAX_ENTRIES = 100


class DebugLogger:
    """Fixed-size in-memory log of orchestrator request/response cycles.

    Thread-safe enough for the single-worker uvicorn setup used in Phase 2.
    """

    def __init__(self, max_entries: int = _MAX_ENTRIES) -> None:
        self._entries: deque[DebugEntry] = deque(maxlen=max_entries)
        self._total_requests: int = 0
        self._total_prompt_tokens: int = 0
        self._total_response_tokens: int = 0
        self._total_latency_ms: float = 0.0
        self._total_errors: int = 0

    # -- recording ----------------------------------------------------------

    def log(
        self,
        action_type: str,
        target: str | None = None,
        prompt_tokens_est: int = 0,
        response_tokens_est: int = 0,
        latency_ms: float = 0.0,
        narration_snippet: str = "",
        error: str | None = None,
    ) -> DebugEntry:
        """Record a completed request/response cycle."""
        entry = DebugEntry(
            timestamp=datetime.now(timezone.utc).isoformat(),
            action_type=action_type,
            target=target,
            prompt_tokens_est=prompt_tokens_est,
            response_tokens_est=response_tokens_est,
            latency_ms=round(latency_ms, 2),
            narration_snippet=narration_snippet[:120],
            error=error,
        )
        self._entries.append(entry)
        self._total_requests += 1
        self._total_prompt_tokens += prompt_tokens_est
        self._total_response_tokens += response_tokens_est
        self._total_latency_ms += latency_ms
        if error:
            self._total_errors += 1
        return entry

    # -- querying -----------------------------------------------------------

    def get_history(self, limit: int = 50) -> list[dict[str, Any]]:
        """Return the most recent *limit* entries, newest first."""
        entries = list(self._entries)
        entries.reverse()
        return [e.to_dict() for e in entries[:limit]]

    def get_stats(self) -> dict[str, Any]:
        """Return aggregate statistics across all logged requests."""
        avg_latency = (
            round(self._total_latency_ms / self._total_requests, 2)
            if self._total_requests > 0
            else 0.0
        )
        return {
            "total_requests": self._total_requests,
            "total_errors": self._total_errors,
            "total_prompt_tokens_est": self._total_prompt_tokens,
            "total_response_tokens_est": self._total_response_tokens,
            "total_tokens_est": self._total_prompt_tokens + self._total_response_tokens,
            "avg_latency_ms": avg_latency,
            "buffer_size": len(self._entries),
            "buffer_capacity": self._entries.maxlen,
        }

    def clear(self) -> None:
        """Reset all stored data (useful for testing)."""
        self._entries.clear()
        self._total_requests = 0
        self._total_prompt_tokens = 0
        self._total_response_tokens = 0
        self._total_latency_ms = 0.0
        self._total_errors = 0


# ---------------------------------------------------------------------------
# Module-level singleton
# ---------------------------------------------------------------------------

_logger_instance: DebugLogger | None = None


def get_debug_logger() -> DebugLogger:
    """Return the global DebugLogger singleton, creating it on first call."""
    global _logger_instance
    if _logger_instance is None:
        _logger_instance = DebugLogger()
    return _logger_instance


def set_debug_logger(logger: DebugLogger | None) -> None:
    """Replace the global DebugLogger (used for testing)."""
    global _logger_instance
    _logger_instance = logger


def estimate_tokens(text: str) -> int:
    """Approximate token count (~4 chars per token for Llama-family models)."""
    return max(1, len(text) // 4)
