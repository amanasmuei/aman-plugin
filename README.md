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

[Quickstart](#quickstart) · [Updating](#updating) · [Managing Your AI](#managing-your-ai) · [Slash Commands](#slash-commands) · [Live Tools](#live-tools-aman-mcp) · [Troubleshooting](#troubleshooting) · [Ecosystem](#the-ecosystem)

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

## The Problem

Even with the aman ecosystem set up, you still have to manually inject identity files, remember which slash commands do what, and manage platform config files. The gap between *"ecosystem configured"* and *"AI actually loads it"* is annoying.

## The Solution

**aman-claude-code** bridges that gap for Claude Code. Install once, and your full AI ecosystem loads automatically every session — identity, rules, memory, tools, workflows, and skills.

```bash
claude plugin marketplace add amanasmuei/aman-claude-code
claude plugin install aman-claude-code@aman
```

> **No more CLAUDE.md injection. No manual setup. It just works.**

> **Also use VS Code Copilot Chat or the Copilot CLI?** Install the sibling adapter — same identity, same rules, same memory, three surfaces:
>
> ```bash
> npx @aman_asmuei/aman-copilot init              # any project
> npx @aman_asmuei/aman-copilot install-mcp --all # VS Code + Copilot CLI
> ```
>
> `--all` writes to both VS Code's `mcp.json` and Copilot CLI's `~/.copilot/mcp-config.json` in one call, seeds the `dev:copilot` scope from your existing aman-claude-code identity, and preserves any other MCP servers you have configured. See [aman-copilot](https://github.com/amanasmuei/aman-copilot) for details. One ecosystem, two IDEs, one terminal CLI, zero duplication.

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
npx @aman_asmuei/aman@latest
```

This walks you through setting up `acore` (identity), `arules` (guardrails), and `aeval` (relationship tracking).

> **New in acore 0.7.0:** developer archetypes now ship with **Fundamental Truths** — short self-anchoring assertions the AI re-reads each session so it stays in character across long conversations (e.g. The Mentor stays patient; The Pragmatist keeps leading with the answer). Non-breaking, additive. See [acore#1](https://github.com/amanasmuei/acore/issues/1) for the design story. Concept credit: [Kiyoraka/Project-AI-MemoryCore](https://github.com/Kiyoraka/Project-AI-MemoryCore).

> **Why `npx @latest` and not `npm install -g`?**
> These are one-shot setup commands — run once, done. `npx` keeps your global `node_modules` clean and avoids `sudo` / permission issues on macOS and Linux. The explicit `@latest` tag matters: **npx caches binaries**, so if you (or your friend) ran a package yesterday you may get the cached older version on the next run. `@latest` forces a fresh resolve against the npm registry. If you *really* want a global install, `npm install -g @aman_asmuei/aman` works too — but it's not recommended for most users.

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

### Step 3 — Install the plugin

Claude Code installs plugins from **marketplaces**. This repo ships its own marketplace manifest, so you add it as a marketplace once, then install the plugin from it:

```bash
# 1. Register this repo as a marketplace
claude plugin marketplace add amanasmuei/aman-claude-code

# 2. Install the plugin from it
claude plugin install aman-claude-code@aman
```

Claude Code registers the plugin and wires its `SessionStart` hook. From now on, the hook fires automatically on every session start, resume, clear, and compact.

<details>
<summary><b>Other ways to install</b></summary>

**From inside Claude Code** — use the `/plugin` slash command, then pick `aman-claude-code` after adding the marketplace.

**From a local clone** — useful for development:

```bash
git clone https://github.com/amanasmuei/aman-claude-code ~/aman-claude-code
claude plugin marketplace add ~/aman-claude-code
claude plugin install aman-claude-code@aman
```

**Verify the install:**

```bash
claude plugin list
```

</details>

### Step 4 — Install live tools (`aman-mcp`)

The hook gives Claude your identity as **text in the prompt** — fast, zero tool calls. For **live read/write during the session** (updating identity on the fly, rule-checking a proposed action, etc.), install the MCP server:

```bash
node ~/.claude/plugins/cache/aman/aman-claude-code/*/bin/install-mcp.mjs
```

This is **idempotent**, **preserves any other MCP servers** in your config, and works on macOS, Linux, and Windows. It pins `@aman_asmuei/aman-mcp@^0.6.0` to prevent drift.

> **Where does that path come from?** Claude Code caches marketplace-installed plugins at `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`. Since this plugin ships in a marketplace named `aman`, the `*` glob picks whichever version is currently installed.

### Step 5 — Add persistent memory *(recommended)*

Memory is provided by the **amem plugin** — a separate Claude Code plugin from the same ecosystem. Install it alongside aman-claude-code:

```bash
claude plugin marketplace add amanasmuei/amem
claude plugin install amem@amem
```

This gives you:

- The **`amem-memory` MCP server** (~30 tools: `memory_store`, `memory_recall`, `memory_inject`, `memory_doctor`, etc.)
- **Memory skills** — `/remember`, `/recall`, `/context`, `/dashboard`, `/sync`
- **Automatic extraction** via a `PostToolUse` hook (learns from tool calls)
- **Session-end consolidation** via a `Stop` hook

Then initialize the local database once:

```bash
npx @aman_asmuei/amem@latest init
```

Once `~/.amem/` exists, aman-claude-code's session-start hook **auto-detects it** and injects memory-usage guidance. Claude will proactively use the amem MCP tools during every session.

> **Heads up — `amem init` keeps running.** The first run downloads the embedding model and then **stays in the foreground as an MCP server**. Once you see lines like `Vector index built: N vectors` and `Embedding model loaded`, initialization is complete — **press `Ctrl+C` to exit**. Claude Code spawns its own amem process via the plugin when needed, so you don't need to keep this one running.

> **Why two plugins?** aman-claude-code handles identity, rules, tools, workflows, eval (the acore/arules/akit/aflow/aeval layers). amem-plugin handles persistent memory. They're complementary and have no overlap — together they form the full aman ecosystem for Claude Code.

### Step 6 — Verify

Restart Claude Code. In a new session, try:

- [ ] *"What do you know about me?"* — Claude should reference details from your `acore` identity.
- [ ] *"Read my identity with the MCP tool."* — Claude should call `identity_read` and return your config. *(requires Step 4)*
- [ ] *"Remember that I prefer pnpm over npm."* — Claude should call `memory_store`. *(requires Step 5 — amem plugin)*

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

## Updating

To pull the latest version from the marketplace:

```bash
claude plugin marketplace update aman
claude plugin update aman-claude-code@aman
```

Then `/reload-plugins` inside Claude Code (or restart). The first command re-fetches the marketplace manifest from GitHub; the second applies the new version to your install. Always use `aman-claude-code@aman` (with the marketplace qualifier) — the bare `aman-claude-code` will return *"Plugin not found"*.

> **Tip:** run `claude plugin list` to see what's installed and at which scope (`user` or `project`). If you see the same plugin listed twice, you probably installed it once globally and once inside a project — keep the `user` scope one and uninstall the other with `claude plugin uninstall aman-claude-code@aman --scope project`.

See [CHANGELOG.md](CHANGELOG.md) for what's new in each release.

---

## Managing Your AI

Once the plugin is installed, you have **two ways** to manage your identity, rules, and memory — use whichever feels natural.

### First-time setup → use the CLI

The `npx @aman_asmuei/acore` wizard gives you the best onboarding:

- Auto-detected name from `git config`
- Auto-detected platform (writes to the right file for Claude Code, Cursor, etc.)
- **Visual archetype picker** with all 25 options
- Creates the identity file at the correct scope-aware path

```bash
npx @aman_asmuei/acore@latest         # identity — one-time, 15 seconds
npx @aman_asmuei/arules@latest init   # guardrails — one-time
```

### Day-to-day → just talk to Claude

After the initial bootstrap, **you don't need the CLI anymore**. The plugin's `identity`, `rules`, `tools`, `workflows`, and `eval` skills — combined with the `aman-mcp` live tools from [Step 4](#step-4--install-live-tools-aman-mcp) — let Claude read and write your ecosystem files directly from inside any conversation:

| Just say | Claude does |
|:---|:---|
| *"what do you know about me?"* | Calls `identity_read`, reads your personality aloud |
| *"update my personality to The Mentor"* | Calls `identity_update_section` |
| *"add a boundary: never force-push to main"* | Calls `rules_add` |
| *"is this action allowed?"* | Calls `rules_check` against your guardrails |
| *"remember that I prefer pnpm over npm"* | Calls `memory_store` (requires amem plugin) |
| *"what have I told you about testing?"* | Calls `memory_recall` |
| *"log this session"* | Calls `eval_log` |

No slash commands needed — the plugin's skills auto-trigger on natural language. You can also invoke them explicitly with `/aman-claude-code:identity`, `/aman-claude-code:rules`, etc.

> **Can I skip the CLI entirely?** Technically yes — Claude can call `identity_update_section` to build a fresh config from a prompt like *"set up my identity, I'm a developer, use the Pragmatist archetype"*. But you'll miss the visual archetype picker and auto-detection. For first-time setup, the 15-second CLI run is worth it.

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

> **Memory commands** (`/remember`, `/recall`, `/context`, `/dashboard`, `/sync`) are provided by the separate **amem plugin** — see [Step 5](#step-5--add-persistent-memory-recommended) to install it.

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
node ~/.claude/plugins/cache/aman/aman-claude-code/*/bin/uninstall-mcp.mjs
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
4. If neither exists, you haven't set up the ecosystem yet — run `npx @aman_asmuei/aman@latest`.

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

If missing, run `npx @aman_asmuei/amem@latest init`. Then start a new Claude Code session.

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
claude plugin marketplace update aman
claude plugin update aman-claude-code@aman
```

> **Note:** always use the fully-qualified `aman-claude-code@aman` form (plugin name + marketplace name). The bare `aman-claude-code` will fail with *"Plugin not found"* because Claude Code needs the marketplace qualifier to disambiguate.

Then restart Claude Code. See [CHANGELOG.md](CHANGELOG.md) for what changed.

</details>

<details>
<summary><b>How do I uninstall everything?</b></summary>

```bash
node ~/.claude/plugins/cache/aman/aman-claude-code/*/bin/uninstall-mcp.mjs  # removes aman-mcp from ~/.claude.json
claude plugin uninstall aman-claude-code@aman                             # removes the plugin
claude plugin marketplace remove aman                                # removes the marketplace entry
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
├── aman-claude-code  → plugin      → Claude Code glue  ← YOU ARE HERE
└── aman-copilot → plugin      → VS Code + GitHub Copilot Chat glue
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
| **Claude Code** | **aman-claude-code** | **Claude Code integration** |
| VS Code | [aman-copilot](https://github.com/amanasmuei/aman-copilot) | GitHub Copilot Chat integration |

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
