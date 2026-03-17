"""Comprehensive tests for the context management module.

Tests cover token estimation, exchange management, history compression,
formatting, and response budget calculation.
"""

from __future__ import annotations

import pytest

from orchestrator.engine.context_manager import (
    COMPRESS_AFTER,
    CONTEXT_WINDOW,
    MIN_RESPONSE_BUDGET,
    add_exchange,
    calculate_response_budget,
    compress_exchange,
    compress_history,
    estimate_tokens,
    format_exchange,
    format_history,
    trim_history,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _make_exchange(
    turn: int = 1,
    action: str = "I attack the goblin",
    response: str = "You swing your sword and hit the goblin for 8 damage.",
    compressed: bool = False,
) -> dict:
    """Create a test exchange dict."""
    return {
        "turn": turn,
        "action": action,
        "response": response,
        "compressed": compressed,
    }


def _make_history(count: int) -> list[dict]:
    """Create a history list with `count` exchanges."""
    history: list[dict] = []
    for i in range(count):
        add_exchange(
            history,
            action=f"Action {i + 1}: I do something interesting",
            response=f"Response {i + 1}: The DM describes what happens next in the story.",
        )
    return history


# ===================================================================
# estimate_tokens
# ===================================================================


class TestEstimateTokens:
    def test_empty_string(self):
        """Empty string returns 1 (minimum)."""
        assert estimate_tokens("") == 1

    def test_short_string(self):
        """'hello' is 5 chars → 5 // 4 = 1."""
        assert estimate_tokens("hello") == 1

    def test_longer_string(self):
        """'hello world test' is 16 chars → 16 // 4 = 4."""
        assert estimate_tokens("hello world test") == 4

    def test_very_long_string(self):
        """400 chars → 100 tokens."""
        text = "a" * 400
        assert estimate_tokens(text) == 100

    def test_single_char(self):
        """Single char → 1 (minimum)."""
        assert estimate_tokens("x") == 1

    def test_exactly_four_chars(self):
        """4 chars → 1 token."""
        assert estimate_tokens("test") == 1

    def test_five_chars(self):
        """5 chars → 1 token (5 // 4 = 1)."""
        assert estimate_tokens("tests") == 1

    def test_eight_chars(self):
        """8 chars → 2 tokens."""
        assert estimate_tokens("12345678") == 2


# ===================================================================
# add_exchange
# ===================================================================


class TestAddExchange:
    def test_first_exchange(self):
        """First exchange gets turn=1."""
        history: list[dict] = []
        result = add_exchange(history, "I open the door", "The door creaks open.")
        assert len(result) == 1
        assert result[0]["turn"] == 1

    def test_increments_turn(self):
        """Second exchange gets turn=2."""
        history: list[dict] = []
        add_exchange(history, "action 1", "response 1")
        add_exchange(history, "action 2", "response 2")
        assert history[1]["turn"] == 2

    def test_structure(self):
        """Exchange has all required keys."""
        history: list[dict] = []
        add_exchange(history, "I cast fireball", "Flames erupt!")
        exchange = history[0]
        assert "turn" in exchange
        assert "action" in exchange
        assert "response" in exchange
        assert "compressed" in exchange
        assert exchange["compressed"] is False

    def test_returns_same_list(self):
        """Returns the same list object (mutated in place)."""
        history: list[dict] = []
        result = add_exchange(history, "action", "response")
        assert result is history

    def test_preserves_existing_entries(self):
        """Adding an exchange does not alter existing entries."""
        history: list[dict] = []
        add_exchange(history, "action 1", "response 1")
        first_copy = dict(history[0])
        add_exchange(history, "action 2", "response 2")
        assert history[0] == first_copy

    def test_action_and_response_stored(self):
        """Action and response text are stored verbatim."""
        history: list[dict] = []
        add_exchange(history, "I search the room", "You find a hidden compartment.")
        assert history[0]["action"] == "I search the room"
        assert history[0]["response"] == "You find a hidden compartment."


# ===================================================================
# compress_exchange
# ===================================================================


class TestCompressExchange:
    def test_sets_compressed_flag(self):
        """Compressed exchange has compressed=True."""
        exchange = _make_exchange()
        compressed = compress_exchange(exchange)
        assert compressed["compressed"] is True

    def test_preserves_turn(self):
        """Turn number is preserved after compression."""
        exchange = _make_exchange(turn=7)
        compressed = compress_exchange(exchange)
        assert compressed["turn"] == 7

    def test_shortens_long_action(self):
        """Actions longer than 80 chars get truncated with ellipsis."""
        long_action = "I carefully search every corner of the room, " \
                      "looking under the furniture and behind the tapestries for traps"
        exchange = _make_exchange(action=long_action)
        compressed = compress_exchange(exchange)
        assert len(compressed["action"]) <= 83  # 80 chars + "..."
        assert compressed["action"].endswith("...")

    def test_keeps_short_action(self):
        """Short actions are kept intact."""
        exchange = _make_exchange(action="I attack")
        compressed = compress_exchange(exchange)
        assert compressed["action"] == "I attack"

    def test_response_takes_first_sentence(self):
        """Response is compressed to first sentence."""
        exchange = _make_exchange(
            response="You hit the goblin. It staggers backward. Blood drips from its wound.",
        )
        compressed = compress_exchange(exchange)
        assert "You hit the goblin." in compressed["response"]
        # Subsequent sentences should not appear
        assert "It staggers" not in compressed["response"]

    def test_empty_response(self):
        """Empty response produces empty string."""
        exchange = _make_exchange(response="")
        compressed = compress_exchange(exchange)
        assert compressed["response"] == ""

    def test_returns_new_dict(self):
        """Compression returns a new dict, does not mutate original."""
        exchange = _make_exchange()
        compressed = compress_exchange(exchange)
        assert compressed is not exchange
        assert exchange["compressed"] is False


# ===================================================================
# trim_history
# ===================================================================


class TestTrimHistory:
    def test_empty_history(self):
        """Empty history returns empty list."""
        assert trim_history([], 1000) == []

    def test_within_budget(self):
        """History that fits within budget is returned as-is (but new list)."""
        history = [_make_exchange(turn=1)]
        result = trim_history(history, 10000)
        assert len(result) == 1
        assert result[0]["turn"] == 1

    def test_compresses_old_exchanges(self):
        """Exchanges older than COMPRESS_AFTER get compressed."""
        history = _make_history(COMPRESS_AFTER + 2)
        result = trim_history(history, 10000)
        # First 2 exchanges should be compressed
        assert result[0]["compressed"] is True
        assert result[1]["compressed"] is True
        # Last COMPRESS_AFTER should remain uncompressed
        for e in result[-COMPRESS_AFTER:]:
            assert e["compressed"] is False

    def test_drops_oldest_when_over_budget(self):
        """When over budget, oldest exchanges are dropped first."""
        history = _make_history(10)
        # Use a very small budget to force dropping
        result = trim_history(history, 10)
        assert len(result) < 10
        # The remaining entries should be from the most recent turns
        if result:
            assert result[-1]["turn"] == 10

    def test_does_not_mutate_original(self):
        """Original history list is not modified."""
        history = _make_history(6)
        original_len = len(history)
        original_first = dict(history[0])
        trim_history(history, 50)
        assert len(history) == original_len
        assert history[0] == original_first

    def test_single_exchange_within_budget(self):
        """Single exchange that fits in budget."""
        history = [_make_exchange(turn=1)]
        result = trim_history(history, 10000)
        assert len(result) == 1
        assert result[0]["compressed"] is False

    def test_already_compressed_not_recompressed(self):
        """Exchanges already marked compressed are not compressed again."""
        exchange = _make_exchange(turn=1, compressed=True, action="short", response="ok.")
        history = [exchange] + _make_history(COMPRESS_AFTER + 1)
        result = trim_history(history, 10000)
        # First exchange was already compressed; should stay the same
        assert result[0]["compressed"] is True
        assert result[0]["action"] == "short"


# ===================================================================
# format_exchange
# ===================================================================


class TestFormatExchange:
    def test_full_exchange_format(self):
        """Uncompressed exchange includes 'Turn X:', 'Action:', 'Result:'."""
        exchange = _make_exchange(turn=3, compressed=False)
        formatted = format_exchange(exchange)
        assert "Turn 3:" in formatted
        assert "Action:" in formatted
        assert "Result:" in formatted

    def test_compressed_exchange_format(self):
        """Compressed exchange uses '[Turn X]' and arrow."""
        exchange = _make_exchange(turn=5, compressed=True)
        formatted = format_exchange(exchange)
        assert "[Turn 5]" in formatted
        assert "\u2192" in formatted  # → character

    def test_full_exchange_contains_action_text(self):
        """Full exchange includes the action text."""
        exchange = _make_exchange(action="I cast magic missile")
        formatted = format_exchange(exchange)
        assert "I cast magic missile" in formatted

    def test_full_exchange_contains_response_text(self):
        """Full exchange includes the response text."""
        exchange = _make_exchange(response="Three darts of light strike the enemy.")
        formatted = format_exchange(exchange)
        assert "Three darts of light strike the enemy." in formatted


# ===================================================================
# format_history
# ===================================================================


class TestFormatHistory:
    def test_empty_history(self):
        """Empty history returns empty string."""
        assert format_history([]) == ""

    def test_with_entries(self):
        """Non-empty history starts with 'RECENT HISTORY:'."""
        history = [_make_exchange(turn=1)]
        formatted = format_history(history)
        assert formatted.startswith("RECENT HISTORY:")

    def test_multiple_entries(self):
        """Multiple entries are all included."""
        history = [
            _make_exchange(turn=1, action="action 1"),
            _make_exchange(turn=2, action="action 2"),
        ]
        formatted = format_history(history)
        assert "action 1" in formatted
        assert "action 2" in formatted

    def test_mixed_compressed_and_full(self):
        """Both compressed and full exchanges are formatted."""
        history = [
            _make_exchange(turn=1, compressed=True),
            _make_exchange(turn=2, compressed=False),
        ]
        formatted = format_history(history)
        assert "[Turn 1]" in formatted
        assert "Turn 2:" in formatted


# ===================================================================
# compress_history (main entry point)
# ===================================================================


class TestCompressHistory:
    def test_empty_history(self):
        """Empty history returns empty string."""
        assert compress_history([], 1000) == ""

    def test_zero_budget(self):
        """Zero budget returns empty string."""
        history = _make_history(3)
        assert compress_history(history, 0) == ""

    def test_negative_budget(self):
        """Negative budget returns empty string."""
        history = _make_history(3)
        assert compress_history(history, -100) == ""

    def test_with_entries(self):
        """Returns formatted string with 'RECENT HISTORY:' header."""
        history = _make_history(2)
        result = compress_history(history, 10000)
        assert "RECENT HISTORY:" in result
        assert "Action 1" in result
        assert "Action 2" in result

    def test_respects_token_budget(self):
        """Result fits within the specified token budget."""
        history = _make_history(10)
        budget = 50
        result = compress_history(history, budget)
        tokens = estimate_tokens(result) if result else 0
        # The formatted result should be within a reasonable range of the budget.
        # trim_history drops entries to get under budget; format_history adds
        # the header, so it may be slightly over the raw sum, but should be close.
        assert tokens <= budget + 20  # small margin for header text

    def test_preserves_recent_exchanges(self):
        """Most recent exchanges are preserved in the output."""
        history = _make_history(8)
        result = compress_history(history, 10000)
        # The most recent exchange (turn 8) should be present
        assert "Action 8" in result


# ===================================================================
# calculate_response_budget
# ===================================================================


class TestCalculateResponseBudget:
    def test_normal_usage(self):
        """With moderate usage, returns positive budget."""
        budget = calculate_response_budget(
            system_tokens=300,
            state_tokens=200,
            action_tokens=100,
            history_tokens=400,
        )
        # 2048 - 300 - 200 - 100 - 400 = 1048
        assert budget == 1048

    def test_minimum_floor(self):
        """Never returns below MIN_RESPONSE_BUDGET."""
        budget = calculate_response_budget(
            system_tokens=800,
            state_tokens=500,
            action_tokens=400,
            history_tokens=500,
        )
        # 2048 - 800 - 500 - 400 - 500 = -152, but min is 400
        assert budget == MIN_RESPONSE_BUDGET

    def test_plenty_of_space(self):
        """When context is sparse, returns large budget."""
        budget = calculate_response_budget(
            system_tokens=100,
            state_tokens=50,
            action_tokens=50,
            history_tokens=0,
        )
        # 2048 - 100 - 50 - 50 - 0 = 1848
        assert budget == 1848

    def test_with_npc_tokens(self):
        """NPC tokens are subtracted from the budget."""
        budget = calculate_response_budget(
            system_tokens=300,
            state_tokens=200,
            action_tokens=100,
            history_tokens=400,
            npc_tokens=200,
        )
        # 2048 - 300 - 200 - 100 - 400 - 200 = 848
        assert budget == 848

    def test_all_zeros(self):
        """With no usage, returns full context window."""
        budget = calculate_response_budget(
            system_tokens=0,
            state_tokens=0,
            action_tokens=0,
            history_tokens=0,
        )
        assert budget == CONTEXT_WINDOW

    def test_exact_threshold(self):
        """When used tokens leave exactly MIN_RESPONSE_BUDGET, returns that."""
        # Need: CONTEXT_WINDOW - used = MIN_RESPONSE_BUDGET
        # used = CONTEXT_WINDOW - MIN_RESPONSE_BUDGET = 2048 - 400 = 1648
        budget = calculate_response_budget(
            system_tokens=1000,
            state_tokens=400,
            action_tokens=148,
            history_tokens=100,
        )
        # 2048 - 1000 - 400 - 148 - 100 = 400
        assert budget == MIN_RESPONSE_BUDGET

    def test_just_below_threshold(self):
        """When used tokens leave less than MIN_RESPONSE_BUDGET, returns min."""
        budget = calculate_response_budget(
            system_tokens=1000,
            state_tokens=400,
            action_tokens=149,
            history_tokens=100,
        )
        # 2048 - 1000 - 400 - 149 - 100 = 399 → clamped to 400
        assert budget == MIN_RESPONSE_BUDGET
