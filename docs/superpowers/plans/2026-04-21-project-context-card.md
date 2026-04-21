# Project Context Card Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Wire up `$PROJECT_ROOT/.acore/context.md` — a per-project context file that already gets written by `aman setup` but has never been read — so both the Claude Code session-start hook and the Copilot `init` renderer pick it up and inject it into the LLM's system context.

**Architecture:** Two repos edited, one responsibility each: plugin reads at hook time; copilot embeds at `init` time. Project root resolution is git-toplevel with `$PWD` fallback. Copilot's git call uses `execFile` (argv-separated, no shell spawned) per the codebase's shell-injection-avoidance rule.

**Tech stack:**
- `aman-plugin`: bash (`hooks/session-start`) + bash test (`test/test-hook.sh`).
- `aman-copilot`: Node 18+ ESM (`bin/init.mjs`) using `node:child_process.execFile` + `node:util.promisify` + `fs.promises` + bash test (`test/test.sh`).

**Repos:**
- `aman-plugin` at `/Users/aman-asmuei/project-aman/aman-plugin`, branch `feat/project-context-card` (created from `main` at HEAD).
- `aman-copilot` at `/Users/aman-asmuei/project-aman/aman-copilot`, branch `feat/project-context-card` (created from `master` at HEAD).

**Spec:** `aman-plugin/docs/superpowers/specs/2026-04-21-project-context-card-design.md`

---

## File Structure

| Repo | File | Action | Responsibility |
|---|---|---|---|
| `aman-plugin` | `hooks/session-start` | Modify | Resolve `project_root` (git toplevel, `$PWD` fallback). If `$project_root/.acore/context.md` exists AND `$context_parts` is non-empty, append a "Project context" block. |
| `aman-plugin` | `test/test-hook.sh` | Modify | Two new test groups: card-present (assert block + body), card-absent (assert block NOT in output). |
| `aman-copilot` | `bin/init.mjs` | Modify | Add `resolveProjectContext()` using `execFile` (argv-separated) for git and `fs.readFile` for the card. Thread `projectContext` through `buildInstructions()` and emit a "Project context" sections block when present. Log detected path in the CLI tail summary. |
| `aman-copilot` | `test/test.sh` | Modify | One new test group: set up a `myproject/.acore/context.md`, `cd` in, run `init`, assert the rendered `copilot-instructions.md` contains the expected heading and body. |

No new files. Four existing files modified across two repos.

---

## Phase A — aman-plugin

All tasks run in `/Users/aman-asmuei/project-aman/aman-plugin/.worktrees/feat-project-context-card`.

### Task A1: Failing test + implementation — card present case

**Files:**
- Modify: `test/test-hook.sh` (append at end, BEFORE final summary/exit section)
- Modify: `hooks/session-start` (insert block before `# Build the context message` comment)

- [ ] **Step 1: Find next test number**

```bash
grep -cE '^# ---------- Test ' test/test-hook.sh
```

Use that count + 1 as `N`.

- [ ] **Step 2: Append failing test**

```bash
# ---------- Test N: Project context card loaded when .acore/context.md exists ----------
echo ""
echo "Test N: Project context card present when file exists"
TMPDIR_PC=$(mktemp -d)
mkdir -p "$TMPDIR_PC/.acore/dev/plugin"
echo "name: Sarah" > "$TMPDIR_PC/.acore/dev/plugin/core.md"
PROJECT_DIR="$TMPDIR_PC/myproject"
mkdir -p "$PROJECT_DIR/.acore"
cat > "$PROJECT_DIR/.acore/context.md" <<'PCEOF'
## Work
- Stack: Node/TypeScript
- Domain: frontend

## Session
- Last updated: 2026-04-21
- Resume: wiring checkout flow
PCEOF

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

- [ ] **Step 3: Verify test fails**

```bash
cd /Users/aman-asmuei/project-aman/aman-plugin/.worktrees/feat-project-context-card && bash test/test-hook.sh
```

**Expected:** 3 new assertions FAIL; all 29 pre-existing tests PASS. Total: `29 passed, 3 failed, 32 total`.

- [ ] **Step 4: Insert hook block**

Edit `hooks/session-start`. Find `# Build the context message` (around line 188 post-v3.2.0-alpha.2). Immediately BEFORE that line, insert:

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
    project_context_block=$(cat <<PCEND
## Project context (current working directory)

The following is the project-specific context card for the current project root (\`${project_root}\`). This supplements your global identity above with project-local stack, domain, active topics, and recent decisions. Prefer project-local facts over generic assumptions when they conflict.

---

${project_context}
PCEND
)
    context_parts="${context_parts}\n\n---\n\n${project_context_block}"
fi
```

**Gotcha — heredoc choice:** The `PCEND` delimiter is UNQUOTED so `${project_root}` and `${project_context}` expand inside. If you ever need to suppress expansion, quote the delimiter as `'PCEND'`. For this block we WANT expansion.

**Gotcha — backticks around path:** The `\`${project_root}\`` inside the heredoc uses escaped backticks so they render as literal backticks in the output (for Markdown inline code formatting), not as command substitution. Preserve both escapes.

- [ ] **Step 5: Run tests — all should pass**

```bash
bash test/test-hook.sh
```

**Expected:** `32 passed, 0 failed, 32 total`.

- [ ] **Step 6: Commit**

```bash
cd /Users/aman-asmuei/project-aman/aman-plugin/.worktrees/feat-project-context-card
git add hooks/session-start test/test-hook.sh
git commit -m "feat(hook): wire project context card from \$PROJECT_ROOT/.acore/context.md

Session-start hook resolves project root via git toplevel (falling
back to \$PWD) and, if \$PROJECT_ROOT/.acore/context.md exists,
appends it as a Project context block to the injected system
context. Silent no-op when the card is absent. Supplements global
identity without replacing it. Part 1 of the multi-project roadmap
— see docs/superpowers/specs/2026-04-21-project-context-card-design.md."
```

---

### Task A2: Regression test — card absent case

- [ ] **Step 1: Append test**

Next sequential test number. Append AFTER Task A1's test group, still BEFORE the final summary/exit section:

```bash
# ---------- Test N: Project context card absent when no .acore/context.md ----------
echo ""
echo "Test N: Project context card absent when no file"
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

- [ ] **Step 2: Run full suite — all should pass**

The guard `[ -f "$project_context_path" ]` from Task A1 already handles this case. This test verifies that.

```bash
bash test/test-hook.sh
```

**Expected:** `33 passed, 0 failed, 33 total`.

- [ ] **Step 3: Commit**

```bash
git add test/test-hook.sh
git commit -m "test(hook): verify project card absent when no file exists

Regression test: project context block must not appear if
\$PROJECT_ROOT/.acore/context.md does not exist. Today's guard
(file-existence check) passes."
```

---

## Phase B — aman-copilot

All tasks run in `/Users/aman-asmuei/project-aman/aman-copilot/.worktrees/feat-project-context-card`.

### Task B1: Embed project context card

**Files:**
- Modify: `bin/init.mjs` — add imports, resolver, thread through `buildInstructions()`, emit block, log
- Modify: `test/test.sh` — one new test group

- [ ] **Step 1: Find next test group number**

```bash
grep -cE '^# ---------- Test group ' test/test.sh
```

Use count + 1 as `N`.

- [ ] **Step 2: Append failing test**

```bash
# ---------- Test group N: Project context card embedded in copilot-instructions.md ----------
echo ""
echo "Test group N: Project context card embedded in copilot-instructions.md"

TMP_PC=$(make_sandbox_home "dev/copilot")
cleanup_dirs+=("$TMP_PC")

PROJECT_DIR="$TMP_PC/myproject"
mkdir -p "$PROJECT_DIR/.acore"
cat > "$PROJECT_DIR/.acore/context.md" <<'PCEOF'
## Work
- Stack: Node/TypeScript
- Domain: frontend

## Session
- Last updated: 2026-04-21
- Resume: checkout flow work
PCEOF

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

- [ ] **Step 3: Verify test fails**

```bash
cd /Users/aman-asmuei/project-aman/aman-copilot/.worktrees/feat-project-context-card && bash test/test.sh
```

**Expected:** 3 new assertions FAIL; all 70 pre-existing tests PASS.

- [ ] **Step 4: Add imports and resolver to init.mjs**

Open `bin/init.mjs`. Below the existing imports at the top (around line 19-21), add:

```javascript
import { execFile } from "node:child_process";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);
```

If any of those names are already imported in the file (e.g., `promisify`), reuse the existing import — do not duplicate.

Then place a helper near `resolveLayer` (around line 29):

```javascript
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

**Why `execFile` / argv-separated invocation:** this form passes the command and arguments as distinct parameters — no shell is spawned, no word splitting happens on the command string. Even though today's call uses only hardcoded string literals, this pattern prevents future edits (that might interpolate a variable) from introducing a shell-injection surface.

- [ ] **Step 5: Thread `projectContext` through `buildInstructions()`**

Find the signature around line 62:

```javascript
function buildInstructions({ core, rules, amemInstalled }) {
```

Change to:

```javascript
function buildInstructions({ core, rules, amemInstalled, projectContext }) {
```

- [ ] **Step 6: Emit the project context block inside `buildInstructions()`**

Find the `sections.push("## Guardrails snapshot (arules)", ...)` block (the conditional one wrapped in `if (rules) { ... }`). AFTER that `if (rules)` block closes, and BEFORE the `sections.push("## Live tools available", ...)` line, insert:

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

**Gotcha — escaped backticks in template literal:** the outer delimiter is a backtick (template literal), so the `\`${projectContext.root}\`` renders as a literal backtick-wrapped path in the output (for Markdown inline code). Keep both backslashes.

- [ ] **Step 7: Call resolver and pass into main()**

Find the `async function main()` around line 322. Add this line near the top of the function body (after the existing `corePath` / `rulesPath` resolution):

```javascript
  const projectContext = await resolveProjectContext();
```

Update the `buildInstructions(...)` call:

```javascript
  const content = buildInstructions({ core, rules, amemInstalled, projectContext });
```

In the "Layers included" summary block at the end of `main()`, add AFTER the existing `amemInstalled` line:

```javascript
  if (projectContext) console.log(`  project ${projectContext.path}`);
```

- [ ] **Step 8: Run tests**

```bash
bash test/test.sh
```

**Expected:** `73 passed, 0 failed, 73 total`.

- [ ] **Step 9: Hermetic inspect**

```bash
cd /Users/aman-asmuei/project-aman/aman-copilot/.worktrees/feat-project-context-card && \
  TMPINSPECT=$(mktemp -d) && \
  mkdir -p "$TMPINSPECT/.acore/dev/copilot" && \
  echo "name: TestBot" > "$TMPINSPECT/.acore/dev/copilot/core.md" && \
  mkdir -p "$TMPINSPECT/myproject/.acore" && \
  printf "## Work\n- Stack: Python\n- Domain: data pipeline\n\n## Session\n- Last updated: 2026-04-21\n- Resume: fixing ingest bug\n" > "$TMPINSPECT/myproject/.acore/context.md" && \
  cd "$TMPINSPECT/myproject" && HOME="$TMPINSPECT" node /Users/aman-asmuei/project-aman/aman-copilot/.worktrees/feat-project-context-card/bin/init.mjs && \
  echo "---RENDERED---" && \
  grep -A 15 "Project context" "$TMPINSPECT/myproject/.github/copilot-instructions.md" && \
  rm -rf "$TMPINSPECT"
```

**Expected:** "Project context (current working directory)" heading followed by the description and the card body. If you see literal `${projectContext.root}` in the output, the template literal escaping is wrong — fix and re-run.

- [ ] **Step 10: Commit**

```bash
cd /Users/aman-asmuei/project-aman/aman-copilot/.worktrees/feat-project-context-card
git add bin/init.mjs test/test.sh
git commit -m "feat(init): embed project context card in copilot-instructions.md

aman-copilot init resolves project root (git toplevel, falling back
to process.cwd()) and embeds \$PROJECT_ROOT/.acore/context.md as a
'Project context' section if present. Uses execFile (argv-separated,
no shell spawned) for the git invocation. Silent no-op when no card
is present. Parity with aman-claude-code v3.2.0-alpha.3 hook
injection."
```

---

## Phase C — Version bumps

### Task C1: aman-plugin → 3.2.0-alpha.3

In the plugin worktree:

- [ ] **Step 1: Edit `.claude-plugin/plugin.json`** — change `"version": "3.2.0-alpha.2"` to `"version": "3.2.0-alpha.3"`.

- [ ] **Step 2: Edit `CHANGELOG.md`** — add above the `## 3.2.0-alpha.2` entry:

```markdown
## 3.2.0-alpha.3 — 2026-04-21

### Added
- **Project context card**: the session-start hook now reads
  `$PROJECT_ROOT/.acore/context.md` (where `$PROJECT_ROOT` is the
  current git toplevel, or `$PWD` if outside a git repo) and injects
  it as a "Project context" block into the Claude Code session
  context. Supplements global identity with project-local stack,
  domain, active topics, and recent decisions.

The card is silently skipped when no file exists — no changes to
behavior for projects that have not run `aman setup`. This is Part 1
of 3 in the multi-project roadmap; per-project memory tagging (Path 2)
and first-class project registry (Path 3) are deferred to future
releases.

See `docs/superpowers/specs/2026-04-21-project-context-card-design.md`.
```

- [ ] **Step 3: Commit**

```bash
git add .claude-plugin/plugin.json CHANGELOG.md
git commit -m "chore: bump to 3.2.0-alpha.3 — project context card"
```

### Task C2: aman-copilot → 0.6.0

In the copilot worktree:

- [ ] **Step 1: Edit `package.json`** — change `"version": "0.5.0"` to `"version": "0.6.0"`.

- [ ] **Step 2: Edit `CHANGELOG.md`** — add above `## 0.5.0`:

```markdown
## 0.6.0 — 2026-04-21

### Added
- **Project context card**: `aman-copilot init` now resolves the
  current project root (git toplevel or `process.cwd()`) and embeds
  `$PROJECT_ROOT/.acore/context.md` as a "Project context" section in
  the rendered `.github/copilot-instructions.md`. Copilot Chat picks
  up project-local stack, domain, active topics, and recent decisions
  on every chat turn in that workspace.
- Uses `execFile` (argv-separated invocation, no shell spawned) for
  the `git rev-parse` call. No injection surface.

Re-run `npx @aman_asmuei/aman-copilot init` inside a project to pick
up the new embed. Silent no-op when no card is present.

See the design spec in the sibling repo at
`aman-plugin/docs/superpowers/specs/2026-04-21-project-context-card-design.md`.
```

- [ ] **Step 3: Commit**

```bash
cd /Users/aman-asmuei/project-aman/aman-copilot/.worktrees/feat-project-context-card
git add package.json CHANGELOG.md
git commit -m "chore: bump to 0.6.0 — project context card"
```

---

## Phase D — Merge, tag, push, publish

The orchestrator (not the subagents) handles these.

1. Merge plugin feature branch into `main` with `--no-ff`. Verify tests pass.
2. Merge copilot feature branch into `master` with `--no-ff`. Verify tests pass.
3. Push both to origin (non-tag refs).
4. Tag plugin `v3.2.0-alpha.3` (annotated).
5. Tag copilot `v0.6.0` (annotated).
6. Push plugin tag — marketplace only, no CI publish.
7. Push copilot tag — triggers `release.yml`: test → verify-version → `npm publish --provenance` to `@aman_asmuei/aman-copilot@0.6.0` on `latest` → GitHub Release.
8. Watch the copilot CI run until green.

---

## Phase E — Readme updates (after publish)

Surgical additions — same pattern as the wake-word/tier-loader documentation.

**aman-plugin README:** add a `### Project context` subsection under `## Features`, AFTER `### Tier-loader phrases`. Short paragraph + 4-line example of what the card looks like, note that it is auto-written by `aman setup` when a stack is detected.

**aman-copilot README:** parity. Note the re-run reminder (`aman-copilot init` must be re-run when the card changes).

Commit locally, do NOT push without explicit user approval (per the user's established cadence for README changes).

---

## Success criteria

- [ ] Phase A: 33/33 tests pass in aman-plugin.
- [ ] Phase B: 73/73 tests pass in aman-copilot.
- [ ] Both feature branches merged into `main`/`master` with `--no-ff`.
- [ ] `v3.2.0-alpha.3` tag on plugin `main`.
- [ ] `v0.6.0` tag on copilot `master`; CI pipeline green; `npm view @aman_asmuei/aman-copilot version` returns `0.6.0`.
- [ ] READMEs updated and committed (push held for user review).
- [ ] No changes to `aman/` or any other ecosystem package.
- [ ] No Co-Authored-By Claude trailer in any commit.
