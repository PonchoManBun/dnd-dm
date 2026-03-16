# MCP Forge Mode Design: Claude Content Generation System

## Architecture Overview

```
[Player Session]
       |
[Local LLM on Ollama] -- decides what content is needed
       |
[Python Orchestrator] -- intercepts tool_calls from Ollama
       |
       |--- (Phase 1: Direct) ---> [Claude Agent SDK] ---> Claude API
       |                                   |
       |                           writes .tscn/.tres/.gd/.json files
       |
       |--- (Phase 2: MCP) ------> [Forge MCP Server] ---> Claude Agent SDK
       |                                   |
       |                           writes .tscn/.tres/.gd/.json files
       |
[Generated Content on Disk]
       |
[Godot Client reads and renders]
```

**Phase 1:** Python orchestrator calls Claude Agent SDK directly. Simplest path.
**Phase 2:** Wrap the same logic in an MCP server for discoverability and reusability.

---

## 1. MCP Protocol Summary

MCP (Model Context Protocol) is a JSON-RPC 2.0 protocol for connecting AI applications to external systems.

### Three Primitives

| Primitive | Purpose | Control |
|-----------|---------|---------|
| **Tools** | Executable functions LLM can invoke | Model-controlled |
| **Resources** | Read-only data for context | Application-controlled |
| **Prompts** | Reusable interaction templates | User-controlled |

Forge Mode uses **tools** as the primary primitive.

### Transport Options

| Transport | Best For |
|-----------|----------|
| **stdio** | Local, single-client (server as subprocess) |
| **Streamable HTTP** | Persistent daemon, multiple clients |

For local Jetson deployment: stdio is simplest. HTTP is better if forge server runs as a daemon.

---

## 2. Forge Tool Schemas

### `forge_dungeon` -- Generate a dungeon tilemap

```json
{
  "name": "forge_dungeon",
  "description": "Generate a dungeon level with rooms, corridors, encounters, and loot",
  "inputSchema": {
    "type": "object",
    "properties": {
      "theme": { "type": "string", "description": "e.g., 'crypt', 'sewer', 'cave', 'temple'" },
      "difficulty": { "type": "integer", "minimum": 1, "maximum": 20 },
      "width": { "type": "integer", "default": 32 },
      "height": { "type": "integer", "default": 32 },
      "num_rooms": { "type": "integer", "default": 5 },
      "boss_room": { "type": "boolean", "default": true },
      "context": { "type": "string", "description": "Narrative context" }
    },
    "required": ["theme", "difficulty"]
  }
}
```

**Returns:** JSON grid layout + room metadata + encounter placements.

### `forge_monster` -- Generate a monster with D&D 5e stats

```json
{
  "name": "forge_monster",
  "inputSchema": {
    "type": "object",
    "properties": {
      "name": { "type": "string" },
      "cr": { "type": "number", "description": "Challenge rating" },
      "type": { "type": "string", "enum": ["aberration","beast","celestial","construct","dragon","elemental","fey","fiend","giant","humanoid","monstrosity","ooze","plant","undead"] },
      "environment": { "type": "string" },
      "role": { "type": "string", "enum": ["brute","skirmisher","controller","artillery","lurker","leader"] },
      "context": { "type": "string" }
    },
    "required": ["cr", "type"]
  }
}
```

**Returns:** `.tres` resource content + JSON stat block.

### `forge_item` -- Generate an item card

```json
{
  "name": "forge_item",
  "inputSchema": {
    "type": "object",
    "properties": {
      "rarity": { "type": "string", "enum": ["common","uncommon","rare","very_rare","legendary","artifact"] },
      "type": { "type": "string", "enum": ["weapon","armor","potion","scroll","wondrous","ring","wand","staff"] },
      "theme": { "type": "string" },
      "level_range": { "type": "string", "description": "e.g., '5-10'" },
      "context": { "type": "string" }
    },
    "required": ["rarity", "type"]
  }
}
```

### `forge_npc` -- Generate an NPC with dialogue and behavior

```json
{
  "name": "forge_npc",
  "inputSchema": {
    "type": "object",
    "properties": {
      "role": { "type": "string", "description": "e.g., 'merchant', 'questgiver', 'villain'" },
      "race": { "type": "string" },
      "class": { "type": "string" },
      "personality_traits": { "type": "array", "items": { "type": "string" } },
      "location": { "type": "string" },
      "context": { "type": "string" }
    },
    "required": ["role"]
  }
}
```

### `forge_narrative` -- Generate story/quest content

```json
{
  "name": "forge_narrative",
  "inputSchema": {
    "type": "object",
    "properties": {
      "type": { "type": "string", "enum": ["main_quest","side_quest","encounter","lore","dialogue","room_description"] },
      "tone": { "type": "string" },
      "characters": { "type": "array", "items": { "type": "string" } },
      "location": { "type": "string" },
      "player_level": { "type": "integer" },
      "context": { "type": "string" }
    },
    "required": ["type"]
  }
}
```

### Design Pattern

Every tool includes an optional `context` string -- the local LLM passes its understanding of the current game state, player history, and narrative arc. This is what makes generated content coherent with the session.

---

## 3. Claude Invocation Options

### Option A: Claude Code CLI Subprocess

```python
import subprocess, json

result = subprocess.run(
    ["claude", "-p", prompt, "--output-format", "json", "--json-schema", schema],
    capture_output=True, text=True, timeout=120, cwd=project_dir
)
output = json.loads(result.stdout)
```

**Key flags:** `--print`, `--output-format json`, `--json-schema`, `--max-turns`, `--max-budget-usd`, `--system-prompt`, `--allowedTools`, `--dangerously-skip-permissions`

**Pros:** Full Claude Code agent (file read/write/edit, bash). Good for writing files to disk.
**Cons:** Process spawn overhead. 10-60 sec latency.

### Option B: Claude Agent SDK (Recommended)

```python
from claude_agent_sdk import query, ClaudeAgentOptions

async for message in query(
    prompt="Generate a crypt-themed dungeon...",
    options=ClaudeAgentOptions(
        allowed_tools=["Read", "Write", "Edit", "Bash"],
        system_prompt="You are a game content generator..."
    ),
):
    if hasattr(message, "result"):
        return message.result
```

**Pros:** Library, not subprocess. Streaming. Session management. Same capabilities as CLI.
**Cons:** Requires `ANTHROPIC_API_KEY`. Same API latency.

### Option C: Anthropic API Directly

Direct API calls with custom tool definitions. Most control, but loses built-in tools.

### Recommendation

**Use a persistent Claude Code CLI session.** The CLI runs in the `forge/` subdirectory with its own CLAUDE.md. The orchestrator does `/clear` before each request, ensuring a clean context. This provides all Claude Code tools (file read/write/edit, bash) with the simplicity of an interactive session rather than subprocess management or SDK integration.

The Agent SDK and direct API remain viable alternatives if the persistent session model proves impractical, but the CLI approach is the Phase 1 design. See `specs/phase-1-core/forge-mode.md` for full details.

---

## 4. MCP Server vs Direct Invocation

| Factor | Direct (Agent SDK) | MCP Server |
|--------|-------------------|------------|
| Complexity | Lower | Higher |
| Setup | Zero extra infrastructure | Build + deploy server |
| Discoverability | Hardcoded in orchestrator | Standardized protocol |
| Multi-client | Single orchestrator only | Any MCP client can connect |
| Future-proof | Tightly coupled | Ready for Ollama native MCP |
| Debugging | Simpler (one layer) | Extra hop to trace |

**Verdict:** Start with direct invocation. Build MCP server later when you need multi-client access or Ollama ships native MCP support.

---

## 5. Local LLM to Forge Bridge

### Ollama Tool Calling (Available Now)

```python
import ollama

response = ollama.chat(
    model='llama3.2:3b',
    messages=[{"role": "user", "content": "The player found a locked door..."}],
    tools=[{
        "type": "function",
        "function": {
            "name": "forge_dungeon",
            "description": "Generate a dungeon tilemap",
            "parameters": { ... }
        }
    }]
)
# response.message.tool_calls contains the function call
```

Models with tool support: Llama 3.1+, Llama 3.2+, Mistral Nemo, Command-R+.

### Orchestrator Bridge Pattern

```python
# Pseudocode
response = ollama.chat(model='llama3.2:3b', messages=messages, tools=forge_tools)

if response.message.tool_calls:
    for tool_call in response.message.tool_calls:
        # Invoke Claude Agent SDK
        result = await invoke_forge(tool_call.function.name, tool_call.function.arguments)
        # Feed result back to Ollama
        messages.append({"role": "tool", "content": result})
        response = ollama.chat(model='llama3.2:3b', messages=messages, tools=forge_tools)
```

### Ollama Native MCP Status

As of March 2026:
- **PR #13700:** MCP protocol support -- Open (Jan 2026)
- **PR #13628:** Experimental agent loop -- **Merged** (Jan 2026)
- Not yet in stable release. When it lands, Ollama models can call MCP tools directly.

---

## 6. Error Handling & Cost Control

- `--max-turns` prevents runaway agent loops
- `--max-budget-usd` caps spend per invocation
- 120s timeout is reasonable for content generation
- Return `isError: true` in MCP tool results on failure
- Retry with exponential backoff on 429/500 errors
- Log all forge invocations for cost tracking

---

## Key References

- MCP Specification: https://modelcontextprotocol.io/specification/latest
- MCP Python SDK: `pip install "mcp[cli]"` (v1.26.0)
- Claude Agent SDK: https://platform.claude.com/docs/en/agent-sdk/overview
- Claude Code CLI: https://code.claude.com/docs/en/cli-usage
- Ollama tool calling: https://ollama.com/blog/tool-support
- Ollama MCP PR: https://github.com/ollama/ollama/pull/13700
