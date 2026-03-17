"""Context management: sliding window, token budget, history compression.

The local LLM (Llama 3.2 3B) has a 2048 token context window. This module
manages conversation history to fit within that budget while preserving
the most relevant context.

Token budget allocation:
- System prompt (archetype): ~300 tokens (fixed, never truncated)
- Current state summary: ~200 tokens
- Recent history: ~500-800 tokens (sliding window)
- Current action + dice results: ~200 tokens
- LLM response: ~500-800 tokens (reserved)
"""

from __future__ import annotations

# Token budget constants
CONTEXT_WINDOW = 2048
SYSTEM_BUDGET = 300
STATE_BUDGET = 200
ACTION_BUDGET = 200
RESPONSE_BUDGET = 600
MIN_RESPONSE_BUDGET = 400
HISTORY_BUDGET = CONTEXT_WINDOW - SYSTEM_BUDGET - STATE_BUDGET - ACTION_BUDGET - RESPONSE_BUDGET
# HISTORY_BUDGET ≈ 748

# Sliding window size
MAX_RECENT_EXCHANGES = 5
COMPRESS_AFTER = 3  # Exchanges older than this get compressed into summaries


def estimate_tokens(text: str) -> int:
    """Approximate token count (~4 chars per token for Llama)."""
    return max(1, len(text) // 4)


def add_exchange(history: list[dict], action: str, response: str) -> list[dict]:
    """Add a new exchange (player action + DM response) to history.

    Each exchange is a dict:
    {
        "turn": <int>,
        "action": "player action text",
        "response": "DM response text",
        "compressed": False
    }

    Returns the updated history list (same list, mutated).
    """
    turn = len(history) + 1
    history.append({
        "turn": turn,
        "action": action,
        "response": response,
        "compressed": False,
    })
    return history


def compress_exchange(exchange: dict) -> dict:
    """Compress a single exchange into a bullet-point summary.

    Takes a full exchange and produces a shortened version:
    - Extracts key action and outcome
    - Reduces to ~20-30% of original tokens

    Returns a new dict with compressed=True and summary text.
    """
    action = exchange.get("action", "")
    response = exchange.get("response", "")

    # Simple compression: take first sentence of response
    # (a better version could use the LLM for summarization)
    first_sentence = response.split(".")[0].strip() + "." if response else ""

    # Build compressed summary
    action_brief = action[:80].strip()
    if len(action) > 80:
        action_brief += "..."
    response_brief = first_sentence[:120].strip()
    if len(first_sentence) > 120:
        response_brief += "..."

    return {
        "turn": exchange.get("turn", 0),
        "action": action_brief,
        "response": response_brief,
        "compressed": True,
    }


def trim_history(history: list[dict], max_tokens: int) -> list[dict]:
    """Trim history to fit within max_tokens budget.

    Strategy:
    1. Keep the most recent COMPRESS_AFTER exchanges uncompressed
    2. Compress older exchanges into summaries
    3. If still over budget, drop the oldest compressed exchanges

    Returns a new list (does not mutate the original).
    """
    if not history:
        return []

    result = list(history)  # shallow copy

    # Step 1: Compress old exchanges (keep recent ones full)
    if len(result) > COMPRESS_AFTER:
        compressed_part = []
        for exchange in result[:-COMPRESS_AFTER]:
            if not exchange.get("compressed", False):
                compressed_part.append(compress_exchange(exchange))
            else:
                compressed_part.append(exchange)
        result = compressed_part + result[-COMPRESS_AFTER:]

    # Step 2: Check if we're within budget
    total = sum(estimate_tokens(format_exchange(e)) for e in result)

    # Step 3: Drop oldest exchanges if still over budget
    while result and total > max_tokens:
        dropped = result.pop(0)
        total -= estimate_tokens(format_exchange(dropped))

    return result


def format_exchange(exchange: dict) -> str:
    """Format a single exchange for inclusion in the prompt."""
    if exchange.get("compressed"):
        return f"[Turn {exchange['turn']}] {exchange['action']} → {exchange['response']}"
    else:
        return f"Turn {exchange['turn']}:\nAction: {exchange['action']}\nResult: {exchange['response']}"


def format_history(history: list[dict]) -> str:
    """Format the full history list into a prompt-ready string.

    Returns empty string if history is empty.
    """
    if not history:
        return ""

    parts = ["RECENT HISTORY:"]
    for exchange in history:
        parts.append(format_exchange(exchange))
    return "\n".join(parts)


def compress_history(history: list[dict], max_tokens: int) -> str:
    """One-shot function: trim history and format it for the prompt.

    This is the main entry point used by prompt_builder.py.

    Args:
        history: List of exchange dicts from NarrativeState.history
        max_tokens: Maximum token budget for the history section

    Returns:
        Formatted history string, or empty string if no history.
    """
    if not history or max_tokens <= 0:
        return ""

    trimmed = trim_history(history, max_tokens)
    return format_history(trimmed)


def calculate_response_budget(
    system_tokens: int,
    state_tokens: int,
    action_tokens: int,
    history_tokens: int,
    npc_tokens: int = 0,
) -> int:
    """Calculate how many tokens are left for the LLM response.

    Returns at least MIN_RESPONSE_BUDGET.
    """
    used = system_tokens + state_tokens + action_tokens + history_tokens + npc_tokens
    available = CONTEXT_WINDOW - used
    return max(MIN_RESPONSE_BUDGET, available)
