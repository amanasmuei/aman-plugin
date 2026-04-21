<div align="center">

<br>

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://img.shields.io/badge/aman--claude--code-Claude_Code-white?style=for-the-badge&labelColor=0d1117&color=58a6ff">
  <img alt="aman-claude-code" src="https://img.shields.io/badge/aman--claude--code-Claude_Code-black?style=for-the-badge&labelColor=f6f8fa&color=24292f">
</picture>

### The complete AI companion plugin for Claude Code.

Auto-loads your identity, memory, tools, workflows, guardrails, and skills — every session, zero setup.

<br>

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)](LICENSE)
[![aman](https://img.shields.io/badge/part_of-aman_ecosystem-ff6b35.svg?style=flat-square)](https://github.com/amanasmuei/aman)
[![Claude Code](https://img.shields.io/badge/Claude_Code-plugin-8A2BE2.svg?style=flat-square)](https://docs.claude.com/claude-code)
[![Tests](https://img.shields.io/badge/tests-20%20passing-brightgreen.svg?style=flat-square)](./test/test-hook.sh)
[![Engine](https://img.shields.io/badge/engine-v1-informational.svg?style=flat-square)](./docs/engine-v1.md)

[Install](#install) · [Features](#features) · [How to use](#how-to-use) · [Troubleshooting](#troubleshooting) · [Ecosystem](#the-ecosystem) · [Updating](#updating)

</div>

---

> ### ⚠️ Renamed from `aman-plugin` (v3.0.0)
>
> This plugin was previously published as **`aman-plugin`**. Starting with **v3.0.0** it's renamed to **`aman-claude-code`** for consistency with the rest of the ecosystem (`aman-copilot`, `aman-cursor` in the roadmap, etc.). The GitHub repo `amanasmuei/aman-plugin` auto-redirects to `amanasmuei/aman-claude-code`, so clones and bookmarks still work.
>
> **Existing users:** reinstall under the new name:
>
> ```bash
> claude plugin uninstall aman-plugin@aman
> claude plugin marketplace remove aman
> claude plugin marketplace add amanasmuei/aman-claude-code
> claude plugin install aman-claude-code@aman
> ```
>
> Your acore/arules/amem data at `~/.acore`, `~/.arules`, `~/.amem` is untouched — only the plugin wrapper is renamed. See [CHANGELOG.md](CHANGELOG.md#300) for the full migration guide and rationale.

---

## Why this exists

Even with the aman ecosystem set up, you still have to manually inject identity files, remember which slash commands do what, and manage platform config files. The gap between *"ecosystem configured"* and *"AI actually loads it"* is annoying. **aman-claude-code** bridges that gap for Claude Code. Install once, and your full AI ecosystem loads automatically every session — identity, rules, memory, tools, workflows, and skills. No CLAUDE.md injection. No manual setup per project.

---

## Install

### 1. Requirements

| Requirement | Check | Get it |
|:---|:---|:---|
| **Node.js 18+** | `node --version` | https://nodejs.org |
| **Claude Code** | `claude --version` | https://docs.claude.com/claude-code |
| **jq** *(optional, for tests)* | `jq --version` | `brew install jq` / `apt install jq` |

### 2. Set up the aman ecosystem + install the plugin

Run the one-shot ecosystem installer, then add the plugin:

```bash
# Set up identity, guardrails, and eval
npx @aman_asmuei/aman@latest

# Register the marketplace and install the plugin
claude plugin marketplace add amanasmuei/aman-claude-code
claude plugin install aman-claude-code@aman

# Install live MCP tools (read/write during sessions)
node ~/.claude/plugins/cache/aman/aman-claude-code/*/bin/install-mcp.mjs
```

The `aman@latest` wizard walks you through `acore` (identity), `arules` (guardrails), and `aeval` (relationship tracking). The plugin install wires a `SessionStart` hook that fires on every session start, resume, clear, and compact. The `install-mcp.mjs` step is idempotent and preserves any other MCP servers in your config.

<details>
<summary><b>Prefer to install layers individually?</b></summary>

```bash
npx @aman_asmuei/acore@latest            # identity    → ~/.acore/dev/plugin/core.md
npx @aman_asmuei/arules@latest init      # guardrails  → ~/.arules/dev/plugin/rules.md
npx @aman_asmuei/aeval@latest init       # evaluation
npx @aman_asmuei/akit@latest add github  # (optional) tools
npx @aman_asmuei/aflow@latest init       # (optional) workflows
```

Each installer is idempotent — safe to re-run.

</details>

<details>
<summary><b>Install the plugin from a local clone</b></summary>

```bash
git clone https://github.com/amanasmuei/aman-claude-code ~/aman-claude-code
claude plugin marketplace add ~/aman-claude-code
claude plugin install aman-claude-code@aman
```

Useful for development or testing unreleased changes.

</details>

<details>
<summary><b>What does each layer provide?</b></summary>

| Layer | Path | What it provides |
|:------|:-----|:-----------------|
| **acore** | `~/.acore/dev/plugin/core.md` | AI personality and your preferences |
| **arules** | `~/.arules/dev/plugin/rules.md` | Safety boundaries and permissions |
| **akit** | `~/.akit/kit.md` | Available tools and capabilities |
| **aflow** | `~/.aflow/flow.md` | Multi-step workflow definitions |
| **askill** | `~/.askill/skills.md` | Domain expertise |
| **amem** | `~/.amem/` *(runtime MCP)* | Persistent memory |

</details>

### 3. Add persistent memory

Memory is provided by the **amem plugin** — a separate Claude Code plugin from the same ecosystem:

```bash
claude plugin marketplace add amanasmuei/amem
claude plugin install amem@amem
npx @aman_asmuei/amem@latest init
```

> **Note:** `amem init` downloads the embedding model and stays in the foreground. Once you see `Embedding model loaded`, press `Ctrl+C` — Claude Code spawns its own amem process via the plugin when needed.

Verify by starting a Claude Code session; identity auto-loads and Claude will proactively use amem tools.

In that session, try:

- *"What do you know about me?"* — Claude should reference details from your `acore` identity.
- *"Read my identity with the MCP tool."* — Claude should call `identity_read` and return your config.
- *"Remember that I prefer pnpm over npm."* — Claude should call `memory_store`.

---

## Features

### Wake-word briefing

Type your AI's name as the first message of a session and you get a real briefing — last session narrative, today's reminders, pending rule suggestions — instead of a silent "hello":

```text
You: Sarah

Sarah: Morning, Aman — today's the 21st. Last session we wired up
       scope inheritance across the acore ecosystem (v0.3.0 now live).
       2 reminders due: the passive-observer alpha follow-up, and the
       amem RFC thread. 3 rule suggestions pending — run /rules review
       when you're ready. What's next?
```

Triggered only when your first message is just the AI's name (or a greeting with the name, like `hi Sarah`). If the first message is already a task (`Sarah, fix the login bug`), the plugin folds the greeting into the task opener — no noise added. Skipped if the name is still set to `Companion`.

> **Reliability (v3.2.0-alpha.10+).** The trigger is gated by explicit positive *and* negative examples in the session-start manifest, not prose alone. Pure wake-word inputs fire the full Boot Protocol; wake-word + task content suppresses it. Empirically validated across 6 scenarios. alpha.11 additionally drops an undocumented duplicate field from the hook's JSON emit (no behavior change, ~55% smaller hook I/O).

### Tier-loader phrases

Don't remember which `npx` command adds which layer? Just ask in plain language:

```text
You: load memory

Claude: Installing @aman_asmuei/amem (persistent memory MCP)…
        ✓ Installed. amem will auto-load on your next session.
```

Full catalog:

| You say           | Runs                                      | What it adds |
|:------------------|:------------------------------------------|:-------------|
| `load rules`      | `npx @aman_asmuei/arules init`            | Guardrails (24 starter rules) |
| `load workflows`  | `npx @aman_asmuei/aflow init`             | 4 starter workflows |
| `load memory`     | `npx @aman_asmuei/amem`                   | Persistent amem MCP |
| `load eval`       | `npx @aman_asmuei/aeval init`             | Relationship tracking |
| `load identity`   | `npx @aman_asmuei/acore`                  | Full identity (re-)walk |
| `load archetype`  | `npx @aman_asmuei/acore customize`        | Change AI personality |
| `load tools`      | `npx @aman_asmuei/akit add <name>`        | Tool kits (Claude asks which) |
| `load skills`     | `npx @aman_asmuei/askill add <name>`      | Plugin skills (Claude asks which) |

If a layer is already installed, Claude asks before re-running.

> **`load archetype` is special.** As of v3.2.0-alpha.4 the plugin no longer shells out to the interactive CLI for this phrase — Claude edits your `core.md` directly and shifts its own tone mid-session. No exit + restart required. See [Day-to-day verbs](#day-to-day-verbs--just-talk) below.

### Day-to-day verbs — just talk

Once layers are installed, you don't need `load` anymore. Say what you want in plain language — Claude maps your phrase to the right MCP tool on the `aman` server and handles it in-session:

| You say | What happens |
|:---|:---|
| *"add rule: never force-push to main"* | `rules_add` (Claude classifies the category) |
| *"can I delete this file?"* / *"is X allowed?"* | `rules_check` |
| *"list my rules"* / *"list my skills"* / *"list tools"* | `rules_list` / `skill_list` / `tools_list` |
| *"remove rule about X"* | `rules_remove` |
| *"log this session as productive"* / *"record today"* | `eval_log` |
| *"how are we doing?"* / *"show relationship report"* | `eval_report` |
| *"we hit X today"* / *"milestone: Y"* | `eval_milestone` |
| *"install testing skill"* / *"add security skill"* | `skill_install` |
| *"search skills for X"* | `skill_search` |
| *"add tool: github"* / *"install supabase tool"* | `tools_add` |
| *"add workflow: code-review"* | `workflow_add` |
| *"who am I?"* / *"show my profile"* | `identity_read` |
| *"update my role to senior architect"* | `identity_update_section` |
| *"remember that I use pnpm"* / *"don't commit secrets"* | `memory_store` |
| *"what do you remember about X?"* | `memory_recall` |

**Mental model**

```
New layer I haven't installed yet?  →  load <layer>
I want my AI to feel different?     →  load archetype (tone shifts in-session)
Everything else                     →  just say what you want
```

No phrases to memorize. Talk to your AI like a colleague — *"save this"*, *"check my rules"*, *"log today"*, *"install the testing skill"*. The plugin maps your intent to the right tool.

> Shipped in v3.2.0-alpha.5 — the session-start hook injects the full catalog so Claude knows every mapping without you teaching it.

### Project context card

Working on 5 different repos this week? aman keeps each project's context fresh automatically. The session-start hook reads `$PROJECT_ROOT/.acore/context.md` (git toplevel, or `$PWD` if you're outside a repo) and injects it into every session — so Claude knows which project you're in without being told.

```text
You: Sarah

Sarah: Morning, Aman — you're in myapp-frontend (Node/TypeScript).
       Last session here we wired up the checkout flow. 2 reminders
       due today. What's next?
```

Create the card on demand with **`npx @aman_asmuei/aman here`** (fast, single-purpose — writes the card for the current repo and exits), or let the full `npx @aman_asmuei/aman@latest` setup wizard detect your stack and write one automatically. The card captures Stack, Domain, Focus, Session, Active topics, Recent decisions, and Project Patterns — edit it directly as you work. No file? No problem: the block is silently skipped, and you get today's single-project behavior.

> **Part of a multi-project roadmap.** Path 1 (project context) shipped in v3.2.0-alpha.3. Path 2 (per-project memory tagging in amem) and Path 3 (first-class project registry) are still on the roadmap — this release is a foundation, not a full multi-project system.

### Identity that persists

Every session auto-loads `core.md` via the session-start hook. Claude greets you by name, adjusts for time of day, and picks up from where you left off — without you asking. The hook exports `AMAN_MCP_SCOPE=dev:plugin` so every MCP tool spawned during the session uses the right scope automatically.

### Guardrails (arules) + passive observer

Guardrails live in `rules.md`; the `rules_check` MCP tool consults them before risky actions. The passive observer (opt-in via `AMAN_OBSERVER_ENABLED=1`) watches for repeated corrections across sessions and queues them as rule suggestions. Review and promote them with `/rules review` — no mid-conversation interrupts, zero LLM cost.

### Memory (amem)

Persistent memory runs via the `amem-memory` MCP server. It provides `memory_store`, `memory_recall`, `memory_inject`, `reminder_check`, and ~24 more tools. Memory is shared across Claude Code and aman-copilot through amem's `dev:*` scope inheritance — one brain, multiple surfaces.

The most underused feature is the **session narrative**: at the end of a substantial session, say *"save a session narrative"* and Claude writes a 300–500 word prose memory note covering what was tried, what worked, what was decided, and why. Unlike scattered `memory_store` calls, the narrative captures the reasoning path — the attempts, the dead ends, the pivot moments. Next session, recall returns the whole story.

See [amem](https://github.com/amanasmuei/amem) for depth on memory tiers, privacy, and the full phrase catalog.

### Live tools (aman-mcp)

`aman-mcp` provides ~31 MCP tools across all ecosystem layers, all scope-aware via `dev:plugin`. These are for live read/write during a session — updating identity on the fly, rule-checking a proposed action, logging a milestone.

<details>
<summary><b>Tool categories</b></summary>

| Category | Count | Sample tools |
|:---|:---:|:---|
| **Identity** | 6 | `identity_read`, `identity_summary`, `identity_update_section`, `identity_update_session`, `identity_update_dynamics`, `avatar_prompt` |
| **Rules** | 5 | `rules_list`, `rules_check`, `rules_add`, `rules_remove`, `rules_toggle` |
| **Tools** | 4 | `tools_list`, `tools_add`, `tools_remove`, `tools_search` |
| **Workflows** | 5 | `workflow_list`, `workflow_get`, `workflow_add`, `workflow_update`, `workflow_remove` |
| **Skills** | 4 | `skill_list`, `skill_search`, `skill_install`, `skill_uninstall` |
| **Eval** | 4 | `eval_log`, `eval_milestone`, `eval_report`, `eval_status` |
| **Files / Docs** | 3 | `file_read`, `file_list`, `doc_convert` |

</details>

See [aman-mcp](https://github.com/amanasmuei/aman-mcp) for the full catalog.

---

## How to use

### Day-to-day

Natural-language patterns the plugin is instructed to act on:

| Just say | Claude does |
|:---|:---|
| *"what do you know about me?"* | Calls `identity_read`, reads your personality aloud |
| *"update my personality to The Mentor"* | Calls `identity_update_section` |
| *"add a boundary: never force-push to main"* | Calls `rules_add` |
| *"is this action allowed?"* | Calls `rules_check` against your guardrails |
| *"remember that I prefer pnpm over npm"* | Calls `memory_store` |
| *"what have I told you about testing?"* | Calls `memory_recall` |
| *"save a session narrative"* | Stores a prose narrative of the session's reasoning path |
| *"log this session"* | Calls `eval_log` |
| `load archetype`, `load memory`, `load rules` | Tier-loader runs the matching `npx` command |
| First message is your AI's name | Wake-word briefing fires |

### Slash commands

| Command | What it does |
|:--------|:-------------|
| `/identity` | View or update your AI identity |
| `/tools` | View installed tools, search the registry |
| `/workflows` | List workflows, follow them during tasks |
| `/rules` | Check guardrails, validate actions |
| `/eval` | Log sessions, view relationship report |
| `/session-narrative` ⭐ | Save a 300–500 word prose narrative of the session's reasoning path to amem |

Memory commands (`/remember`, `/recall`, `/context`, `/dashboard`, `/sync`) are provided by the separate **amem plugin**.

### Changing your AI

Run `npx @aman_asmuei/acore@latest customize` to change personality via the CLI archetype picker. Or say `load archetype` in a session and Claude walks you through the options interactively. Identity auto-reloads on the next session start.

---

## Troubleshooting

<details>
<summary><b>Plugin is installed but Claude doesn't know my identity.</b></summary>

Restart Claude Code — plugins only attach on fresh sessions. Then confirm the hook runs:

```bash
bash hooks/session-start | jq -r '.additional_context' | head -c 400
```

If the hook output is empty, confirm `~/.acore/dev/plugin/core.md` or `~/.acore/core.md` exists. If neither does, run `npx @aman_asmuei/aman@latest`.

</details>

<details>
<summary><b>Slash commands are missing.</b></summary>

Run `claude plugin list` and confirm `aman-claude-code` appears. If not, re-run the install steps. If listed but commands are absent, restart Claude Code — slash commands register at startup.

</details>

<details>
<summary><b>MCP tools don't appear in Claude Code.</b></summary>

Restart Claude Code after `install-mcp.mjs`. Then verify the entry exists:

```bash
cat ~/.claude.json | jq .mcpServers.aman
```

You should see an entry with `AMAN_MCP_SCOPE=dev:plugin`. If missing, re-run `node ~/.claude/plugins/cache/aman/aman-claude-code/*/bin/install-mcp.mjs`.

</details>

<details>
<summary><b>amem isn't recalling memories.</b></summary>

The plugin gates amem guidance on `~/.amem/` existing. Confirm:

```bash
ls -la ~/.amem
```

If missing, run `npx @aman_asmuei/amem@latest init`, then start a new session.

</details>

<details>
<summary><b>Hook errors on session start.</b></summary>

Run the hook manually to see the raw error:

```bash
bash hooks/session-start
```

Most errors are missing ecosystem files (`~/.acore/`, `~/.arules/`). Re-run `npx @aman_asmuei/aman@latest` to regenerate them.

</details>

<details>
<summary><b>How do I opt out of the passive observer?</b></summary>

The observer is opt-in: it only runs when `AMAN_OBSERVER_ENABLED=1` is set in your shell. Remove or unset that variable to disable it. The tally file at `~/.arules/dev/plugin/.tally.tsv` can be deleted safely — it will be recreated empty.

</details>

---

## The ecosystem

| Layer | Package | Purpose |
|:------|:--------|:--------|
| Identity | [acore](https://github.com/amanasmuei/acore) | Personality, values, relationship memory |
| Memory | [amem](https://github.com/amanasmuei/amem) | Persistent knowledge storage (MCP) |
| Tools | [akit](https://github.com/amanasmuei/akit) | 15 portable AI tools |
| Workflows | [aflow](https://github.com/amanasmuei/aflow) | Reusable AI workflows |
| Guardrails | [arules](https://github.com/amanasmuei/arules) | Safety boundaries and permissions |
| Skills | [askill](https://github.com/amanasmuei/askill) | Domain expertise |
| Evaluation | [aeval](https://github.com/amanasmuei/aeval) | Relationship tracking |
| MCP Server | [aman-mcp](https://github.com/amanasmuei/aman-mcp) | 31 MCP tools across all layers |
| VS Code | [aman-copilot](https://github.com/amanasmuei/aman-copilot) | GitHub Copilot Chat integration — same identity, same memory |

---

## Updating

```bash
claude plugin update aman-claude-code@aman
npx @aman_asmuei/aman@latest
```

Always use the fully-qualified `aman-claude-code@aman` form — the bare name fails with "Plugin not found". See [CHANGELOG.md](CHANGELOG.md) for what changed.

---

## Uninstall

Removes the plugin and the aman MCP entry from Claude Code. **Your identity, rules, and memory at `~/.acore`, `~/.arules`, `~/.amem` are untouched** — they survive so you can reinstall or switch to `aman-copilot` without losing anything.

```bash
claude plugin uninstall aman-claude-code@aman
claude plugin marketplace remove aman
claude mcp remove aman 2>/dev/null || true
```

To also wipe the ecosystem data and per-project cards (full uninstall across all surfaces), see the [canonical guide in the aman umbrella README](https://github.com/amanasmuei/aman#uninstall--reset).

---

## License

[MIT](LICENSE)
