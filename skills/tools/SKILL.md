---
name: tools
description: "Manage your AI toolkit. Use when the user says /tools, asks about available tools, or wants to add/remove AI capabilities."
---

# Tools Management

You are managing the user's AI toolkit stored in `~/.akit/kit.md` and `~/.akit/installed.json`.

## When invoked

1. Check if `~/.akit/kit.md` exists
2. If yes: read and display installed tools with their status (MCP vs manual)
3. If no: inform the user they can set up tools with `npx @aman_asmuei/akit add <tool>`

## Available tools in the registry

The user can add these tools via `npx @aman_asmuei/akit add <name>`:

| Tool | What it does |
|:-----|:-------------|
| web-search | Search the web |
| brave-search | Private web search |
| github | PRs, issues, repos |
| git | Log, diff, blame |
| filesystem | Read, write, search files |
| memory | amem integration |
| postgres | PostgreSQL queries |
| sqlite | SQLite queries |
| fetch | HTTP requests |
| puppeteer | Browser automation |
| slack | Team messaging |
| notion | Notes and docs |
| linear | Issue tracking |
| sentry | Error monitoring |
| docker | Container management |

## Adding/removing tools

Guide the user to use the CLI:
- `npx @aman_asmuei/akit add github` — adds a tool
- `npx @aman_asmuei/akit remove github` — removes a tool
- `npx @aman_asmuei/akit search <query>` — search the registry
