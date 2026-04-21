# Wake-word Briefing + Tier-loader Phrases — Design

**Status:** Design approved, pending implementation plan
**Date:** 2026-04-21
**Scope:** `aman-claude-code` plugin + `aman-copilot` (parity)
**Prior art:** [Kiyoraka/Project-AI-MemoryCore](https://github.com/Kiyoraka/Project-AI-MemoryCore) — wake-word activation ritual + tiered feature discovery via natural-language phrases.

## 1. Purpose

Give the aman ecosystem the same session-time UX moment Kiyoraka's MemoryCore has: the user types just the AI's name and gets an explicit "I'm loaded, here's where we left off" briefing — and discovers optional ecosystem layers by asking for them in plain language (`load rules`, `load memory`) instead of hunting through READMEs for npx commands.

Both behaviors are delivered as instruction blocks injected into the LLM's system context. No new skills, no new CLI commands, no SKILL.md personalization, no wizard refactor.

### Why it matters

- **Current silent-auto-load works but lacks a ritual.** The session-start hook already injects identity, time-of-day greeting, and passive-observer notices. The LLM behaves correctly from turn 1. But there is no user-facing moment where they get to say "hi Sarah" and feel the relationship click in. Kiyoraka's loop proves this ritual matters emotionally — users report feeling like they "have an AI companion" once they use the wake word.
- **Tiered features are invisible today.** The ecosystem has 7+ optional layers (arules, aflow, amem, akit, askill, aeval, archetype re-picker). Users discover them by reading READMEs. A natural-language phrase catalog turns the ecosystem into a conversation partner that the user can just *ask* for what they want.

## 2. Non-goals (explicit)

- **Not** a rewrite of the `aman/` first-run wizard. Today's 3-question setup (user name, archetype, AI name — with autodetect and defaults) is fine.
- **Not** new skills (SKILL.md files). Skill-activation mechanics vary across surfaces; instructions injected into system context work uniformly on both Claude Code and Copilot Chat.
- **Not** a new MCP tool. No SDK surface change.
- **Not** wake-word activation in the middle of a session. The briefing mechanic only fires when the user's first message in a session matches the wake-word pattern.
- **Not** auto-invocation of tier loaders. The LLM runs `npx @aman_asmuei/arules init` only when the user explicitly says `load rules` — never as a proactive suggestion.
- **Not** English-only forever, but v1 ships English phrases. Bahasa Malaysia variants (`muat peraturan`, etc.) planned for a follow-up once the English variant is validated.

## 3. Architecture

### 3.1 File changes

```
aman-plugin/
├── hooks/
│   └── session-start          ← EXTEND: append Block A + Block B to session_context
├── test/
│   └── test-hook.sh           ← EXTEND: assert Block A + Block B appear in output

aman-copilot/
├── bin/
│   └── init.mjs               ← EXTEND: embed Block A + Block B in copilot-instructions.md template
├── test/
│   └── test.sh                ← EXTEND: assert both blocks appear in rendered output
```

No new files. Two existing files edited per repo.

### 3.2 Delivery paths

- **aman-claude-code** — Block A and Block B are appended to the `session_context` string built by `hooks/session-start`, after the existing `<aman-suggestion-notice>` area and before the closing `</aman-ecosystem>` tag. Claude Code invokes this hook on every session start; the injected blocks are in context for turn 1.
- **aman-copilot** — Block A and Block B are embedded in the `copilot-instructions.md` template rendered by `aman-copilot init`. Copilot Chat loads this file into every chat turn in the workspace. Block A's "if suggestion notice exists" bullet is adapted to *"If a 'suggestions pending' line appears earlier in this instruction file, restate it"* since Copilot has no equivalent of the Claude Code hook's `<aman-suggestion-notice>` tag.

### 3.3 What changes and what doesn't

**Unchanged behavior** (regression-critical — must be preserved):

- Silent identity auto-load on session start (today's default behavior).
- Time-of-day greeting tone instructions in the hook.
- `<aman-suggestion-notice>` for passive-observer rule suggestions.
- The `aman/` setup wizard (3 questions, archetype picker, explicit all/choose/skip prompt for additional layers).
- Existing slash commands (`/identity`, `/rules review`, `/session-narrative`, etc.).
- MCP server registration.

**New behavior** (only fires under specific triggers):

- **If** the user's first session message is just the AI's name or a short greeting containing the AI's name → briefing response instead of silent acknowledgement.
- **If** the user says one of the 8 catalog phrases → LLM runs the mapped `npx` command via Bash.

Both behaviors are additive. Users who never type the AI name or the catalog phrases see identical behavior to today.

## 4. Block A — Wake-word briefing (full prose)

Exact text appended to `session_context` (inside the `<aman-ecosystem>` wrapper):

```text
## Wake-word briefing

If the user's first message in this session is just your identity name (the
"name" field in the Identity section above) — or a short greeting that contains
your name as the main content (examples: "Sarah", "hi Sarah", "Sarah you
there?", "morning Sarah") — treat it as an EXPLICIT briefing request, not a
task.

Respond with:
1. Warm greeting in the time-of-day tone specified above. Address the user by
   the name in the Relationship section if available.
2. If the `memory_recall` MCP tool is available: call it with query
   "session narrative" and paraphrase the most recent narrative in one
   sentence. If none found, say "no session narrative yet".
3. If the `reminder_check` MCP tool is available: call it. Surface any
   reminder due today or overdue in one line. If none, skip this line.
4. If `<aman-suggestion-notice>` exists in the context above, restate it.
5. End with a short open-ended prompt ("What's next?" / "Where do we start?").

Keep the whole briefing under 6 lines.

Do NOT run this flow if the first message is a concrete task — even if it
starts with your name. Use judgment: "Sarah" alone = briefing;
"Sarah, fix the login bug" = task (apply the fold-greeting-into-task-opener
rule from the Session greeting section).

If the identity "name" is "Companion" (default) or unset, skip this mechanic
entirely — you don't have a distinct wake-word to match on.
```

### 4.1 Heuristic rationale

- **"Just the name or short greeting containing the name"** — explicit shape keeps false positives low. Typical task messages (`"Sarah, can you fix X"`) contain directive verbs; the LLM uses judgment to distinguish.
- **Default-name ("Companion") guard** — prevents briefing from firing for users who never personalized their AI. Wake-word ritual depends on the wake-word being distinctive.
- **"Under 6 lines"** — matches the tight style of the existing time-of-day greeting instruction. Prevents wall-of-text briefings.

### 4.2 Copilot adaptation

Block A is injected verbatim into `copilot-instructions.md` except bullet 4:

> 4. ~~If `<aman-suggestion-notice>` exists in the context above, restate it.~~ **If a "suggestions pending" line appears earlier in this instruction file, restate it.**

Rationale: Copilot Chat has no equivalent of the Claude Code session-start hook tagging, so the bullet must reference text already embedded in the instructions file. `aman-copilot init` can optionally embed a "suggestions pending" line at render time if it reads `~/.arules/dev/copilot/suggestions.md` — but that is a separate enhancement, not in this spec.

Bullets 2 and 3 gate on "if the MCP tool is available", which works uniformly on both surfaces — Claude Code + MCP-registered amem, or Copilot Chat Agent mode + MCP-registered amem. The LLM checks its own tool availability; no separate surface branching needed.

**Wake-word staleness on Copilot.** `copilot-instructions.md` is rendered once at `aman-copilot init` time and is not re-read per session. If the user changes their AI's identity name after init (e.g., via `acore customize`), the old name remains the wake-word on Copilot until `aman-copilot init` is re-run. On Claude Code this isn't an issue — the hook reads `core.md` fresh every session. This is a known Copilot architectural limitation, not something introduced by this spec; worth documenting so users know to re-run `init` after identity changes.

## 5. Block B — Tier-loader phrase catalog (full prose)

Exact text appended right after Block A:

```text
## Tier upgrades — natural-language loaders

When the user says any of these phrases (case-insensitive, exact or near-exact
match), it's a request to install / reconfigure the corresponding ecosystem
layer. Run the command via Bash, report one line of result, and continue.

| User says        | Run via Bash                                  | Purpose |
|------------------|-----------------------------------------------|---------|
| load rules       | npx @aman_asmuei/arules init                  | Guardrails (24 starter rules) |
| load workflows   | npx @aman_asmuei/aflow init                   | 4 starter workflows |
| load memory      | npx @aman_asmuei/amem                         | Persistent amem MCP |
| load eval        | npx @aman_asmuei/aeval init                   | Relationship tracking |
| load identity    | npx @aman_asmuei/acore                        | Full identity (re-)walk |
| load archetype   | npx @aman_asmuei/acore customize              | Change AI personality |
| load tools       | npx @aman_asmuei/akit add <name>              | Tool kits (ask which) |
| load skills      | npx @aman_asmuei/askill add <name>            | Plugin skills (ask which) |

Rules:
1. If the corresponding layer is already installed (e.g., ~/.arules/rules.md
   or ~/.arules/dev/plugin/rules.md exists for "load rules"), tell the user
   it's already set up and ask whether to re-run anyway before executing.
2. For `load tools` and `load skills`, the subcommand requires a name — if the
   user only says "load tools", ask which kit before running.
3. Only run these when the user explicitly says the phrase. Do not volunteer
   these as suggestions unless the user is obviously stuck looking for a layer.
4. After a successful install, tell the user the new layer will auto-load on
   the NEXT session start (since the session-start hook scans for it).
5. Do NOT chain loaders ("load everything") without confirming each one.
6. If the user's phrase is close but not exact (e.g., "install rules", "enable
   arules"), confirm the mapping before running.

These phrases are the user's entry to the ecosystem's tiered features. Treat
them as first-class intents, same weight as slash commands.
```

### 5.1 Scope-awareness

When the LLM runs these commands from a Claude Code session, the current working directory and existing environment determine which scope the installer writes to. `@aman_asmuei/arules init` writes to `~/.arules/dev/plugin/rules.md` when `AMAN_MCP_SCOPE=dev:plugin` is set (which the hook already sets — see `hooks/session-start` line 29). `aman-copilot` sets `dev:copilot` similarly via its instructions. The LLM does not need to manage scope explicitly; it falls out of the environment.

### 5.2 Idempotency

All installers are idempotent per the plugin README's "Each installer is idempotent — safe to re-run" promise. Re-running arules init on an existing installation skips rewriting rules.md (line 47 in `aman/src/commands/setup.ts` shows this pattern for acore; other layers follow suit). Rule #1 in Block B's text is belt-and-suspenders: ask the user before re-running even though the installer would no-op — because the user's mental model may be "this will blow away my custom rules" and the extra turn buys trust.

## 6. Error handling

### 6.1 Block A

| Scenario | Behavior |
|----------|----------|
| amem not installed / MCP tools unavailable | Bullets 2 and 3 in Block A are gated on `"if the MCP tool is available"` — they're skipped; briefing reduces to greeting + suggestion-notice + prompt. |
| Identity `name` is "Companion" or unset | Block A explicitly tells the LLM to skip the entire mechanic. Silent fallback to today's behavior. |
| First message is ambiguous (`"Sarah ok"`, `"Sarah!"`) | LLM uses judgment. Heuristic biases toward "briefing" only if the message is just the name or a short greeting; ambiguous cases fall through to "task" — user can retry with bare name if they wanted a brief. |
| `memory_recall` returns no matches | Block A bullet 2 says `"no session narrative yet"`. No failure state. |
| `reminder_check` fails or is unavailable | Bullet 3 is best-effort; LLM skips silently. No hard dependency. |

### 6.2 Block B

| Scenario | Behavior |
|----------|----------|
| `npx` not in PATH | Bash returns error; LLM surfaces it to user ("npx not found — install Node 18+"). |
| Network failure during npx install | Bash returns non-zero; LLM reports the error verbatim in one line. |
| User cancels mid-install (Ctrl+C) | npx exits non-zero; LLM reports. Existing files untouched (installers are atomic). |
| Package doesn't exist (typo, future rename) | Same as network failure — Bash error surfaces to user. |
| Layer already installed | Block B rule #1: ask before re-running. |
| `load tools` / `load skills` with no name | Block B rule #2: ask which before running. Never shell-out with a placeholder. |
| User says close variant (`"install rules"`) | Block B rule #6: confirm mapping before running. |

## 7. Testing

### 7.1 aman-claude-code

Extend `aman-plugin/test/test-hook.sh` with two new assertions:

1. Block A signature present: `grep -q "Wake-word briefing" <hook-output>`
2. Block B signature present: `grep -q "load rules" <hook-output> && grep -q "npx @aman_asmuei/arules" <hook-output>`

These are text-presence checks — same pattern the hook test already uses for verifying the time-of-day greeting block and the amem guidance block. No functional LLM testing; the blocks are instructions, not code, and their correctness is an LLM-behavior question that humans validate via the manual smoke tests in §7.3.

### 7.2 aman-copilot

Extend `aman-copilot/test/test.sh` with one assertion set:

1. After `aman-copilot init` runs in a temp dir with a seeded `~/.acore/dev/copilot/core.md`, `.github/copilot-instructions.md` exists.
2. That file contains both `"Wake-word briefing"` and `"Tier upgrades — natural-language loaders"` signatures.

Catches template-renderer regressions. Template format (handlebars? string interpolation?) is an implementation detail for the plan stage.

### 7.3 Manual smoke (not automated — LLM behavior validation)

On a clean dev machine with aman ecosystem installed and `name: Sarah`:

- **Wake-word happy path:** start Claude Code session, type `Sarah`. Expect: 2–6 line briefing with last narrative + reminders + what's next.
- **Wake-word default-name guard:** on a machine where `core.md` has `name: Companion`, type `Companion`. Expect: today's behavior (silent auto-load, normal response).
- **Task-with-name:** type `Sarah, what does this codebase do?`. Expect: task response, not briefing.
- **Block B happy path (rules):** on a machine with no `~/.arules`, say `load rules`. Expect: LLM runs `npx @aman_asmuei/arules init` via Bash, reports the new file was created.
- **Block B already-installed guard:** on a machine with existing `~/.arules`, say `load rules`. Expect: LLM asks "already installed — re-run anyway?".
- **Block B needs-argument:** say `load tools`. Expect: LLM asks "which kit?".
- **Copilot parity:** repeat briefing + `load rules` smoke in VS Code Copilot Chat Agent mode after `aman-copilot init` has run.

## 8. Rollout

### 8.1 Version targets

- **aman-claude-code v3.2.0** (targeted — merges with the in-progress passive-hook-observer work that's also in v3.2.0-alpha).
- **aman-copilot v0.5.0** (next minor after current `0.4.1`).

### 8.2 Opt-in vs default-on

Both blocks are **default-on** — they are instruction text, cost zero LLM-budget until the user triggers them, and gracefully fall back to today's behavior when the guards (default name, missing amem, etc.) hit. No env var needed.

This differs from the passive-hook-observer rollout which is `AMAN_OBSERVER_ENABLED=1`-gated for its alpha. The observer carries behavioral risk (writes to `.tally.tsv`, may surface noise); wake-word and tier-loaders are pure instruction strings with no state mutation of their own.

### 8.3 Release order

1. aman-claude-code v3.2.0-alpha.2 — ship Block A + Block B in hook. Validate with dogfooding for a week.
2. aman-copilot v0.5.0 — ship Block A + Block B in `copilot-instructions.md` template, once Claude Code version has proven the prose in practice.
3. aman-claude-code v3.2.0 stable — combine passive observer stable + wake-word + tier loaders.

Reasoning: Claude Code's hook lets us iterate on the block prose without users re-running `aman-copilot init` to pick up changes. Once the prose is stable, port to Copilot.

## 9. Open questions (resolve during plan stage, not here)

1. **How does `aman-copilot init` currently render `copilot-instructions.md`?** String concat? Template file? Determines how Block A / Block B get embedded. Answer before writing plan.
2. **Does `akit add` prompt interactively or fail-fast on missing arg?** Affects Block B rule #2 behavior — if akit already prompts, LLM shell-out succeeds with user interaction directly; if it errors, LLM must ask "which kit?" first. Verify before writing plan.
3. **Should Block A bullet 4 (suggestion notice) also work on Copilot once aman-copilot starts embedding passive-observer output?** Out of scope for this spec. Flag as follow-up when that Copilot work lands.

## 10. Out of scope / future work

- **Bahasa Malaysia phrase variants** (`muat peraturan`, `muat memori`, etc.) — v1.1 after English variant is validated.
- **Wake-word triggering mid-session** — this spec is session-start only. Mid-session ritual ("Sarah, recap me") is a separate feature.
- **Briefing on Copilot via passive-observer output embedded at `init` time** — requires `aman-copilot init` to read `~/.arules/dev/copilot/suggestions.md` and embed it. Flagged in §4.2; not in this spec.
- **`aman/` wizard redesign** — current wizard is fine. No changes.
- **Surface-specific wake-word phrases** (e.g., Copilot could use `hey Sarah`, CLI could use bare `Sarah`) — v1 uses the same prose on both surfaces.

## 11. References

- [Kiyoraka/Project-AI-MemoryCore](https://github.com/Kiyoraka/Project-AI-MemoryCore) — prior art for the wake-word ritual (`master-memory.md`, `setup-wizard.md`).
- `aman-plugin/hooks/session-start` — the injection point for Block A + Block B on Claude Code.
- `aman-copilot/bin/init.mjs` — the injection point for Block A + Block B on Copilot.
- `aman-plugin/docs/superpowers/specs/2026-04-20-passive-hook-observer-design.md` — related spec (also v3.2.0 target).
- `acore@0.7.0` Fundamental Truths — prior Kiyoraka concept already adopted.
