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
[![Claude Code](https://img.shields.io/badge/Claude_Code-plugin-8A2BE2.svg?style=flat-square)](https://docs.claude.com/claude-code)
[![Tests](https://img.shields.io/badge/tests-20%20passing-brightgreen.svg?style=flat-square)](./test/test-hook.sh)
[![Engine](https://img.shields.io/badge/engine-v1-informational.svg?style=flat-square)](./docs/engine-v1.md)

[Quickstart](#quickstart) · [What It Does](#what-it-does) · [Slash Commands](#slash-commands) · [Live Tools](#live-tools-aman-mcp) · [Troubleshooting](#troubleshooting) · [Ecosystem](#the-ecosystem)

</div>

---

## The Problem

Even with the aman ecosystem set up, you still have to manually inject identity files, remember which slash commands do what, and manage platform config files. The gap between *"ecosystem configured"* and *"AI actually loads it"* is annoying.

## The Solution

**aman-plugin** bridges that gap for Claude Code. Install once, and your full AI ecosystem loads automatically every session — identity, rules, memory, tools, workflows, and skills.

> **No more CLAUDE.md injection. No manual setup. It just works.**

---

## Quickstart

Six steps. Under five minutes.

### Step 1 — Check requirements

You need:

| Requirement | Check | Get it |
|:---|:---|:---|
| **Node.js 18+** | `node --version` | https://nodejs.org |
| **Claude Code** | `claude --version` | https://docs.claude.com/claude-code |
| **jq** *(optional, for tests)* | `jq --version` | `brew install jq` / `apt install jq` |

### Step 2 — Set up the aman ecosystem

The plugin loads files the ecosystem writes to your home directory. Run the one-shot installer:

```bash
npx @aman_asmuei/aman
```

This walks you through setting up `acore` (identity), `arules` (guardrails), and `aeval` (relationship tracking).

> **Why `npx` and not `npm install -g`?**
> These are one-shot setup commands — run once, done. `npx` keeps your global `node_modules` clean, always pulls the latest published version, and avoids `sudo` / permission issues on macOS and Linux. If you *really* want a global install (e.g. you run the CLIs dozens of times a day), `npm install -g @aman_asmuei/aman` works too — but it's not recommended for most users.

<details>
<summary><b>Prefer to install layers individually?</b></summary>

```bash
npx @aman_asmuei/acore            # identity    → ~/.acore/dev/plugin/core.md
npx @aman_asmuei/arules init      # guardrails  → ~/.arules/dev/plugin/rules.md
npx @aman_asmuei/aeval init       # evaluation
npx @aman_asmuei/akit add github  # (optional) tools
npx @aman_asmuei/aflow init       # (optional) workflows
```

Each installer is idempotent — safe to re-run.

</details>

### Step 3 — Install the plugin

```bash
claude plugins add aman-plugin https://github.com/amanasmuei/aman-plugin
```

Claude Code registers the plugin and wires its `SessionStart` hook. From now on, the hook fires automatically on every session start, resume, clear, and compact.

### Step 4 — Install live tools (`aman-mcp`)

The hook gives Claude your identity as **text in the prompt** — fast, zero tool calls. For **live read/write during the session** (updating identity on the fly, rule-checking a proposed action, etc.), install the MCP server:

```bash
cd "$(claude plugins path aman-plugin 2>/dev/null || echo ~/.claude/plugins/aman-plugin)"
node bin/install-mcp.mjs
```

This is **idempotent**, **preserves any other MCP servers** in your config, and works on macOS, Linux, and Windows. It pins `@aman_asmuei/aman-mcp@^0.6.0` to prevent drift.

### Step 5 — Add persistent memory *(recommended)*

Install [amem](https://github.com/amanasmuei/amem) for cross-session memory — corrections, decisions, preferences, and reminders:

```bash
npx @aman_asmuei/amem init
```

Once `~/.amem/` exists, the plugin **auto-detects it** and injects memory guidance. Claude will proactively call `memory_store`, `memory_recall`, and `memory_inject` during sessions.

### Step 6 — Verify

Restart Claude Code. In a new session, try:

- [ ] *"What do you know about me?"* — Claude should reference details from your `acore` identity.
- [ ] *"Read my identity with the MCP tool."* — Claude should call `identity_read` and return your config. *(requires Step 4)*
- [ ] *"Remember that I prefer pnpm over npm."* — Claude should call `memory_store`. *(requires Step 5)*

<details>
<summary><b>Run the test suite</b></summary>

```bash
bash test/test-hook.sh
```

Expected: `Results: 20 passed, 0 failed, 20 total`

</details>

<details>
<summary><b>Inspect what the hook injects into your session</b></summary>

```bash
bash hooks/session-start | jq -r '.additional_context' | head -40
```

You should see your identity, rules, and (if amem is installed) memory guidance.

</details>

---

## What It Does

### Auto-loads your AI identity every session

The session-start hook reads your ecosystem files and injects them into every conversation. It is **engine v1 aware** — each layer is checked at the new scope-aware path first, then falls back to the legacy single-tenant path. Scope: `dev:plugin`.

| Layer | Engine v1 path (preferred) | Legacy fallback | What it provides |
|:------|:---------------------------|:----------------|:-----------------|
| **acore** | `~/.acore/dev/plugin/core.md` | `~/.acore/core.md` | AI personality and your preferences |
| **arules** | `~/.arules/dev/plugin/rules.md` | `~/.arules/rules.md` | Safety boundaries and permissions |
| **akit** | — | `~/.akit/kit.md` | Available tools and capabilities |
| **aflow** | — | `~/.aflow/flow.md` | Multi-step workflow definitions |
| **askill** | — | `~/.askill/skills.md` | Domain expertise |
| **amem** | `~/.amem/` *(runtime MCP)* | — | Persistent memory: corrections, decisions, reminders |

> **Engine v1 status:** `acore` and `arules` are the two essentials extracted into multi-tenant libraries (`@aman_asmuei/acore-core`, `@aman_asmuei/arules-core`). `akit`, `aflow`, and `askill` remain dormant single-tenant layers in v1 — they wake up in engine v2.

The hook also exports `AMAN_MCP_SCOPE=dev:plugin` so any MCP tool spawned during the session automatically uses the right scope.

### Proactive behavior

| Trigger | Action |
|:--------|:-------|
| **Session start / resume / clear** | Loads identity, rules, and memory guidance into context |
| **Corrections** (*"don't"*, *"never"*, *"stop"*) | Stores in amem as absolute constraints |
| **Architecture decisions** | Stores as versioned decisions in amem |
| **Before risky actions** | Checks against your guardrails |
| **During tasks** | Follows matching workflows automatically |
| **Session end** | Offers to save what the AI learned |

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

## Live Tools (`aman-mcp`)

`aman-mcp` provides **31 MCP tools**, all scope-aware via `dev:plugin`.

<details>
<summary><b>Full tool catalog (click to expand)</b></summary>

| Category | Count | Tools |
|:---|:---:|:---|
| **Identity** | 6 | `identity_read`, `identity_summary`, `identity_update_section`, `identity_update_session`, `identity_update_dynamics`, `avatar_prompt` |
| **Rules** | 5 | `rules_list`, `rules_check`, `rules_add`, `rules_remove`, `rules_toggle` |
| **Tools** | 4 | `tools_list`, `tools_add`, `tools_remove`, `tools_search` |
| **Workflows** | 5 | `workflow_list`, `workflow_get`, `workflow_add`, `workflow_update`, `workflow_remove` |
| **Skills** | 4 | `skill_list`, `skill_search`, `skill_install`, `skill_uninstall` |
| **Eval** | 4 | `eval_log`, `eval_milestone`, `eval_report`, `eval_status` |
| **Files / Docs** | 3 | `file_read`, `file_list`, `doc_convert` |

</details>

For **persistent memory**, install [amem](https://github.com/amanasmuei/amem) separately — it adds ~30 more MCP tools including `memory_store`, `memory_recall`, `memory_inject`, plus self-heal utilities (`memory_doctor`, `memory_repair`, `memory_config`, `memory_sync`).

<details>
<summary><b>Manual install (edit JSON yourself)</b></summary>

Add this block to `~/.claude.json` under `mcpServers`:

```json
{
  "mcpServers": {
    "aman": {
      "command": "npx",
      "args": ["-y", "@aman_asmuei/aman-mcp@^0.6.0"],
      "env": {
        "AMAN_MCP_SCOPE": "dev:plugin"
      }
    }
  }
}
```

Then restart Claude Code.

</details>

<details>
<summary><b>Uninstall aman-mcp</b></summary>

```bash
node bin/uninstall-mcp.mjs
```

</details>

---

## Troubleshooting

<details>
<summary><b>The plugin is installed but Claude doesn't seem to know my identity.</b></summary>

1. **Restart Claude Code.** Plugins only attach on fresh sessions.
2. **Confirm the hook runs:**
   ```bash
   bash hooks/session-start | jq -r '.additional_context' | head -c 400
   ```
   You should see your identity content.
3. **Confirm your identity file exists:**
   ```bash
   ls ~/.acore/dev/plugin/core.md 2>/dev/null || ls ~/.acore/core.md
   ```
4. If neither exists, you haven't set up the ecosystem yet — run `npx @aman_asmuei/aman`.

</details>

<details>
<summary><b><code>aman-mcp</code> tools don't appear in Claude Code.</b></summary>

1. Did you **restart Claude Code** after running `node bin/install-mcp.mjs`? MCP servers load on startup.
2. **Check your config:**
   ```bash
   cat ~/.claude.json | jq .mcpServers.aman
   ```
   You should see an entry with `AMAN_MCP_SCOPE=dev:plugin`.
3. **Check the MCP server is reachable:**
   ```bash
   npx -y @aman_asmuei/aman-mcp@^0.6.0 --help
   ```

</details>

<details>
<summary><b>amem tools / memory guidance aren't loading.</b></summary>

The plugin gates amem guidance on `~/.amem/` existing. Confirm:

```bash
ls -la ~/.amem
```

If missing, run `npx @aman_asmuei/amem init`. Then start a new Claude Code session.

</details>

<details>
<summary><b>How do I know which scope the plugin is using?</b></summary>

The plugin always uses `dev:plugin`. Verify:

```bash
grep AMAN_MCP_SCOPE hooks/session-start
```

</details>

<details>
<summary><b>I'm on engine v0 — will the plugin still work?</b></summary>

Yes. The hook tries engine-v1 scope-aware paths first, then automatically falls back to the legacy single-tenant paths (`~/.acore/core.md`, `~/.arules/rules.md`, etc.). Existing users keep working unchanged.

</details>

<details>
<summary><b>How do I update the plugin?</b></summary>

```bash
claude plugins update aman-plugin
```

Then restart Claude Code. See [CHANGELOG.md](CHANGELOG.md) for what changed.

</details>

<details>
<summary><b>How do I uninstall everything?</b></summary>

```bash
node bin/uninstall-mcp.mjs            # removes aman-mcp from ~/.claude.json
claude plugins remove aman-plugin     # removes the plugin
# (optional) remove ecosystem data:
rm -rf ~/.acore ~/.arules ~/.amem ~/.aeval ~/.akit ~/.aflow ~/.askill
```

</details>

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
| Memory | [amem](https://github.com/amanasmuei/amem) | Persistent knowledge storage (MCP) |
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

Contributions welcome! Please:

1. Open an issue describing the change before sending a PR for anything non-trivial.
2. Run `bash test/test-hook.sh` before submitting — **all 20 tests must pass.**
3. Update [`CHANGELOG.md`](CHANGELOG.md) under the next unreleased version.

## License

[MIT](LICENSE)

---

<div align="center">

**Install once. Load always. Claude Code + aman.**

<sub>Built with care as part of the <a href="https://github.com/amanasmuei/aman">aman ecosystem</a>.</sub>

</div>
