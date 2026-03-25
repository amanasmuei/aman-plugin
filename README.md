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

The plugin's session-start hook reads your ecosystem files and injects them into every conversation:

| File | What it provides |
|:-----|:-----------------|
| `~/.acore/core.md` | AI personality and your preferences |
| `~/.akit/kit.md` | Available tools and capabilities |
| `~/.aflow/flow.md` | Multi-step workflow definitions |
| `~/.arules/rules.md` | Safety boundaries and permissions |
| `~/.askill/skills.md` | Domain expertise |

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

## MCP Server

For even deeper integration, add the aman MCP server alongside the plugin:

```json
{
  "mcpServers": {
    "aman": {
      "command": "npx",
      "args": ["-y", "@aman_asmuei/aman-mcp"]
    }
  }
}
```

This gives Claude Code 11 additional MCP tools to read/write identity, tools, workflows, rules, and evaluation data programmatically.

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
├── aman-mcp     → MCP server  → the bridge
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
| MCP Server | [aman-mcp](https://github.com/amanasmuei/aman-mcp) | 11 MCP tools for all layers |
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
