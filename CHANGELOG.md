# Changelog

All notable changes to `aman-claude-code` (formerly `aman-plugin`) are
documented in this file.

## 3.2.0-alpha.5 — 2026-04-21

### Added
- **Day-to-day operations verb catalog**: a new section in the injected
  system context maps natural-language phrases to the MCP tools on the
  `aman` server, across all six layers:

  | Layer | Sample phrases → MCP tool |
  |---|---|
  | **acore** | "who am I" → `identity_read`, "update my role" → `identity_update_section` |
  | **arules** | "add rule: never force-push" → `rules_add`, "can I deploy" → `rules_check`, "list rules" → `rules_list` |
  | **aeval** | "log this session" → `eval_log`, "how are we doing" → `eval_report` |
  | **aflow** | "list workflows" → `workflow_list`, "add workflow" → `workflow_add` |
  | **askill** | "list skills" → `skill_list`, "install testing skill" → `skill_install` |
  | **akit** | "list tools" → `tools_list`, "add tool: github" → `tools_add` |

  Extends the "load archetype" pattern from 3.2.0-alpha.4 to every layer —
  no shell-out to interactive CLIs for day-to-day operations. Layers can be
  added, listed, queried, removed, or updated mid-session via plain language.

### Tests
+2 assertions (37 total, was 35) verifying the Day-to-day catalog is present
with the `rules_add` / `eval_log` / `skill_install` tool references.

## 3.2.0-alpha.4 — 2026-04-21

### Added
- **In-session archetype switch**: saying `load archetype` (or close variants
  like "switch to mentor", "be more supportive", "less sparring") no longer
  shells out to the interactive `npx @aman_asmuei/acore customize` CLI. The
  LLM handles the change itself — asks which archetype you want, edits
  `~/.acore/dev/plugin/core.md` directly with canonical Personality /
  Communication / Values triples, and **shifts its own tone mid-session**.
  Change persists for future sessions via the file edit. No more exit +
  restart to try a new personality.

Canonical archetypes baked into the hook instruction:
Mentor · Collaborator · Pragmatist · Sparring Partner · Architect · Custom.

Only `load archetype` is special-cased — all other `load ...` phrases still
shell out via the existing tier-loader table.

### Tests
+2 assertions verifying the Archetype switch protocol and its SHIFT YOUR OWN
TONE instruction are present in hook output (35 total, was 33).

## 3.2.0-alpha.3 — 2026-04-21

### Added
- **Project context card**: the session-start hook now reads
  `$PROJECT_ROOT/.acore/context.md` (where `$PROJECT_ROOT` is the
  current git toplevel, or `$PWD` if outside a git repo) and injects
  it as a "Project context" block into the Claude Code session
  context. Supplements global identity with project-local stack,
  domain, active topics, and recent decisions.

The card is silently skipped when no file exists — no change to
behavior for projects that haven't run `aman setup`. This is Part 1
of 3 in the multi-project roadmap; per-project memory tagging
(Path 2) and first-class project registry (Path 3) are deferred.

See `docs/superpowers/specs/2026-04-21-project-context-card-design.md`.

## 3.2.0-alpha.2 — 2026-04-21

### Added
- **Wake-word briefing** (Block A): when the user's first message in a session
  is just the AI's identity name (e.g., "Sarah", "hi Sarah"), Claude responds
  with a session briefing — last `memory_recall` narrative, `reminder_check`
  due items, pending passive-observer suggestions, then "what's next?" — instead
  of silent auto-load. Gated on `name != "Companion"` and ecosystem present.
  Injected as an instruction block in `hooks/session-start`; no new skills or
  MCP tools required.
- **Tier-loader phrase catalog** (Block B): natural-language phrases like
  `load rules`, `load workflows`, `load memory`, `load archetype`, `load tools`,
  `load skills`, `load eval`, `load identity` map to the corresponding
  `npx @aman_asmuei/*` installer. Claude runs them via Bash when the user says
  the phrase. Respects already-installed layers by asking before re-running.

Both are additive instructions injected into the existing session-start context;
users who never trigger them see identical behavior to 3.2.0-alpha.1.

Inspired by the wake-word + tiered-discovery pattern in
[Kiyoraka/Project-AI-MemoryCore](https://github.com/Kiyoraka/Project-AI-MemoryCore).
See `docs/superpowers/specs/2026-04-21-wake-word-and-tier-loaders-design.md`.

### Fixed
- Hardened `test/test-hook.sh` cleanup (`rm -rf ... 2>/dev/null || true`) to
  prevent `set -euo pipefail` abort caused by the background `amem-cli sync`
  writing into temp HOME dirs — a pre-existing race on machines with
  `amem-cli` installed.

## 3.2.0-alpha.1 — 2026-04-20

### Added
- **Passive rule observer** (opt-in via `AMAN_OBSERVER_ENABLED=1`). Watches
  Claude Code conversations for repeated corrections and proposes them as
  rules. Session-start notice shows pending count; `/rules review --list` +
  `/rules accept|reject <n>` lets users act on proposals. Zero LLM cost.
- `UserPromptSubmit` hook wired in `hooks/hooks.json`.
- New `/rules review`, `/rules accept`, `/rules reject` commands in aman-agent.
- Cross-platform `flock` / `sha256sum` shims in `hooks/lib/compat.sh`.
- Shell-test CI on Ubuntu + macOS.

### Notes
- Alpha gating: set `AMAN_OBSERVER_ENABLED=1` to try. Default-enable targeted
  for v3.2.0 once alpha proves stable.
- English-only correction phrases in v1; Bahasa Malaysia markers planned.
- Writes only to `dev:plugin` scope for v1; per-repo scopes planned.
- `/rules review` ships `--list` + index-based accept/reject; fully interactive
  readline loop lands in v3.2.0-beta.

### Design
See `docs/superpowers/specs/2026-04-20-passive-hook-observer-design.md`.

---

## [3.1.0] — 2026-04-09

**Session narratives come to Claude Code.** New `/session-narrative`
skill, parity with aman-copilot@0.4.1's prompt file of the same name.

### Added
- **`skills/session-narrative/SKILL.md`** — new Claude Code skill that
  writes a 300–500 word flowing-prose narrative of the current
  session's reasoning path (intent → attempts → dead ends → pivot
  moments → outcome → lessons) and saves it to amem via
  `memory_store`. If amem isn't installed, falls back to writing the
  narrative into Claude Code's auto-memory directory so the next
  `amem-cli sync` will import it.
- **"Memory 101" section** in the README introduced in the previous
  commit now references `/session-narrative` as the flagship session
  closer.
- **Proactive behavior table** updated to mention `/session-narrative`
  as a session-end option for substantial work.

### Why this matters
Scattered `memory_store` calls capture *what we decided*. They don't
capture *how we got there*. A session narrative is a single prose
note per substantial session that preserves the reasoning path —
attempts, dead ends, pivot moments, lessons — so future sessions can
understand not just the outcome but the thinking that produced it.

The skill is the Claude Code twin of aman-copilot's prompt file of
the same name. Same protocol, same output shape, same amem store,
same dev:* scope inheritance — works transparently across Claude
Code, VS Code Copilot Chat, and Copilot CLI. Write a narrative in
any surface; recall it in any other.

### Parity with aman-copilot

| Feature | aman-copilot@0.4.1 | aman-claude-code@3.1.0 |
|:---|:---:|:---:|
| `/identity` | prompt file | skill (existing) |
| `/rules` | prompt file | skill (existing) |
| `/eval` | prompt file | skill (existing) |
| `/remember` | prompt file | from amem plugin |
| `/session-narrative` | prompt file | **skill (new)** |

### Inspiration
The session narrative pattern is borrowed from Kiyoraka's
[Project-AI-MemoryCore](https://github.com/Kiyoraka/Project-AI-MemoryCore)
(which also inspired acore's Fundamental Truths in 0.7.0).
MemoryCore's Save-Diary-System proved that AI-authored session
documents are a sweet spot between scattered facts and raw
transcripts. This release adapts the pattern to amem's curated-memory
philosophy.

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
