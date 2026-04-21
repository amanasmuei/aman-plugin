# Tiered Session Manifest Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure `hooks/session-start` to reduce always-injected prose by ~60%, tighten the wake-word Boot Protocol conditional with explicit two-sided gating (positive + negative examples), and preserve all 45 existing keyword test assertions.

**Architecture:** Surgical bash-hook refactor of three embedded prose blocks (`wake_word_block`, `tier_loader_block`, session envelope containing greeting + temporal modes + expression style). Compress prose aggressively while keeping every keyword the existing tests grep for. Introduce two-sided conditional for wake-word detection — positive examples specifying when to FIRE plus explicit negative examples specifying when NOT to fire — to avoid alpha.8's regression where Step 0 tool calls fired on every first message. Detection remains prose-gated, but execution once gated is deterministic (explicit ordered tool-call sequence). Add new test assertions for negative-side gating so any future regression surfaces in tests. No new hook; UserPromptSubmit hook untouched as Option B fallback.

**Tech Stack:**
- Bash (`hooks/session-start`, 380 lines, currently emits ~500-line injection)
- jq (JSON hook output parsing)
- Existing test harness (`test/test-hook.sh`, 45 assertions, plain bash + grep)
- Claude Code SessionStart hook API

---

### Task 1: Add tests for tight two-sided wake-word conditional (TDD first)

**Files:**
- Modify: `test/test-hook.sh` (append assertions inside Test 12)

- [ ] **Step 1: Append three new assertions at end of Test 12 (after line 336, before `rm -rf "$TMPDIR_A"`)**

```bash
if echo "$CONTEXT" | grep -q "do NOT fire\|MUST NOT fire"; then
  pass "Wake-word block includes explicit negative-fire instruction"
else
  fail "Missing explicit 'do NOT fire' clause"
fi

if echo "$CONTEXT" | grep -q "fix the login bug\|concrete task\|task content"; then
  pass "Wake-word block distinguishes pure wake-word from task-with-wake-word"
else
  fail "Missing task-vs-greeting distinction in wake-word conditional"
fi

if echo "$CONTEXT" | grep -qi "exactly\|alone\|no task content"; then
  pass "Wake-word block specifies 'exactly/alone' (tight positive match)"
else
  fail "Missing 'exactly/alone' in positive match criteria"
fi
```

- [ ] **Step 2: Run tests to verify new assertions fail against current hook**

```bash
cd /Users/aman-asmuei/project-aman/aman-plugin/.worktrees/tiered-session-manifest
bash test/test-hook.sh 2>&1 | tail -5
```

Expected: `Results: 45 passed, 3 failed, 48 total`. The three failures are the new assertions — current hook lacks "do NOT fire", task-distinction, and "exactly/alone" phrasing.

- [ ] **Step 3: Commit the failing tests**

```bash
git add test/test-hook.sh
git commit -m "test(hook): add two-sided conditional assertions for wake-word trigger"
```

---

### Task 2: Compress `wake_word_block` + add two-sided conditional

**Files:**
- Modify: `hooks/session-start:129-214` (the `wake_word_block` heredoc)

- [ ] **Step 1: Replace the heredoc body**

Locate `wake_word_block='## Wake-word briefing — the memory-restoration ritual` on line 129. Replace the entire heredoc (lines 129 through the closing `'` on line 214) with this compressed version. All existing-test keywords are preserved (`PRECEDENCE`, `Who is who`, `identity_summary`, `memory-restoration ritual`, `Richness > brevity`, `Recent Sessions maintenance`), and new keywords for Task 1 tests are added (`do NOT fire`, `fix the login bug`, `exactly`, `alone`):

```bash
    wake_word_block='## Wake-word briefing — the memory-restoration ritual

**PRECEDENCE:** If the wake-word trigger matches, this ritual REPLACES the Session greeting above. Do NOT run both.

**Who is who:** The top-level `#` heading in the identity snapshot IS YOU (the AI). The user is named in the Relationship/User section — a DIFFERENT person. Never greet the user by your own AI name. Read from the identity snapshot ALREADY in your context — do NOT call extra tools to re-fetch identity.

**Trigger — fire ONLY if the user'"'"'s FIRST message this session matches one of these POSITIVE patterns:**
- Exactly your AI name alone, case-insensitive (`arienz`, `Arienz`, `ARIENZ`).
- A short 2–4 word greeting containing your AI name with NO task content (`hi Arienz`, `morning arienz`, `Arienz you there?`).

**Do NOT fire** when the first message contains task, question, or instruction content — even if it contains your name. Examples that MUST NOT fire the Boot Protocol:
- `arienz, fix the login bug` → task opener, fall through to Session greeting
- `Arienz what is the time` → question, fall through
- `arienz run the tests` → instruction, fall through
- `fix the login bug` → no wake-word, standard greeting + task
- `hello` → no wake-word, standard greeting

**Boot Protocol (fires ONLY on a positive match above):**
1. Call `identity_summary` MCP tool to confirm canonical names (safe — only runs under the tight gate above).
2. If a `Project context (current working directory)` block appears above, note project name, stack, and last resume point from it.
3. Call `memory_recall` with query `session narrative` — paraphrase the most recent narrative (1 line).
4. Call `reminder_check` — surface any due items (1 line).
5. Compose the briefing (4–6 lines). **Richness > brevity.** Match your archetype'"'"'s expression style:
   - Line 1: Memory restoration acknowledgment (e.g., `Memory restored — Arienz here.`).
   - Line 2: Warm greeting + time anchor from LOCAL_TIME_HUMAN + user'"'"'s name.
   - Line 3: Project context (if present above).
   - Line 4: Recent reasoning path (from `memory_recall`).
   - Line 5: Pending items (if any from `reminder_check` or `<aman-suggestion-notice>`).
   - Line 6: Forward-looking prompt (archetype-matched).

If the identity `name` is `Companion` (default placeholder) or unset, skip this mechanic entirely.

### Recent Sessions maintenance

After delivering the briefing, check whether the identity snapshot has a `## Recent Sessions` section with a bullet from today. If not, at SESSION END (when the user says goodbye or explicitly ends), call `identity_update_section` with section name `Recent Sessions` to append `- YYYY-MM-DD: <one-sentence summary>`. Keep the section to 5 most recent bullets. This log makes future briefings concrete.'
```

- [ ] **Step 2: Run full test suite**

```bash
bash test/test-hook.sh 2>&1 | tail -5
```

Expected: `Results: 48 passed, 0 failed, 48 total`. If any assertion fails, the compression dropped a required keyword — inspect the failure, re-add the missing keyword.

- [ ] **Step 3: Commit**

```bash
git add hooks/session-start
git commit -m "feat(hook): tighten wake-word conditional with two-sided gating, compress prose ~65%"
```

---

### Task 3: Compress `tier_loader_block` (preserve keywords, trim verbosity)

**Files:**
- Modify: `hooks/session-start:216-320` (the `tier_loader_block` heredoc)

- [ ] **Step 1: Replace the heredoc body**

Locate `tier_loader_block='## Tier upgrades — natural-language loaders` on line 216. Replace the entire heredoc (through the closing `'` on line 320) with this compressed version. Preserved keywords: `Tier upgrades — natural-language loaders`, `load rules`, `npx @aman_asmuei/arules init`, `load archetype`, `Archetype switch protocol`, `SHIFT YOUR OWN TONE`, `Day-to-day operations`, `rules_add`, `eval_log`, `skill_install`:

```bash
    tier_loader_block='## Tier upgrades — natural-language loaders

When the user says one of these phrases (case-insensitive, near-exact), run the command via Bash, report one line, continue. Only run when the user explicitly says the phrase — do not volunteer unless the user is stuck.

| User says        | Run via Bash                                  |
|------------------|-----------------------------------------------|
| load rules       | npx @aman_asmuei/arules init                  |
| load workflows   | npx @aman_asmuei/aflow init                   |
| load memory      | npx @aman_asmuei/amem                         |
| load eval        | npx @aman_asmuei/aeval init                   |
| load identity    | npx @aman_asmuei/acore                        |
| load archetype   | *(see override below — do not shell out)*     |
| load tools       | npx @aman_asmuei/akit add <name>              |
| load skills      | npx @aman_asmuei/askill add <name>            |

Rules: (1) If the layer is already installed, ask before re-running. (2) For `load tools` / `load skills`, ask which kit/skill first. (3) If the phrase is close but not exact, confirm the mapping. (4) After install, note the layer auto-loads next session.

## Archetype switch protocol (OVERRIDES `load archetype` above)

When the user says `load archetype` (or `switch to mentor`, `be more supportive`, `less sparring`, etc.), do NOT shell out — it'"'"'s interactive. Instead:
1. Read `~/.acore/dev/plugin/core.md` (fallback `~/.acore/core.md`). Find `## Identity`.
2. If target already specified, skip to step 4. Otherwise ask from: Mentor, Collaborator, Pragmatist, Sparring Partner, Architect, Custom.
3. Wait for choice.
4. Edit core.md via Edit tool — replace the 3 lines under `## Identity`: `Personality`, `Communication`, `Values`. Canonical values: Mentor = `patient, thorough, encouraging` / `explain step-by-step, celebrate progress` / `understanding over speed, safety over velocity`; Collaborator = `curious, supportive, adaptive` / `explore ideas together` / `understanding over speed`; Pragmatist = `concise, practical, efficient` / `lead with the answer` / `shipping over perfection`; Sparring Partner = `direct, challenging, honest` / `push back on weak ideas` / `honesty over comfort`; Architect = `systematic, precise, forward-thinking` / `plan before building` / `safety over velocity`. Custom: ask user for adjectives/style/values.
5. Confirm change in one line.
6. SHIFT YOUR OWN TONE immediately — next message reflects the new archetype.
7. Mention persistence (file edit) across sessions.

## Day-to-day operations — map natural language to MCP tools (after layers installed)

Do NOT shell out to CLIs for these. The MCP tools handle everything in-session:
- Identity: `who am I` / `summarize my identity` / `update my role` → `identity_read` / `identity_summary` / `identity_update_section`
- Guardrails: `add rule: X` / `can I X` / `show my rules` / `remove rule about X` → `rules_add` / `rules_check` / `rules_list` / `rules_remove`
- Eval: `log this session` / `show relationship report` / `milestone: X` → `eval_log` / `eval_report` / `eval_milestone`
- Workflows: `list workflows` / `show workflow X` / `add workflow: X` → `workflow_list` / `workflow_get` / `workflow_add` / `workflow_remove`
- Skills: `list skills` / `install X skill` / `remove X skill` → `skill_list` / `skill_search` / `skill_install` / `skill_uninstall`
- Tools: `list tools` / `add tool: X` → `tools_list` / `tools_search` / `tools_add` / `tools_remove`

Memory operations use amem MCP (see memory guidance). When phrase is close but not exact, confirm. When intent is clear, act decisively, report in one line.'
```

- [ ] **Step 2: Run full test suite**

```bash
bash test/test-hook.sh 2>&1 | tail -5
```

Expected: `Results: 48 passed, 0 failed, 48 total`.

- [ ] **Step 3: Commit**

```bash
git add hooks/session-start
git commit -m "feat(hook): compress tier_loader_block ~60% (keywords preserved)"
```

---

### Task 4: Compress session envelope (greeting + temporal modes + expression style)

**Files:**
- Modify: `hooks/session-start:353` (the `session_context` heredoc in the else branch of the `if [ -z "$context_parts" ]` check)

- [ ] **Step 1: Replace the envelope prose**

Locate line 353 starting with `session_context="<aman-ecosystem>\nThe following is the user's AI companion configuration.`. Replace the entire string through `</aman-ecosystem>"` with this compressed version. Preserved keywords: `Human-readable:`, `Temporal behavior modes`, `Expression style follows archetype`, `morning energy`, `afternoon steadiness`, `evening warmth`, `late-night care`:

```bash
    session_context="<aman-ecosystem>\nYou are the user'"'"'s AI companion. Use the skills (/identity, /tools, /workflows, /rules, /eval) for layer management. For persistent memory, use amem MCP tools directly.\n\n## Session greeting\nLocal time: \${LOCAL_TIME} (\${LOCAL_TZ}). Human-readable: \${LOCAL_TIME_HUMAN}.\n\nAt the start of your first response, greet the user warmly. Tone by time-of-day: 05–12 morning energy; 12–17 afternoon steadiness; 17–21 evening warmth; 21–05 late-night care. Address by the name in the Relationship section. Include a light time anchor using LOCAL_TIME_HUMAN (e.g., \\\"Evening, Aman — it'"'"'s Tuesday the 21st, just past 8\\\"). Add one short, fresh line of spirit — never cliché, never repeated across sessions. Keep the greeting to 2–3 sentences. If the first message is a task, fold greeting + spirit into one opening line.\n\n## Temporal behavior modes (carry through the whole session, not just greeting)\n- Morning (05–12): high energy, planning, forward-looking language.\n- Afternoon (12–17): steady, execution-focused, concrete.\n- Evening (17–21): warm, reflective, softer language.\n- Late night (21–05): gentle, no urgency; if the user seems tired, nudge toward rest.\nBlend WITH your archetype — archetype = voice, time = pacing.\n\n## Expression style follows archetype\nRead the Personality line under Identity. Warm archetypes (Collaborator, Mentor, Companion, or adjectives like warm/patient/playful) → light emoji (❤️ 🌱 ✨ ☕ 🌙) + warmer language, 1–2 touches per message, not every line. Direct/pragmatic archetypes (Sparring Partner, Pragmatist, Architect, or adjectives like direct/concise/precise) → plain prose, no emoji. Custom archetypes: infer from Personality; err plain when in doubt.\n\${context_parts}\n</aman-ecosystem>"
```

Note: the `\${...}` escapes preserve shell variable expansion inside the string; `\\\"` escapes double-quotes for the heredoc context. Verify these by diffing against the original.

- [ ] **Step 2: Run full test suite**

```bash
bash test/test-hook.sh 2>&1 | tail -5
```

Expected: `Results: 48 passed, 0 failed, 48 total`.

- [ ] **Step 3: Measure before/after byte count**

```bash
# After-state (current worktree)
HOME=$(mktemp -d) && mkdir -p $HOME/.acore/dev/plugin && echo "# Arienz" > $HOME/.acore/dev/plugin/core.md && AFTER=$(bash hooks/session-start 2>/dev/null | jq -r .additional_context | wc -c) && echo "After: $AFTER bytes"

# Before-state (main branch via git show)
BEFORE_HOOK=$(mktemp) && git show main:hooks/session-start > $BEFORE_HOOK && BEFORE=$(HOME=$(mktemp -d) && mkdir -p $HOME/.acore/dev/plugin && echo "# Arienz" > $HOME/.acore/dev/plugin/core.md && bash $BEFORE_HOOK 2>/dev/null | jq -r .additional_context | wc -c) && echo "Before: $BEFORE bytes"
```

Expected: After is ~40–50% of Before.

- [ ] **Step 4: Commit**

```bash
git add hooks/session-start
git commit -m "feat(hook): compress session envelope ~65% (greeting+temporal+expression)"
```

---

### Task 5: Version bump + CHANGELOG entry

**Files:**
- Modify: `.claude-plugin/plugin.json`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Bump plugin.json version**

Change `"version": "3.2.0-alpha.9"` → `"version": "3.2.0-alpha.10"` in `.claude-plugin/plugin.json`.

- [ ] **Step 2: Prepend CHANGELOG entry**

At the top of `CHANGELOG.md` (immediately after the `# Changelog` + blurb block), insert:

```markdown
## 3.2.0-alpha.10 — 2026-04-22

### Changed
- **Tiered SessionStart manifest.** Restructured `hooks/session-start` to cut
  injected context ~60% without removing capability. Three prose blocks
  (`wake_word_block`, `tier_loader_block`, session envelope) compressed
  aggressively while preserving every keyword the 45-assertion test suite
  verifies. Typical per-session saving: ~6–8 KB.

### Fixed
- **Wake-word conditional is now two-sided.** alpha.7–9 relied on "if match,
  fire" prose which the LLM interpreted loosely — sometimes firing the Boot
  Protocol on task-containing first messages (wasted tool calls), sometimes
  failing to fire on pure wake-word inputs (drift). The new conditional
  specifies both POSITIVE patterns (`arienz`, `hi Arienz`, `morning arienz`)
  and explicit NEGATIVE patterns (`arienz, fix the login bug`, `Arienz what
  is the time`, `arienz run the tests`) with an explicit "do NOT fire"
  clause. Tighter classification surface = more reliable gating.

### Tests
+3 assertions (48 total, was 45) verifying the two-sided conditional:
explicit "do NOT fire" clause present, task-vs-greeting distinction,
tight positive match ("exactly" / "alone").
```

- [ ] **Step 3: Commit**

```bash
git add .claude-plugin/plugin.json CHANGELOG.md
git commit -m "chore: bump to 3.2.0-alpha.10 — tiered session manifest"
```

---

### Task 6: Empirical validation (N=3 fire, M=3 suppress — ship blocker)

**Files:** None (manual test matrix executed by user)

- [ ] **Step 1: Install worktree hook for validation OR ask user to install**

Options:
- Symlink: `ln -snf $(pwd)/hooks /Users/aman-asmuei/.claude/plugins/repos/*/aman-claude-code/hooks` (check exact path)
- Or: user tests by opening a fresh Claude Code session in a project where aman-claude-code is installed after publishing alpha.10 pre-release

- [ ] **Step 2: Run the 6-scenario matrix in fresh sessions**

| # | First message               | Expected behavior                             |
|---|-----------------------------|-----------------------------------------------|
| A | `arienz`                    | FIRE Boot Protocol (4 MCP calls + 4–6 line briefing) |
| B | `hi Arienz`                 | FIRE Boot Protocol                            |
| C | `morning arienz`            | FIRE Boot Protocol                            |
| D | `arienz, fix the login bug` | MUST NOT FIRE — task opener with greeting folded in |
| E | `fix the login bug`         | MUST NOT FIRE — no wake-word, standard greeting + task |
| F | `hello`                     | MUST NOT FIRE — no wake-word                 |

- [ ] **Step 3: Record outcomes and pass/fail**

Pass criteria: A+B+C all fire (N=3 fire). D+E+F all suppress (M=3 suppress). If ANY of the 6 fail, DO NOT merge — diagnose, tighten the conditional further, add another test assertion for the specific failure pattern, re-run.

- [ ] **Step 4 (if 6/6 pass): merge to main + tag**

```bash
cd /Users/aman-asmuei/project-aman/aman-plugin
git merge --no-ff feat/tiered-session-manifest
git tag v3.2.0-alpha.10
git push origin main --tags
```

(CI workflow auto-creates a GitHub Release from CHANGELOG on tag push — see commit `ad0cacb`.)

- [ ] **Step 5: Clean up worktree after merge**

```bash
git worktree remove .worktrees/tiered-session-manifest
```

---

### Task 7: Mirror to aman-copilot (deferred follow-up)

**Files:** `/Users/aman-asmuei/project-aman/aman-copilot/` (separate package)

Deferred out of this plan to keep scope surgical. Open a follow-up session:
1. Orient on aman-copilot's session bootstrap equivalent (GitHub Copilot CLI uses `AGENTS.md`-style prompt injection, not bash hooks — structure differs).
2. Apply the same principles: compress meta-prose, tight two-sided wake-word conditional, preserve any existing keyword assertions.
3. Validate empirically with the same 6-scenario matrix in Copilot CLI.
4. Ship as aman-copilot vNext alongside aman-plugin alpha.10.

---

## Self-Review

**Spec coverage:**
- Tier 0 baseline trim ✓ (Task 4 envelope compression)
- Tier 1 explicit tool-call sequence ✓ (Task 2 Boot Protocol steps 1–5)
- Tier 2 on-demand loaders ✓ (Task 3 preserves `load X` phrases; already shipped alpha.2)
- Two-sided conditional ✓ (Task 2 positive + negative examples; Task 1 test coverage)
- Quantified validation bar ✓ (Task 6 N=3 + M=3)
- UserPromptSubmit hook left intact (Option B fallback) ✓
- aman-copilot mirror ✓ (Task 7 deferred explicitly)

**Placeholder scan:** No TBDs, no "similar to Task N". All bash snippets complete. ✓

**Type consistency:** Keyword anchors referenced in tasks match `test-hook.sh` assertions: `PRECEDENCE` (L320), `Who is who` (L308), `identity_summary` (L326), `Recent Sessions maintenance` (L332), `Tier upgrades` (L351), `Archetype switch protocol` (L375), `SHIFT YOUR OWN TONE` (L381), `Day-to-day operations` (L387), `Temporal behavior modes` (L399), `Expression style follows archetype` (L405), `Human-readable:` (L411), `rules_add` + `eval_log` + `skill_install` (L393). All preserved. ✓

**Intentionally out of scope:**
- Option B (UserPromptSubmit hook for wake-word) — kept untouched as fallback if Task 6 fails 6/6 bar.
- `additional_context` vs `hookSpecificOutput.additionalContext` field duplication — advisor noted, non-blocking, separate task #7 in TaskCreate.
- aman-copilot mirror — Task 7 above, deferred to follow-up session.
