# Legal & ToS Research: Claude for Automated Game Content Generation

## Applicable Legal Documents

| Document | Governs |
|----------|---------|
| **Consumer Terms of Service** | Claude.ai, Claude Pro/Max, individual products |
| **Commercial Terms of Service** | API keys, Anthropic Console, business offerings |
| **Acceptable Use Policy** | Universal prohibited uses |
| **Claude Code Documentation** | Official feature documentation |
| **Claude Agent SDK Documentation** | Programmatic SDK docs |

> No separate "Claude Code Terms of Service" exists. Claude Code falls under Consumer Terms or Commercial Terms depending on authentication method.

---

## Key Findings

### 1. Can a Local LLM Invoke Claude Code CLI via Terminal Commands?

**YES, with the correct authentication method.**

- **Consumer Terms (claude.ai subscription):** Prohibits automated/scripted access. The Consumer Terms state: *"Except when you are accessing our Services via an Anthropic API Key or where we otherwise explicitly permit it, [you may not] access the Services through automated or non-human means, whether through a bot, script, or otherwise."*
- **Commercial Terms (API key):** Explicitly permits automated access. The API is designed for programmatic use.
- **Claude Code docs** demonstrate scripted usage (piping, CI automation, `--print` mode).

**Bottom line:** Use an **Anthropic API Key** (Commercial Terms), not a claude.ai subscription, for any automated invocation.

### 2. Can Claude Code CLI Be Exposed as an MCP Server?

**YES, officially supported.**

Claude Code can run as an MCP server:
```bash
claude mcp serve
```
This exposes Claude Code's tools (Read, Write, Edit, Bash, etc.) to any MCP client. Another LLM could connect and invoke these tools programmatically.

### 3. Is `--print` Mode Allowed for Automated Content Generation?

**YES, it is a first-class supported feature designed for automation.**

Key `--print` mode features for automation:
- `--output-format` (text, json, stream-json)
- `--json-schema` for validated structured output
- `--max-turns` to limit agentic turns
- `--max-budget-usd` to cap spend per invocation
- `--dangerously-skip-permissions` for sandboxed environments
- `--system-prompt` and `--append-system-prompt` for custom prompts

### 4. Rate Limits for `--print` Mode

Rate limits depend on authentication method, not mode:

**API Key rate limits (by tier):**

| Tier | Opus RPM | Sonnet RPM | Input TPM | Output TPM |
|------|----------|------------|-----------|------------|
| Tier 1 ($5) | 50 | 50 | 30K | 8K |
| Tier 2 ($40) | 1,000 | 1,000 | 450K | 90K |
| Tier 3 ($200) | 2,000 | 2,000 | 800K | 160K |
| Tier 4 ($400) | 4,000 | 4,000 | 2M | 400K |

Tier advancement requires cumulative credit purchases.

### 5. Can Claude-Generated Output Be Used as Game Content?

**YES, you own the output.**

- **Consumer Terms:** *"Subject to your compliance with our Terms, we assign to you all of our right, title, and interest -- if any -- in Outputs."*
- **Commercial Terms:** Customers *"retain all rights to [their] Inputs, and own [their] Outputs."*
- **No training on your data** under Commercial Terms by default.
- Under Consumer Terms, training opt-out is available through account settings.

### 6. Any Restrictions on Game/Entertainment Use Cases?

**No specific restrictions.** The Acceptable Use Policy prohibits illegal activity, weapons, CSAM, self-harm promotion, fraud, etc. Standard fantasy RPG content (combat narrative, NPC dialogue, dungeon generation) does not fall under any prohibited category.

---

## API vs CLI Pricing

### API Pricing (Pay-Per-Token)

| Model | Input | Output |
|-------|-------|--------|
| Claude Opus 4.6 | $5/MTok | $25/MTok |
| Claude Sonnet 4.6 | $3/MTok | $15/MTok |
| Claude Haiku 4.5 | $1/MTok | $5/MTok |

**Batch API** (50% discount, async processing):

| Model | Batch Input | Batch Output |
|-------|-------------|--------------|
| Claude Opus 4.6 | $2.50/MTok | $12.50/MTok |
| Claude Sonnet 4.6 | $1.50/MTok | $7.50/MTok |
| Claude Haiku 4.5 | $0.50/MTok | $2.50/MTok |

### API Advantages for Forge Mode

- **Batch API** for pre-generating content at 50% off
- **Prompt caching** reduces repeated context costs by 90%
- **Structured output** with JSON schema validation
- **No automation restrictions** under Commercial Terms
- **No training on your data** by default

---

## The Claude Agent SDK

Anthropic's Agent SDK (Python + TypeScript) is purpose-built for programmatic Claude Code usage:

```python
from claude_agent_sdk import query, ClaudeAgentOptions

async for message in query(
    prompt="Generate a dungeon encounter",
    options=ClaudeAgentOptions(allowed_tools=["Read", "Write", "Edit", "Bash"]),
):
    print(message)
```

- Requires an **Anthropic API Key** (not a claude.ai subscription)
- Governed by **Commercial Terms**
- Provides all Claude Code tools
- Supports MCP servers, subagents, sessions, structured output

---

## Authentication Method Summary

| Method | Automated Use? | Governing Terms | Best For |
|--------|---------------|-----------------|----------|
| Anthropic API Key | **Yes** | Commercial Terms | Forge Mode |
| Claude.ai Subscription | **No** | Consumer Terms | Interactive dev only |
| Agent SDK | **Yes** | Commercial Terms | Forge Mode (recommended) |

---

## Recommendations for TWW

1. **Use an Anthropic API Key** for all automated content generation. This places you under Commercial Terms which explicitly permit automated usage.
2. **The Agent SDK** is the most natural fit -- programmatic library with all Claude Code tools.
3. **Cost optimization:** Use Sonnet 4.6 or Haiku 4.5 for routine generation, prompt caching for SRD rules, Batch API for pre-generation.
4. **No game/entertainment restrictions** exist in any policy document.

### Persistent Interactive CLI Session

The TWW Forge Mode uses a **persistent interactive Claude Code CLI session** rather than subprocess spawning or Agent SDK calls. This changes the ToS analysis slightly:

- **With API key (Commercial Terms):** Fully permitted. The persistent session is just a long-running API consumer.
- **With Claude subscription (Consumer Terms):** The player-action-triggered model (a human initiates every forge call by taking an in-game action) is closer to normal interactive use than fully automated batch generation. However, the orchestrator sends the actual prompt programmatically, which may still constitute "automated access." **Use an API key to be safe.**
- The `/clear` + CLAUDE.md pattern is standard Claude Code behavior, not a workaround.

### What NOT To Do
- Do not use a claude.ai consumer subscription for automated/scripted generation
- Do not use Claude output to train competing AI models
- Do not resell Claude API access itself as a service

---

## Ambiguities / Gaps

1. Exact Claude Code CLI rate limits under claude.ai subscription are not publicly documented the same way as API limits.
2. Claude Code's documentation shows scripted usage without distinguishing authentication methods, but the Agent SDK docs explicitly require API keys for third-party products.
3. If concerned, a 1-paragraph email to Anthropic support describing the architecture would clarify:

> *"We are building a single-player dungeon crawler game running on a Jetson Orin Nano. A local LLM handles real-time DM duties. We want to use the Claude Agent SDK (authenticated via API key) for async content generation -- generating dungeon maps, monster stats, and narrative content as game files. The local LLM's Python orchestrator would invoke the Agent SDK programmatically to produce these files. Is this use case permitted under the Commercial Terms?"*
