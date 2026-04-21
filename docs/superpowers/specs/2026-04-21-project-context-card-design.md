# Project Context Card — Design

**Status:** Design approved, pending implementation plan
**Date:** 2026-04-21
**Scope:** `aman-claude-code` plugin + `aman-copilot` (parity)
**Related:** Part 1 of 3 in the "multi-project support" roadmap (see §10 Out of scope).

## 1. Purpose

Give aman per-project awareness with zero new concepts — by wiring up infrastructure that already exists but is currently unread.

When a developer runs `npx @aman_asmuei/aman@latest` in a repo with a detectable stack, the wizard ALREADY writes `./.acore/context.md` — a project-local markdown card with Stack, Domain, Focus, Session, Active topics, Recent decisions, and Project Patterns. Today, nothing reads that file. This spec plumbs it in:

- On Claude Code, the `SessionStart` hook reads `./.acore/context.md` (resolved from git toplevel) and appends it to the injected context.
- On Copilot, `aman-copilot init` reads the same file at render time and embeds it into `.github/copilot-instructions.md`.

Net effect: when you `cd` into a project and start a session, the AI knows it is in that project — no shell dance, no profile switcher, no new CLI.

### Why it matters

Most devs juggle 3-10 active repos in a given week. Today, when a user switches from their Go backend to their React frontend, aman's AI has no idea they switched. Same identity, same memory pool, same generic advice. The project card closes the frame gap: *you are in myapp-frontend, Node/TypeScript, last session you were wiring up the checkout flow* — before the user has to re-orient the AI.

This is Path 1 of a 3-part roadmap. Path 2 (per-project memory tagging in amem) and Path 3 (first-class project registry) are deferred — see §10.

## 2. Non-goals (explicit)

- **Not** memory partitioning. `amem` remains a single pool. A memory stored in project A still surfaces in project B via `memory_recall`. That is Path 2 territory, deferred.
- **Not** a per-project identity swap. `~/.acore/dev/plugin/core.md` remains the source of truth for who the AI is. Project context layers on top; it does not replace.
- **Not** a per-project rules file. `./.arules/rules.md` is an obvious next step but out of scope here. Global rules still apply.
- **Not** auto-generation on first visit. The card is only loaded if it exists. If `aman setup` was never run in this repo, nothing happens — no creation, no prompts, no error. Silent fallback to today's behavior.
- **Not** a context-editing UX. Users maintain `./.acore/context.md` by hand or via future tooling — this spec only adds the reader side.
- **Not** git-required. If the user is outside a git repo, we fall back to `$PWD/.acore/context.md` (no upward traversal).

## 3. Architecture

### 3.1 File changes

```
aman-plugin/
├── hooks/
│   └── session-start          ← EXTEND: read project context card if present
├── test/
│   └── test-hook.sh           ← EXTEND: 2 new test groups (card present / card absent)

aman-copilot/
├── bin/
│   └── init.mjs               ← EXTEND: resolve local context.md, embed as section
├── test/
│   └── test.sh                ← EXTEND: test group verifying embed
```

No new files. Two existing files edited per repo.

### 3.2 Path resolution

The project root is the anchor for the context card. Resolution order:

1. `git rev-parse --show-toplevel` — if inside a git worktree, use the repo root.
2. Fallback: `$PWD` (or `process.cwd()` in Node) — if not in a git repo, use the current working directory.

Then check `<project-root>/.acore/context.md` — load if it exists.

No upward filesystem traversal beyond git toplevel. If the user is in `myproject/frontend/` without git, the card at `myproject/.acore/context.md` will not be found — they would need to either `cd` up or `git init` the project. This keeps the resolver predictable and avoids surprise loads from ancestor directories.

**Shell invocation policy.** On the Copilot side, all `git` invocation MUST use `child_process.execFile` (no shell, argv-separated arguments). `child_process.exec` and `execSync` are forbidden for this work — they spawn a shell and create an injection surface. The command is a hardcoded literal today, but using `execFile` future-proofs against later refactors that may interpolate variables. On the plugin side, the hook is bash and invokes `git` directly via the shell; arguments are hardcoded literals so injection is not a concern there.

### 3.3 Composition order in hook output

The injected `<aman-ecosystem>` context in Claude Code builds incrementally:

```
1. Identity (acore/core.md)               — existing
2. Tools (akit/kit.md)                    — existing
3. Workflows (aflow/flow.md)              — existing
4. Rules (arules/rules.md)                — existing
5. Skills (askill/skills.md)              — existing
6. amem guidance                          — existing
7. Passive-observer suggestion notice     — existing
8. Wake-word briefing                     — existing (v3.2.0-alpha.2)
9. Tier-loader phrase catalog             — existing (v3.2.0-alpha.2)
10. Project context card (NEW)            ← inserted here
```

Project card comes after tier-loaders so that "load tools" / "load skills" advice is already in context when the LLM starts reasoning about the current project. Also keeps the project-specific frame closest to the user's first message, which is where it gains the most attention-weight in the LLM.

## 4. Implementation — aman-plugin hook

### 4.1 Exact bash to insert

Inside `hooks/session-start`, AFTER the existing `if [ -n "$context_parts" ]; then ... fi` block (which appends wake-word + tier-loader), and BEFORE the `# Build the context message` comment (around line 188 in the post-v3.2.0-alpha.2 file):

```bash
# Project context card — load $PROJECT_ROOT/.acore/context.md if present.
# Project root = git toplevel if in a git repo, else $PWD.
project_root=""
if command -v git >/dev/null 2>&1; then
    project_root=$(git rev-parse --show-toplevel 2>/dev/null || true)
fi
if [ -z "$project_root" ]; then
    project_root="$PWD"
fi
project_context_path="${project_root}/.acore/context.md"
if [ -f "$project_context_path" ] && [ -n "$context_parts" ]; then
    project_context=$(cat "$project_context_path")
    project_context_block="## Project context (current working directory)

The following is the project-specific context card for the current project root (\`${project_root}\`). This supplements your global identity above with project-local stack, domain, active topics, and recent decisions. Prefer project-local facts over generic assumptions when they conflict.

---

${project_context}"
    context_parts="${context_parts}\n\n---\n\n${project_context_block}"
fi
```

### 4.2 Gating rationale

- **`context_parts` non-empty guard** — same pattern as wake-word/tier-loaders. If no ecosystem is configured at all, the "No aman ecosystem configured" fallback fires instead of noisy project context. Preserves existing UX for unconfigured users.
- **No `AMAN_PROJECT_CARD_ENABLED` env flag** — unlike the passive observer, this is pure read-if-present logic with no state mutation and no behavioral risk. Default-on.
- **Silent on missing file** — zero noise when the card does not exist. Explicit "no project card found" messaging would be clutter for every session in every project that has not opted in.
- **`project_root` echoed back** in the block header so the LLM can say "you are in myproject" without guessing. Visible path disambiguation for multi-repo users who `cd` around.

### 4.3 Interaction with Block A (wake-word briefing)

Block A (wake-word briefing from v3.2.0-alpha.2) tells the LLM to do a session brief when the user's first message is just the AI name. With the project card now in context, the brief naturally can reference the project. Example expected behavior:

```
You: Sarah

Sarah: Morning, Aman — you are in myapp-frontend (Node/TypeScript). Last
       session here we wired up the checkout flow. 2 reminders due today.
       Pending rule suggestion. What's next?
```

No change to Block A's text is required. The LLM folds the project context in naturally because it is in the system context. If users want an explicit instruction, a future spec can tune Block A bullet 1 to say "address the project if the project context card is present" — prose change only, no hook logic change.

## 5. Implementation — aman-copilot init

### 5.1 Resolver in Node (execFile, not exec)

Inside `bin/init.mjs`, add:

```javascript
import { execFile } from "node:child_process";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

async function resolveProjectContext() {
  let projectRoot = process.cwd();
  try {
    const { stdout } = await execFileAsync("git", ["rev-parse", "--show-toplevel"]);
    const gitRoot = stdout.trim();
    if (gitRoot) projectRoot = gitRoot;
  } catch {
    // not a git repo or git binary missing — fall back to cwd
  }
  const candidatePath = path.join(projectRoot, ".acore", "context.md");
  try {
    const content = await fs.readFile(candidatePath, "utf-8");
    return { path: candidatePath, root: projectRoot, content };
  } catch {
    return null;
  }
}
```

**Why `execFile` and not `exec`/`execSync`:** `exec` spawns a shell and is vulnerable to command injection if any argument is ever interpolated from user input. Today the command is a hardcoded literal, but the codebase has a standing rule to use `execFile` or equivalent argv-passing forms so a future edit that adds interpolation cannot introduce a vulnerability. This is a low-cost future-proofing discipline, not a response to a current threat.

### 5.2 Integration into buildInstructions()

`buildInstructions()` currently receives `{ core, rules, amemInstalled }`. Extend to `{ core, rules, amemInstalled, projectContext }` where `projectContext` is the return of `resolveProjectContext()` or `null`.

Where to inject in the sections array: AFTER the `## Guardrails snapshot (arules)` block (or after identity snapshot if no rules), BEFORE the `## Live tools available` tail:

```javascript
if (projectContext) {
  sections.push(
    "## Project context (current working directory)",
    "",
    `The following is the project-specific context card for the current project root (\`${projectContext.root}\`). This supplements the global identity above with project-local stack, domain, active topics, and recent decisions. Prefer project-local facts over generic assumptions when they conflict.`,
    "",
    "---",
    "",
    projectContext.content.trim(),
    "",
    "---",
    "",
  );
}
```

### 5.3 CLI output

Add a log line in `main()` so users see the card was picked up:

```javascript
if (projectContext) {
  console.log(`  project  ${projectContext.path}`);
}
```

If no card is found, the existing output is unchanged — no confusion for users who do not have one.

## 6. Error handling

| Scenario | Plugin hook | Copilot init |
|---|---|---|
| Not in a git repo | Falls through to `$PWD/.acore/context.md`. If present, loaded. If not, silent. | Same — `execFile` throws, caught; falls back to `process.cwd()`. |
| `git` binary missing | `command -v git` check guards the hook; falls through to `$PWD`. | `execFile` throws ENOENT, caught, falls back to `process.cwd()`. |
| `.acore/context.md` missing at resolved root | Silent skip. No warning, no failure. | Silent skip. `console.log` line omitted. |
| `.acore/context.md` unreadable (permissions) | `cat` fails → `project_context` is empty → block is appended with empty body. Edge case; acceptable today, revisit if it bites. | `fs.readFile` throws, caught, returns `null` — treated as missing. |
| Context card is very large (>100KB) | Loaded verbatim. No size limit today. If the user has a bloated card, it inflates every session's context injection. Monitor in practice; cap at a future iteration if needed. | Same — embedded verbatim. |
| Context card contains secrets | Loaded verbatim. Same risk as `~/.acore/core.md` today — user is responsible for what they write to identity files. No auto-redaction. | Same. |

## 7. Testing

### 7.1 aman-plugin — test/test-hook.sh

Two new test groups.

**Test group: Project context card appears when present.**

```bash
# ---------- Test N: Project context card loaded when .acore/context.md exists ----------
echo ""
echo "Test N: Project context card present when file exists"
TMPDIR_PC=$(mktemp -d)
mkdir -p "$TMPDIR_PC/.acore/dev/plugin"
echo "name: Sarah" > "$TMPDIR_PC/.acore/dev/plugin/core.md"
# Simulate a project dir with a context card
PROJECT_DIR="$TMPDIR_PC/myproject"
mkdir -p "$PROJECT_DIR/.acore"
cat > "$PROJECT_DIR/.acore/context.md" <<EOF
## Work
- Stack: Node/TypeScript
- Domain: frontend

## Session
- Last updated: 2026-04-21
- Resume: wiring checkout flow
EOF

# Run hook from project dir so PWD=PROJECT_DIR. No git repo, so fallback to PWD.
OUTPUT=$(cd "$PROJECT_DIR" && HOME="$TMPDIR_PC" bash "$HOOK_PATH" 2>&1)
CONTEXT=$(echo "$OUTPUT" | jq -r '.additional_context')

if echo "$CONTEXT" | grep -q "Project context (current working directory)"; then
  pass "Contains 'Project context' heading when card exists"
else
  fail "Missing 'Project context' heading"
fi

if echo "$CONTEXT" | grep -q "Stack: Node/TypeScript"; then
  pass "Contains project card body (Stack line)"
else
  fail "Missing project card body"
fi

if echo "$CONTEXT" | grep -q "wiring checkout flow"; then
  pass "Contains project-specific session text"
else
  fail "Missing project-specific session text"
fi

rm -rf "$TMPDIR_PC" 2>/dev/null || true
```

**Test group: Project context card absent when file does not exist.**

```bash
# ---------- Test N+1: Project context card absent when no .acore/context.md ----------
echo ""
echo "Test N+1: Project context card absent when no file"
TMPDIR_NC=$(mktemp -d)
mkdir -p "$TMPDIR_NC/.acore/dev/plugin"
echo "name: Sarah" > "$TMPDIR_NC/.acore/dev/plugin/core.md"
EMPTY_PROJECT="$TMPDIR_NC/empty"
mkdir -p "$EMPTY_PROJECT"

OUTPUT=$(cd "$EMPTY_PROJECT" && HOME="$TMPDIR_NC" bash "$HOOK_PATH" 2>&1)
CONTEXT=$(echo "$OUTPUT" | jq -r '.additional_context')

if echo "$CONTEXT" | grep -q "Project context (current working directory)"; then
  fail "Project card block appeared when no file exists"
else
  pass "Project card block correctly absent when no file exists"
fi

rm -rf "$TMPDIR_NC" 2>/dev/null || true
```

### 7.2 aman-copilot — test/test.sh

One new test group.

```bash
# ---------- Test group N: Project context card embedded in copilot-instructions.md ----------
echo ""
echo "Test group N: Project context card embedded in copilot-instructions.md"

TMP_PC=$(make_sandbox_home "dev/copilot")
cleanup_dirs+=("$TMP_PC")

PROJECT_DIR="$TMP_PC/myproject"
mkdir -p "$PROJECT_DIR/.acore"
cat > "$PROJECT_DIR/.acore/context.md" <<EOF
## Work
- Stack: Node/TypeScript
- Domain: frontend

## Session
- Last updated: 2026-04-21
- Resume: checkout flow work
EOF

cd "$PROJECT_DIR"
HOME="$TMP_PC" node "$INIT" >/dev/null 2>&1

INSTRUCTIONS_FILE="$PROJECT_DIR/.github/copilot-instructions.md"

if [ -f "$INSTRUCTIONS_FILE" ]; then
  if grep -q "Project context (current working directory)" "$INSTRUCTIONS_FILE"; then
    pass "Contains 'Project context' heading"
  else
    fail "Missing 'Project context' heading"
  fi

  if grep -q "Stack: Node/TypeScript" "$INSTRUCTIONS_FILE"; then
    pass "Contains project card body"
  else
    fail "Missing project card body"
  fi

  if grep -q "checkout flow work" "$INSTRUCTIONS_FILE"; then
    pass "Contains session text from card"
  else
    fail "Missing session text"
  fi
else
  fail "copilot-instructions.md not rendered"
fi
```

### 7.3 Manual smoke (LLM-behavioral)

After shipping, verify on a real dev machine:

1. **Plugin happy path:** `cd` into an existing project with `.acore/context.md` written by prior `aman setup`; start a Claude Code session; ask "where are we?" — expect Claude to reference the project's stack/domain.
2. **Plugin wake-word × project:** in same project, first message = AI name. Expect briefing to mention the project explicitly.
3. **Plugin empty fallback:** `cd /tmp && mkdir empty && cd empty`; start session. Expect no project block, no errors, normal wake-word/tier-loader behavior.
4. **Copilot happy path:** same project; run `aman-copilot init`; open Copilot Chat in Agent mode; ask "what project am I in?" — expect Copilot to reference the project.
5. **Copilot re-render freshness:** change `./.acore/context.md` contents; re-run `aman-copilot init`; verify the new content appears.

## 8. Rollout

### 8.1 Version targets

- **aman-claude-code**: `3.2.0-alpha.2` → `3.2.0-alpha.3`. Still alpha; v3.2.0 stable is pending observer stabilization.
- **aman-copilot**: `0.5.0` → `0.6.0`. Minor bump — additive new rendered section.

### 8.2 Default-on

Both blocks are default-on. Additive, silent when no card exists, no env flag. Mirrors the wake-word/tier-loader rollout pattern from v3.2.0-alpha.2.

### 8.3 Release order

1. aman-plugin `v3.2.0-alpha.3` first (hook change, lower blast radius — no npm publish).
2. aman-copilot `v0.6.0` second (triggers CI/CD → npm publish `@aman_asmuei/aman-copilot@0.6.0` on `latest` via `release.yml`).

Same pattern as last ship.

## 9. Open questions

1. **Should we auto-call `aman here` on first session without a card?** Out of scope — would need a new CLI command. Flag as Path 1.5 or a follow-up.
2. **Multi-level card composition?** E.g., `workspace/.acore/context.md` (monorepo-wide) + `workspace/service-a/.acore/context.md` (service-specific). Deferred — today's resolver is single-file.
3. **Cap card size?** No limit today. Monitor; add a warning + truncation at ~10KB if bloat becomes a problem.

## 10. Out of scope / future work

- **Path 2 — Memory tagging by project.** Tag each `memory_store` with a project identifier (git remote URL hash or pwd hash). `memory_recall` boosts same-project matches. Needs amem schema migration. Separate spec.
- **Path 3 — First-class project registry.** `aman project list` / `aman project switch`. Explicit profile UX. Defer until Path 1+2 have a week of real use.
- **Per-project rules (`./.arules/rules.md`).** Obvious extension, same resolver pattern. Separate spec.
- **Project-aware greeting in wake-word briefing.** Block A currently has generic bullets; a future tune could say "greet with project name if project card is present."
- **`aman here` / `aman init project`** — zero-friction CLI to write a project card without running the full setup wizard. Frequently asked UX but out of scope; users can hand-write `./.acore/context.md` or re-run `aman setup` in the project today.

## 11. References

- Existing writer: `aman/src/commands/setup.ts` lines ~112-122 (writes `./.acore/context.md` when stack is detected).
- Existing hook: `aman-plugin/hooks/session-start` (extends in this spec).
- Existing copilot renderer: `aman-copilot/bin/init.mjs` `buildInstructions()` (extends in this spec).
- Prior ship: `aman-plugin/docs/superpowers/specs/2026-04-21-wake-word-and-tier-loaders-design.md` — same pattern, different scope.
