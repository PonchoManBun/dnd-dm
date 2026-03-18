"""Async wrapper for Ollama REST API.

Connects to a local Ollama instance for LLM inference using raw HTTP
via httpx. No dependency on the ollama Python package.
"""

from __future__ import annotations

import logging

import httpx

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Custom exceptions
# ---------------------------------------------------------------------------

class OllamaConnectionError(Exception):
    """Raised when the Ollama server is unreachable."""


class OllamaTimeoutError(Exception):
    """Raised when a request to Ollama times out."""


class OllamaModelNotFoundError(Exception):
    """Raised when the requested model is not available on the Ollama server."""


# ---------------------------------------------------------------------------
# Client
# ---------------------------------------------------------------------------

PREFERRED_MODEL = "llama3.2:3b"
FALLBACK_MODEL = "gemma3:1b"


class OllamaClient:
    """Async wrapper for Ollama API.

    Connects to a local Ollama instance (default ``http://localhost:11434``)
    for LLM inference.  Uses ``httpx.AsyncClient`` under the hood and talks
    directly to the Ollama REST API — no third-party ``ollama`` package needed.
    """

    def __init__(
        self,
        base_url: str = "http://localhost:11434",
        model: str = "gemma3:1b",
        timeout: float = 30.0,
        num_gpu: int = 999,
        num_ctx: int = 2048,
    ) -> None:
        self.base_url: str = base_url.rstrip("/")
        self.model: str = model
        self.timeout: float = timeout
        self.num_gpu: int = num_gpu
        self.num_ctx: int = num_ctx

    # -- helpers ------------------------------------------------------------

    def _make_client(self) -> httpx.AsyncClient:
        """Create a fresh ``httpx.AsyncClient`` configured with our timeout."""
        return httpx.AsyncClient(
            base_url=self.base_url,
            timeout=httpx.Timeout(self.timeout),
        )

    # -- public API ---------------------------------------------------------

    async def health_check(self) -> bool:
        """Check if Ollama is running **and** the configured model is loaded.

        Calls ``GET /api/tags`` and checks whether ``self.model`` appears in
        the list of available models.

        Returns:
            ``True`` when the server is reachable and the model is available.

        Raises:
            OllamaConnectionError: Server is unreachable.
        """
        try:
            async with self._make_client() as client:
                response = await client.get("/api/tags")
                response.raise_for_status()
                data = response.json()
        except httpx.ConnectError as exc:
            raise OllamaConnectionError(
                f"Cannot connect to Ollama at {self.base_url}"
            ) from exc
        except httpx.TimeoutException as exc:
            raise OllamaConnectionError(
                f"Timeout connecting to Ollama at {self.base_url}"
            ) from exc

        models: list[dict] = data.get("models", [])
        available_names: list[str] = [m.get("name", "") for m in models]

        if self.model in available_names:
            return True

        # Also match without the tag suffix (e.g. "llama3.2:3b" matches
        # "llama3.2:3b" but the server might report "llama3.2:3b" as-is).
        # Tolerate the server returning with or without a `:latest` suffix.
        for name in available_names:
            if name.split(":")[0] == self.model.split(":")[0]:
                # Close enough — same base model family.  Still, be strict
                # and only return True on an exact match so callers can
                # distinguish between e.g. 3B and 1B.
                pass

        logger.warning(
            "Model '%s' not found. Available: %s", self.model, available_names
        )
        return False

    async def generate_response(
        self,
        prompt: str,
        system_prompt: str = "",
        max_tokens: int = 800,
        temperature: float = 0.7,
    ) -> str:
        """Generate a completion using ``POST /api/generate``.

        Args:
            prompt: The user prompt / instruction.
            system_prompt: Optional system-level instructions.
            max_tokens: Maximum number of tokens to generate.
            temperature: Sampling temperature.

        Returns:
            The generated text.

        Raises:
            OllamaConnectionError: Server unreachable.
            OllamaTimeoutError: Request timed out.
            OllamaModelNotFoundError: Model not available.
        """
        payload: dict = {
            "model": self.model,
            "prompt": prompt,
            "stream": False,
            "options": {
                "num_predict": max_tokens,
                "temperature": temperature,
                "num_gpu": self.num_gpu,
                "num_ctx": self.num_ctx,
            },
        }
        if system_prompt:
            payload["system"] = system_prompt

        data = await self._post("/api/generate", payload)
        return data.get("response", "")

    async def generate_chat(
        self,
        messages: list[dict],
        max_tokens: int = 800,
        temperature: float = 0.7,
    ) -> str:
        """Generate a chat response using ``POST /api/chat``.

        Args:
            messages: A list of message dicts, each with ``role`` and
                ``content`` keys.  Example::

                    [
                        {"role": "system", "content": "You are a DM."},
                        {"role": "user",   "content": "I search the room."},
                    ]
            max_tokens: Maximum number of tokens to generate.
            temperature: Sampling temperature.

        Returns:
            The assistant's reply text.

        Raises:
            OllamaConnectionError: Server unreachable.
            OllamaTimeoutError: Request timed out.
            OllamaModelNotFoundError: Model not available.
        """
        payload: dict = {
            "model": self.model,
            "messages": messages,
            "stream": False,
            "options": {
                "num_predict": max_tokens,
                "temperature": temperature,
                "num_gpu": self.num_gpu,
                "num_ctx": self.num_ctx,
            },
        }

        data = await self._post("/api/chat", payload)
        # The chat endpoint nests the reply inside a "message" object.
        message: dict = data.get("message", {})
        return message.get("content", "")

    # -- token helpers ------------------------------------------------------

    def estimate_tokens(self, text: str) -> int:
        """Approximate token count for *text*.

        Uses the rule-of-thumb that English text averages roughly 4 characters
        per token with Llama-family tokenisers.
        """
        return max(1, len(text) // 4)

    def is_within_budget(self, text: str, budget: int) -> bool:
        """Return ``True`` if *text* fits within *budget* tokens."""
        return self.estimate_tokens(text) <= budget

    # -- GPU diagnostics ----------------------------------------------------

    async def check_gpu_status(self) -> dict:
        """Check GPU offload status for the loaded model."""
        async with self._make_client() as client:
            resp = await client.get("/api/ps")
            resp.raise_for_status()
        for m in resp.json().get("models", []):
            if self.model in m.get("name", ""):
                vram = m.get("size_vram", 0)
                total = m.get("size", 1)
                return {
                    "model": m["name"],
                    "gpu_percent": round(vram / total * 100, 1),
                    "vram_mb": vram // (1024 * 1024),
                }
        return {"error": "not loaded"}

    async def select_best_model(self) -> str:
        """Try preferred model; if it fails, fall back to smaller model."""
        try:
            self.model = PREFERRED_MODEL
            await self.generate_chat(
                [{"role": "user", "content": "test"}], max_tokens=5
            )
            logger.info("Using preferred model: %s", self.model)
            return self.model
        except Exception:
            self.model = FALLBACK_MODEL
            logger.info("Fell back to model: %s", self.model)
            return self.model

    # -- internal -----------------------------------------------------------

    async def _post(self, endpoint: str, payload: dict) -> dict:
        """Send a POST request to Ollama and return the parsed JSON body.

        Centralises error handling for connection / timeout / model-not-found
        errors so callers don't have to repeat it.
        """
        try:
            async with self._make_client() as client:
                response = await client.post(endpoint, json=payload)
        except httpx.ConnectError as exc:
            raise OllamaConnectionError(
                f"Cannot connect to Ollama at {self.base_url}"
            ) from exc
        except httpx.TimeoutException as exc:
            raise OllamaTimeoutError(
                f"Request to Ollama timed out after {self.timeout}s"
            ) from exc

        if response.status_code == 404:
            raise OllamaModelNotFoundError(
                f"Model '{self.model}' not found on Ollama server"
            )

        response.raise_for_status()
        return response.json()
