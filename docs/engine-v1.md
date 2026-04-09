# Engine v1 — what changed for aman-claude-code

aman-claude-code now consumes **engine v1**, a shared substrate published as 3 npm packages:

- [`@aman_asmuei/aman-core`](https://www.npmjs.com/package/@aman_asmuei/aman-core) — scope, `withScope`, `Storage<T>`
- [`@aman_asmuei/acore-core`](https://www.npmjs.com/package/@aman_asmuei/acore-core) — multi-tenant Identity layer
- [`@aman_asmuei/arules-core`](https://www.npmjs.com/package/@aman_asmuei/arules-core) — multi-tenant guardrails layer

## What it means for aman-claude-code (since v2.0.0, renamed from aman-plugin in v3.0.0)

- **Scope-aware skills.** `skills/identity` and `skills/rules` now resolve via the `dev:plugin` scope. They look at `~/.acore/dev/plugin/core.md` first and fall back to legacy `~/.acore/core.md`.
- **session-start hook** exports `AMAN_MCP_SCOPE=dev:plugin` and `AMAN_PLUGIN_SCOPE=dev:plugin` so the engine v1 libraries pick up the right tenant automatically when the MCP server starts.
- **Cross-platform install helpers**:
  - `bin/install-mcp.mjs` — registers `@aman_asmuei/aman-mcp` into Claude Code's `mcp.json` idempotently with atomic temp+rename
  - `bin/uninstall-mcp.mjs` — walks all candidate config paths and unregisters
- aman-claude-code itself ships **no JS dependencies** — it's still a pure Claude Code plugin (skills, hooks, slash commands). All engine code lives in `@aman_asmuei/aman-mcp ^0.6.0` which the install script wires up.

## Why it matters

The same identity and guardrail rules you tune via `/identity` and `/rules` in Claude Code now live in the **same engine** that powers aman-agent, aman-tg, and any future frontend. Edit them in one place, they apply everywhere your scope routes.

## Migration impact

**Zero for users.** Re-run the installer:

```bash
node bin/install-mcp.mjs
```

The hook will start exporting `dev:plugin` scope automatically. Legacy `~/.acore/core.md` and `~/.arules/rules.md` still work as a fallback.

## Learn more

- Engine architecture: https://github.com/amanasmuei/aman-core
- Identity layer: https://github.com/amanasmuei/acore-core
- Guardrails layer: https://github.com/amanasmuei/arules-core
