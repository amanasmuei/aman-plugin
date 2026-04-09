# Changelog

All notable changes to `aman-plugin` are documented in this file.

## [2.2.0] — 2026-04-09

### Changed
- **Memory skills moved to the amem plugin.** The 5 memory skills
  (`/remember`, `/recall`, `/context`, `/dashboard`, `/sync`) that shipped
  in 2.1.0 are now canonically provided by the separate
  [amem plugin](https://github.com/amanasmuei/amem) — which also registers
  the `amem-memory` MCP server and ships `PostToolUse` / `Stop` hooks for
  automatic memory extraction and session-end consolidation.

  Bundling the skills here created duplicate entries in the command picker
  for users who (correctly) had both plugins installed, and the skills were
  broken wrappers for users who had only aman-plugin (no MCP server to
  call). Removing them leaves a **clean command palette** and makes the
  ecosystem boundaries explicit: aman-plugin for identity/rules/tools/
  workflows/eval, amem plugin for memory.

- **README Step 5** now installs the amem plugin via the Claude Code
  marketplace (`claude plugin marketplace add amanasmuei/amem &&
  claude plugin install amem@amem`) instead of only running
  `npx @aman_asmuei/amem init`. The CLI init still runs to create the
  local database.

- **Session-start hook** no longer advertises the removed memory slash
  commands. It still auto-detects `~/.amem/` and injects memory-usage
  guidance telling Claude to proactively call the amem MCP tools
  (`memory_store`, `memory_recall`, `memory_inject`, etc.) directly.

### Removed
- `skills/remember/`, `skills/recall/`, `skills/context/`,
  `skills/dashboard/`, `skills/sync/` — see rationale above.

## [2.1.0] — 2026-04-09

### Added
- **amem integration.** The session-start hook now auto-detects `~/.amem/` and
  injects persistent-memory guidance (session-start drill, extraction signals,
  privacy rules, tier usage, self-heal tools).
- **5 new slash commands** wrapping amem: `/remember`, `/recall`, `/context`,
  `/dashboard`, `/sync`. Available under `skills/` and usable when amem-mcp is
  installed.
- **aman-agent** referenced in the ecosystem diagram and package table.
- **Test coverage** for the amem hook path, guidance gating, and
  `install-mcp.mjs` syntax/version pinning (11 → 20 tests).
- `CHANGELOG.md` (this file).
- Beefed-up `.gitignore` (node_modules, dist, .env, editor dirs, temp files).

### Changed
- **README** now reports the correct `aman-mcp` tool count (**31**, not ~17),
  broken down by category (Identity 6, Rules 5, Tools 4, Workflows 5, Skills 4,
  Eval 4, Files/Docs 3).
- README documents amem's admin/self-heal MCP tools (`memory_doctor`,
  `memory_repair`, `memory_config`, `memory_sync`) shipped with the amem-core
  extraction.
- `bin/install-mcp.mjs` now pins `@aman_asmuei/aman-mcp@^0.6.0` to prevent
  version drift when the user re-runs the installer.

### Fixed
- Ecosystem diagram no longer omits the memory and agent layers.

## [2.0.0] — engine-v1 alignment

### Added
- Engine v1 scope-aware path resolution (`~/.acore/dev/plugin/core.md`,
  `~/.arules/dev/plugin/rules.md`) with automatic fallback to legacy
  single-tenant paths.
- `AMAN_MCP_SCOPE=dev:plugin` exported by the session-start hook so any MCP
  tool spawned during the session uses the correct scope.
- `bin/install-mcp.mjs` / `bin/uninstall-mcp.mjs` for one-command
  aman-mcp registration in Claude Code's config.
- Slash commands: `/identity`, `/tools`, `/workflows`, `/rules`, `/eval`.
