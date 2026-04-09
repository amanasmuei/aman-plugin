<div align="center">

<br>

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://img.shields.io/badge/aman--plugin-Claude_Code-white?style=for-the-badge&labelColor=0d1117&color=58a6ff">
  <img alt="aman-plugin" src="https://img.shields.io/badge/aman--plugin-Claude_Code-black?style=for-the-badge&labelColor=f6f8fa&color=24292f">
</picture>

### The complete AI companion plugin for Claude Code.

Auto-loads your identity, memory, tools, workflows, guardrails, and skills — every session, zero setup.

<br>

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)](LICENSE)
[![aman](https://img.shields.io/badge/part_of-aman_ecosystem-ff6b35.svg?style=flat-square)](https://github.com/amanasmuei/aman)

[Install](#install) · [What It Does](#what-it-does) · [Slash Commands](#slash-commands) · [Prerequisites](#prerequisites) · [Ecosystem](#the-ecosystem)

</div>

---

## The Problem

Even with the aman ecosystem set up, you still have to manually inject identity files, remember which slash commands do what, and manage platform config files. The gap between "ecosystem configured" and "AI actually loads it" is annoying.

## The Solution

**aman-plugin** bridges that gap for Claude Code. Install once, and your full AI ecosystem loads automatically every session.

```bash
claude plugins add aman-plugin https://github.com/amanasmuei/aman-plugin
```

> **No more CLAUDE.md injection. No manual setup. It just works.**

---

## Install

```bash
claude plugins add aman-plugin https://github.com/amanasmuei/aman-plugin
```

---

## What It Does

### Auto-loads your AI identity every session

The plugin's session-start hook reads your ecosystem files and injects them into every conversation. It is **engine v1 aware**: each layer is checked at the new scope-aware path first, then falls back to the legacy single-tenant path. The plugin uses scope `dev:plugin`.

| Layer | Engine v1 path (preferred) | Legacy fallback | What it provides |
|:------|:---------------------------|:----------------|:-----------------|
| acore | `~/.acore/dev/plugin/core.md` | `~/.acore/core.md` | AI personality and your preferences |
| arules | `~/.arules/dev/plugin/rules.md` | `~/.arules/rules.md` | Safety boundaries and permissions |
| akit | — | `~/.akit/kit.md` | Available tools and capabilities |
| aflow | — | `~/.aflow/flow.md` | Multi-step workflow definitions |
| askill | — | `~/.askill/skills.md` | Domain expertise |
| amem | `~/.amem/` (runtime MCP) | — | Persistent memory: corrections, decisions, reminders |

> **Engine v1 status:** `acore` and `arules` are the two essentials extracted into multi-tenant libraries (`@aman_asmuei/acore-core`, `@aman_asmuei/arules-core`). `akit`, `aflow`, and `askill` remain dormant single-tenant layers in v1 — they wake up in engine v2.

The hook also exports `AMAN_MCP_SCOPE=dev:plugin` so any MCP tool spawned during the session automatically uses the right scope.

### Proactive behavior

| Trigger | Action |
|:--------|:-------|
| **Session end** | Automatically offers to save what the AI learned |
| **Before risky actions** | Checks against your guardrails |
| **During tasks** | Follows matching workflows automatically |

---

## Slash Commands

| Command | What it does |
|:--------|:-------------|
| `/identity` | View or update your AI identity |
| `/tools` | View installed tools, search the registry |
| `/workflows` | List workflows, follow them during tasks |
| `/rules` | Check guardrails, validate actions |
| `/eval` | Log sessions, view relationship report |
| `/remember` | Store a memory (correction, decision, preference) |
| `/recall` | Search memories by topic |
| `/context` | Load full memory context for the current task |
| `/dashboard` | Inspect memory stats and recent activity |
| `/sync` | Reconcile amem with Claude auto-memory |

---

## Prerequisites

Set up the ecosystem first:

```bash
# Full setup (recommended)
npx @aman_asmuei/aman

# Or individually:
npx @aman_asmuei/acore         # identity
npx @aman_asmuei/akit add github  # tools
npx @aman_asmuei/aflow init    # workflows
npx @aman_asmuei/arules init   # guardrails
npx @aman_asmuei/aeval init    # evaluation
```

---

## Live tools (aman-mcp)

The plugin's session-start hook gives Claude Code your identity as **text in
the prompt** — fast, no tool calls, available immediately. For **live
read/write** during the session (e.g. updating your personality on the fly,
rule-checking a proposed action, syncing memory), install the aman-mcp server
alongside the plugin.

### One-command install

```bash
node bin/install-mcp.mjs
```

This adds an `aman` entry to Claude Code's `~/.claude.json` (or wherever it
keeps MCP server config) with `AMAN_MCP_SCOPE=dev:plugin` set automatically.
It is **idempotent**, **preserves any other MCP servers** in your config, and
works on macOS, Linux, and Windows.

### One-command uninstall

```bash
node bin/uninstall-mcp.mjs
```

### What you get after installing aman-mcp

aman-mcp provides **31 MCP tools**, all scope-aware via `dev:plugin`:

- **Identity (6)**: `identity_read`, `identity_summary`, `identity_update_section`, `identity_update_session`, `identity_update_dynamics`, `avatar_prompt`
- **Rules (5)**: `rules_list`, `rules_check`, `rules_add`, `rules_remove`, `rules_toggle`
- **Tools (4)**: `tools_list`, `tools_add`, `tools_remove`, `tools_search`
- **Workflows (5)**: `workflow_list`, `workflow_get`, `workflow_add`, `workflow_update`, `workflow_remove`
- **Skills (4)**: `skill_list`, `skill_search`, `skill_install`, `skill_uninstall`
- **Eval (4)**: `eval_log`, `eval_milestone`, `eval_report`, `eval_status`
- **Files/Docs (3)**: `file_read`, `file_list`, `doc_convert`

For **persistent memory**, install [amem](https://github.com/amanasmuei/amem) separately — it provides an additional ~30 MCP tools (`memory_store`, `memory_recall`, `memory_inject`, plus self-heal: `memory_doctor`, `memory_repair`, `memory_config`, `memory_sync`). The plugin's session-start hook auto-detects `~/.amem/` and injects memory guidance.

After installing, restart Claude Code and ask: *"what do you remember about me?"* — the LLM will use the MCP tools to fetch your identity directly.

### Manual install (if you prefer to edit JSON yourself)

```json
{
  "mcpServers": {
    "aman": {
      "command": "npx",
      "args": ["-y", "@aman_asmuei/aman-mcp"],
      "env": {
        "AMAN_MCP_SCOPE": "dev:plugin"
      }
    }
  }
}
```

---

## The Ecosystem

```
aman
├── acore        → identity    → who your AI IS
├── amem         → memory      → what your AI KNOWS
├── akit         → tools       → what your AI CAN DO
├── aflow        → workflows   → HOW your AI works
├── arules       → guardrails  → what your AI WON'T do
├── askill       → skills      → what your AI MASTERS
├── aeval        → evaluation  → how GOOD your AI is
├── achannel     → channels    → WHERE your AI lives
├── aman-mcp     → MCP server  → the bridge (31 tools)
├── aman-agent   → agent UI    → chat frontend w/ memory
└── aman-plugin  → plugin      → Claude Code glue  ← YOU ARE HERE
```

| Layer | Package | What it does |
|:------|:--------|:-------------|
| Identity | [acore](https://github.com/amanasmuei/acore) | Personality, values, relationship memory |
| Memory | [amem](https://github.com/amanasmuei/amem) | Automated knowledge storage (MCP) |
| Tools | [akit](https://github.com/amanasmuei/akit) | 15 portable AI tools (MCP + manual fallback) |
| Workflows | [aflow](https://github.com/amanasmuei/aflow) | Reusable AI workflows |
| Guardrails | [arules](https://github.com/amanasmuei/arules) | Safety boundaries and permissions |
| Skills | [askill](https://github.com/amanasmuei/askill) | Domain expertise |
| Evaluation | [aeval](https://github.com/amanasmuei/aeval) | Relationship tracking |
| Channels | [achannel](https://github.com/amanasmuei/achannel) | Telegram, Discord, webhooks |
| MCP Server | [aman-mcp](https://github.com/amanasmuei/aman-mcp) | 31 MCP tools across all layers |
| Agent UI | [aman-agent](https://github.com/amanasmuei/aman-agent) | Chat frontend with memory |
| **Plugin** | **aman-plugin** | **Claude Code integration** |

---

## Contributing

Contributions welcome! Open an issue or submit a PR.

## License

[MIT](LICENSE)

---

<div align="center">

**Install once. Load always. Claude Code + aman.**

</div>
