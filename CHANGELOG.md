# Changelog

All notable changes to `aman-claude-code` (formerly `aman-plugin`) are
documented in this file.

## [3.0.0] — 2026-04-09

**Renamed from `aman-plugin` to `aman-claude-code`.** This is a
user-facing breaking change — existing installs must be removed and
re-installed under the new name. Data in `~/.acore`, `~/.arules`,
`~/.amem` is preserved; only the plugin wrapper is renamed.

### Why

The ecosystem previously had one plugin (`aman-plugin`) for Claude Code.
The moment a second surface joined — `aman-copilot` for GitHub Copilot
Chat + Copilot CLI — the name `aman-plugin` became the odd one out.
Every other package in the ecosystem is named after the surface it
adapts (`aman-copilot`, `aman-agent`, `aman-tg`, `aman-showcase`, ...),
so the Claude Code plugin should be `aman-claude-code` for parity.

More siblings are planned (`aman-cursor`, JetBrains, ...). Renaming now
— with only aman-copilot as a companion — is far cheaper than renaming
later once there are 4+ adapters.

### Changed
- Plugin name in `.claude-plugin/marketplace.json` and
  `.claude-plugin/plugin.json`: `aman-plugin` → `aman-claude-code`
- GitHub repository: `amanasmuei/aman-plugin` → `amanasmuei/aman-claude-code`
  (GitHub auto-redirects old URLs, so existing clones and links still work)
- All references in README updated to the new name
- Plugin cache path: `~/.claude/plugins/cache/aman/aman-plugin/*/` →
  `~/.claude/plugins/cache/aman/aman-claude-code/*/`
- Slash command namespace: `/aman-plugin:*` → `/aman-claude-code:*`
- Version bumped `2.3.1` → `3.0.0` to signal the breaking rename

### Migration guide

Existing users need three commands to migrate:

```bash
# 1. Uninstall the old plugin
claude plugin uninstall aman-plugin@aman

# 2. Remove the marketplace entry (so the new one can be added cleanly)
claude plugin marketplace remove aman

# 3. Re-add the marketplace and install under the new name
claude plugin marketplace add amanasmuei/aman-claude-code
claude plugin install aman-claude-code@aman
```

Then restart Claude Code. Your identity, rules, and memory are preserved
throughout — they live in `~/.acore`, `~/.arules`, and `~/.amem`, which
this plugin only reads from.

If you had previously installed `aman-mcp` via the old cache path:

```bash
# Old
node ~/.claude/plugins/cache/aman/aman-plugin/*/bin/install-mcp.mjs

# New
node ~/.claude/plugins/cache/aman/aman-claude-code/*/bin/install-mcp.mjs
```

The new path is populated automatically after installing the plugin.

### Not changed
- The marketplace name (`aman`) is unchanged — only the plugin inside
  the marketplace is renamed.
- The session-start hook behavior is unchanged.
- The ecosystem libraries (acore-core, arules-core, amem, aman-mcp) are
  unchanged — this rename only affects the Claude Code plugin wrapper.

## [2.3.1] — 2026-04-09

### Added
- **Auto-sync Claude auto-memory into amem on SessionStart.** The
  session-start hook now fires `amem-cli sync` in the background
  (fire-and-forget) whenever a session starts, resumes, clears, or
  compacts. This closes the drift between Claude Code's built-in
  auto-memory files (`~/.claude/projects/*/memory/*.md`) and amem,
  which is the canonical memory store for the aman ecosystem.
  Non-blocking (no startup latency), silent (suppresses the cosmetic
  embedding-model shutdown crash), and safe if `amem-cli` is not
  installed. Non-destructive — sync deduplicates by content hash.

## [2.3.0] — 2026-04-09

### Added
- **Time-aware session greeting.** The SessionStart hook now captures local
  time + timezone from the OS and injects a directive telling Claude to
  greet the user warmly as their aman companion at the start of each
  session. Tone adapts to time of day (morning energy / afternoon
  steadiness / evening warmth / late-night care), pulls the user's name
  from the `Relationship` section of `core.md`, and adds one short,
  varied line of spirit — a genuine spark of encouragement, affirmation,
  or presence — with explicit anti-cliché guidance. Capped at 2–3
  sentences so it stays warm, not performative. Zero config required:
  timezone comes from `date`, so it travels with the user.

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
