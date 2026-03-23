# aman — Claude Code Plugin

The complete AI companion plugin for Claude Code. Gives your AI persistent identity, memory, tools, workflows, guardrails, and evaluation — automatically loaded every session.

## Install

```bash
claude plugins add aman-plugin https://github.com/amanasmuei/aman-plugin
```

## What it does

### Auto-loads your AI identity every session

The plugin's session-start hook reads your ecosystem files and injects them into every conversation:

- `~/.acore/core.md` — your AI's identity and personality
- `~/.akit/kit.md` — your AI's toolkit
- `~/.aflow/flow.md` — your AI's workflows
- `~/.arules/rules.md` — your AI's guardrails

No more CLAUDE.md injection. No manual setup. It just works.

### Slash commands

| Command | What it does |
|:--------|:-------------|
| `/identity` | View or update your AI identity |
| `/tools` | View installed tools, search the registry |
| `/workflows` | List workflows, follow them during tasks |
| `/rules` | Check guardrails, validate actions |
| `/eval` | Log sessions, view relationship report |

### Proactive behavior

- **Session end**: automatically offers to save what the AI learned
- **Before risky actions**: checks against your guardrails
- **During tasks**: follows matching workflows automatically

## Prerequisites

Set up the ecosystem first:

```bash
npx @aman_asmuei/aman          # full setup (recommended)
# or individually:
npx @aman_asmuei/acore         # identity
npx @aman_asmuei/akit add github  # tools
npx @aman_asmuei/aflow init    # workflows
npx @aman_asmuei/arules init   # guardrails
npx @aman_asmuei/aeval init    # evaluation
```

## The Ecosystem

```
aman
├── acore   →  identity     →  who your AI IS
├── amem    →  memory       →  what your AI KNOWS
├── akit    →  tools        →  what your AI CAN DO
├── aflow   →  workflows    →  HOW your AI works
├── arules  →  guardrails   →  what your AI WON'T do
└── aeval   →  evaluation   →  how GOOD your AI is
```

| Layer | Package | What it does |
|:------|:--------|:-------------|
| Identity | [acore](https://github.com/amanasmuei/acore) | Personality, values, relationship memory |
| Memory | [amem](https://github.com/amanasmuei/amem) | Automated knowledge storage (MCP) |
| Tools | [akit](https://github.com/amanasmuei/akit) | 15 portable AI tools (MCP + manual fallback) |
| Workflows | [aflow](https://github.com/amanasmuei/aflow) | Reusable AI workflows |
| Guardrails | [arules](https://github.com/amanasmuei/arules) | Safety boundaries and permissions |
| Evaluation | [aeval](https://github.com/amanasmuei/aeval) | Relationship tracking and session logging |
| MCP Server | [aman-mcp](https://github.com/amanasmuei/aman-mcp) | 11 MCP tools for all layers |
| **Plugin** | **aman-plugin** | **Claude Code integration** |

## MCP Server

For even deeper integration, add the aman MCP server:

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

This gives Claude Code 11 additional tools to read/write identity, tools, workflows, rules, and evaluation data programmatically.

## License

[MIT](LICENSE)
