# Changelog

All notable changes to `aman-plugin` are documented in this file.

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
