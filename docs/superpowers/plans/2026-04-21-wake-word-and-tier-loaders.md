# Wake-word Briefing + Tier-loader Phrases Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship two new instruction blocks — "Wake-word briefing" and "Tier-loader phrase catalog" — into the aman-claude-code session-start hook and the aman-copilot `copilot-instructions.md` template, so users can trigger a full session briefing by typing just the AI's name and install ecosystem layers by saying "load rules", "load memory", etc.

**Architecture:** Two repos edited. Each block is a static text string appended to the system context the LLM already receives. No new skills, no new CLI commands, no MCP tool changes, no wizard refactor. Block prose is identical on both surfaces except one adapted bullet on Copilot.

**Tech Stack:**
- `aman-plugin`: bash (`hooks/session-start`) + bash test (`test/test-hook.sh`)
- `aman-copilot`: Node 18+ ESM (`bin/init.mjs`) + bash test (`test/test.sh`)
- Both repos: plain text Markdown-ish prose embedded as string constants, validated by `grep`.

**Repositories:**
- `aman-plugin` at `/Users/aman-asmuei/project-aman/aman-plugin/` (branch: `main`, ahead 1)
- `aman-copilot` at `/Users/aman-asmuei/project-aman/aman-copilot/` (branch: check `git branch --show-current`)

**Spec:** `aman-plugin/docs/superpowers/specs/2026-04-21-wake-word-and-tier-loaders-design.md`

---

## File Structure

| Repo | File | Action | Responsibility |
|---|---|---|---|
| `aman-plugin` | `hooks/session-start` | Modify | Append Block A + Block B to `context_parts` (guarded by "ecosystem exists" check) |
| `aman-plugin` | `test/test-hook.sh` | Modify | Add 3 assertions: Block A in ecosystem-present output, Block B in ecosystem-present output, neither block in no-ecosystem output |
| `aman-copilot` | `bin/init.mjs` | Modify | Extend `buildInstructions()` to emit Block A (Copilot-adapted) + Block B |
| `aman-copilot` | `test/test.sh` | Modify | Add assertions: both block signatures appear in rendered `copilot-instructions.md` |

No new files. Four existing files modified across two repos. Both repos remain fully testable on their own.

---

## Block Prose — Canonical Source

These two string constants are the deliverable. Both files in both repos embed this exact text.

### Block A prose (Claude Code version)

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

### Block A prose (Copilot version)

Identical to the Claude Code version EXCEPT bullet 4 reads:

```text
4. If a "suggestions pending" line appears earlier in this instruction file,
   restate it.
```

(Rationale: Copilot has no `<aman-suggestion-notice>` tag; see spec §4.2.)

### Block B prose (identical on both surfaces)

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

---

## Phase A — aman-claude-code

All tasks in this phase are in repo `/Users/aman-asmuei/project-aman/aman-plugin/`.

### Task A1: Write failing test for Block A appearing in hook output

**Files:**
- Modify: `test/test-hook.sh` (append a new test group at the end, before the summary print)

- [ ] **Step 1: Write the failing test**

Append this test block at the end of `test/test-hook.sh`, BEFORE the final summary/exit section at the bottom of the file (the section that prints pass/fail counts and `exit`s). Add it as a new `Test N` group. To find the next test number, run:

```bash
grep -cE '^# ---------- Test ' /Users/aman-asmuei/project-aman/aman-plugin/test/test-hook.sh
```

Use `that-count + 1` as `N` in the snippet below.

```bash
# ---------- Test N: Block A (wake-word briefing) injected when ecosystem exists ----------
echo ""
echo "Test N: Wake-word briefing block present when ecosystem exists"
TMPDIR_A=$(mktemp -d)
mkdir -p "$TMPDIR_A/.acore/dev/plugin"
echo "# Identity
name: Sarah" > "$TMPDIR_A/.acore/dev/plugin/core.md"

OUTPUT=$(HOME="$TMPDIR_A" bash "$HOOK_PATH" 2>&1)
CONTEXT=$(echo "$OUTPUT" | jq -r '.additional_context')

if echo "$CONTEXT" | grep -q "Wake-word briefing"; then
  pass "Contains 'Wake-word briefing' heading when ecosystem exists"
else
  fail "Missing 'Wake-word briefing' heading"
fi

if echo "$CONTEXT" | grep -q "EXPLICIT briefing request"; then
  pass "Contains Block A body signature"
else
  fail "Missing Block A body signature"
fi

rm -rf "$TMPDIR_A"
```

(Replace `Test N` with the correct sequential number. Use `grep -cE '^# ---------- Test' test/test-hook.sh` to count current tests; next number = count + 1.)

- [ ] **Step 2: Run test and verify it fails**

```bash
cd /Users/aman-asmuei/project-aman/aman-plugin && bash test/test-hook.sh
```

Expected: The two new assertions fail with `FAIL: Missing 'Wake-word briefing' heading` and `FAIL: Missing Block A body signature`. All pre-existing tests should continue to pass. Final line should show a FAIL count of 2 (exactly these two).

- [ ] **Step 3: Implement Block A injection in the hook**

Edit `hooks/session-start`. Find the suggestion-notice block (search for `SUGGESTIONS_FILE="$HOME/.arules/dev/plugin/suggestions.md"`). AFTER the entire `if [ -f "$SUGGESTIONS_FILE" ]; then ... fi` block ends (around line 150 in current HEAD), BEFORE the `# Build the context message` comment (around line 152), insert:

```bash
# Wake-word briefing + tier loaders — only inject if the ecosystem has any
# content to anchor to; otherwise the "No aman ecosystem configured" fallback
# should fire unmodified.
if [ -n "$context_parts" ]; then
    wake_word_block='## Wake-word briefing

If the user'"'"'s first message in this session is just your identity name (the
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
5. End with a short open-ended prompt ("What'"'"'s next?" / "Where do we start?").

Keep the whole briefing under 6 lines.

Do NOT run this flow if the first message is a concrete task — even if it
starts with your name. Use judgment: "Sarah" alone = briefing;
"Sarah, fix the login bug" = task (apply the fold-greeting-into-task-opener
rule from the Session greeting section).

If the identity "name" is "Companion" (default) or unset, skip this mechanic
entirely — you don'"'"'t have a distinct wake-word to match on.'
    context_parts="${context_parts}\n\n---\n\n${wake_word_block}"
fi
```

**Gotcha:** Bash single-quoted strings cannot contain single quotes directly. This plan uses the `'"'"'` idiom (close quote, escaped single, re-open quote) to embed apostrophes in the block. Preserve it exactly — modifying to `\'` or double quotes will break the heredoc.

**Gotcha:** The string contains literal backticks (around `memory_recall`, `reminder_check`, `<aman-suggestion-notice>`). Because we're using single quotes, backticks are preserved as literal characters — do NOT switch this block to double quotes, which would cause bash to attempt command substitution.

- [ ] **Step 4: Run test to verify it passes**

```bash
cd /Users/aman-asmuei/project-aman/aman-plugin && bash test/test-hook.sh
```

Expected: All tests pass, including the two new Block A assertions. FAIL count should be 0.

- [ ] **Step 5: Commit**

```bash
cd /Users/aman-asmuei/project-aman/aman-plugin
git add hooks/session-start test/test-hook.sh
git commit -m "feat(hook): inject wake-word briefing block

Adds Block A from the 2026-04-21 spec: tells the LLM to respond with
a session briefing when the user's first message is just the AI's
identity name, instead of silent auto-load. Gated on ecosystem being
present; respects default-name ('Companion') by skipping."
```

---

### Task A2: Write failing test for Block B appearing in hook output

**Files:**
- Modify: `test/test-hook.sh` (append another test group)

- [ ] **Step 1: Write the failing test**

Append after Task A1's test block (next sequential test number):

```bash
# ---------- Test N+1: Block B (tier loaders) injected when ecosystem exists ----------
echo ""
echo "Test N+1: Tier-loader block present when ecosystem exists"
TMPDIR_B=$(mktemp -d)
mkdir -p "$TMPDIR_B/.acore/dev/plugin"
echo "# Identity
name: Sarah" > "$TMPDIR_B/.acore/dev/plugin/core.md"

OUTPUT=$(HOME="$TMPDIR_B" bash "$HOOK_PATH" 2>&1)
CONTEXT=$(echo "$OUTPUT" | jq -r '.additional_context')

if echo "$CONTEXT" | grep -q "Tier upgrades — natural-language loaders"; then
  pass "Contains 'Tier upgrades' heading"
else
  fail "Missing 'Tier upgrades' heading"
fi

if echo "$CONTEXT" | grep -q "load rules"; then
  pass "Contains 'load rules' phrase in catalog"
else
  fail "Missing 'load rules' phrase"
fi

if echo "$CONTEXT" | grep -q "npx @aman_asmuei/arules init"; then
  pass "Contains arules npx command in catalog"
else
  fail "Missing arules npx command"
fi

if echo "$CONTEXT" | grep -q "load archetype"; then
  pass "Contains 'load archetype' phrase"
else
  fail "Missing 'load archetype' phrase"
fi

rm -rf "$TMPDIR_B"
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/aman-asmuei/project-aman/aman-plugin && bash test/test-hook.sh
```

Expected: The four new Block B assertions fail. Block A tests from Task A1 still pass. Pre-existing tests still pass.

- [ ] **Step 3: Implement Block B injection in the hook**

Edit `hooks/session-start`. Inside the same `if [ -n "$context_parts" ]; then ... fi` block you created in Task A1, AFTER the `context_parts="${context_parts}\n\n---\n\n${wake_word_block}"` line but still inside the `if`, add:

```bash
    tier_loader_block='## Tier upgrades — natural-language loaders

When the user says any of these phrases (case-insensitive, exact or near-exact
match), it'"'"'s a request to install / reconfigure the corresponding ecosystem
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
   it'"'"'s already set up and ask whether to re-run anyway before executing.
2. For `load tools` and `load skills`, the subcommand requires a name — if the
   user only says "load tools", ask which kit before running.
3. Only run these when the user explicitly says the phrase. Do not volunteer
   these as suggestions unless the user is obviously stuck looking for a layer.
4. After a successful install, tell the user the new layer will auto-load on
   the NEXT session start (since the session-start hook scans for it).
5. Do NOT chain loaders ("load everything") without confirming each one.
6. If the user'"'"'s phrase is close but not exact (e.g., "install rules", "enable
   arules"), confirm the mapping before running.

These phrases are the user'"'"'s entry to the ecosystem'"'"'s tiered features. Treat
them as first-class intents, same weight as slash commands.'
    context_parts="${context_parts}\n\n---\n\n${tier_loader_block}"
```

**Gotcha:** Same `'"'"'` idiom for apostrophes. Same backtick warning — do not switch to double quotes.

- [ ] **Step 4: Run test to verify all tests pass**

```bash
cd /Users/aman-asmuei/project-aman/aman-plugin && bash test/test-hook.sh
```

Expected: All tests pass. FAIL count is 0.

- [ ] **Step 5: Commit**

```bash
cd /Users/aman-asmuei/project-aman/aman-plugin
git add hooks/session-start test/test-hook.sh
git commit -m "feat(hook): inject tier-loader phrase catalog

Adds Block B from the 2026-04-21 spec: natural-language catalog
mapping 'load rules' / 'load memory' / 'load archetype' / etc. to
the corresponding npx installer. LLM shells out via Bash. Respects
already-installed layers by asking before re-running."
```

---

### Task A3: Write failing test proving blocks do NOT appear when ecosystem is absent

**Files:**
- Modify: `test/test-hook.sh` (append a final test group)

This catches the regression where Block A/B accidentally leak into the "no ecosystem configured" branch.

- [ ] **Step 1: Write the failing test**

Append after Task A2's test block:

```bash
# ---------- Test N+2: Blocks NOT injected when ecosystem is empty ----------
echo ""
echo "Test N+2: Blocks absent when no ecosystem configured"
TMPDIR_C=$(mktemp -d)
# Empty HOME — no .acore, no .arules, no .aflow, nothing.

OUTPUT=$(HOME="$TMPDIR_C" bash "$HOOK_PATH" 2>&1)
CONTEXT=$(echo "$OUTPUT" | jq -r '.additional_context')

if echo "$CONTEXT" | grep -q "Wake-word briefing"; then
  fail "Block A leaked into no-ecosystem fallback"
else
  pass "Block A correctly absent when no ecosystem exists"
fi

if echo "$CONTEXT" | grep -q "Tier upgrades"; then
  fail "Block B leaked into no-ecosystem fallback"
else
  pass "Block B correctly absent when no ecosystem exists"
fi

if echo "$CONTEXT" | grep -q "No aman ecosystem configured"; then
  pass "Fallback message still present when no ecosystem"
else
  fail "Fallback message missing — regression"
fi

rm -rf "$TMPDIR_C"
```

- [ ] **Step 2: Run the full suite**

```bash
cd /Users/aman-asmuei/project-aman/aman-plugin && bash test/test-hook.sh
```

Expected: All tests including the three new assertions above pass. The `if [ -n "$context_parts" ]; then` guard from Task A1 already prevents the blocks from appearing in the empty-ecosystem case, so no additional code change should be needed.

**If any test fails here:** the guard from Task A1 was written wrong. Verify that the entire Block A injection and Block B injection sit INSIDE the same `if [ -n "$context_parts" ]; then ... fi` block. Open `hooks/session-start` and verify indentation.

- [ ] **Step 3: Commit**

```bash
cd /Users/aman-asmuei/project-aman/aman-plugin
git add test/test-hook.sh
git commit -m "test(hook): verify blocks absent in no-ecosystem fallback

Regression test for the guard: wake-word briefing and tier-loader
blocks must not leak into the 'No aman ecosystem configured' output.
Today's guard (context_parts non-empty check) passes."
```

---

## Phase B — aman-copilot

All tasks in this phase are in repo `/Users/aman-asmuei/project-aman/aman-copilot/`.

### Task B1: Write failing test for Block A (Copilot-adapted) and Block B in rendered copilot-instructions.md

**Files:**
- Modify: `test/test.sh` (append new test group at the end, before final summary)

- [ ] **Step 1: Find the insertion point**

Run:
```bash
grep -n "^echo.*PASS\|^exit" /Users/aman-asmuei/project-aman/aman-copilot/test/test.sh | tail -5
```

Identify the final summary / exit section. Insert the new test group BEFORE it.

- [ ] **Step 2: Write the failing test**

Append the following test group before the final summary:

```bash
# ---------- Test: Wake-word briefing + tier loaders in copilot-instructions.md ----------
echo ""
echo "Test: Block A + Block B present in rendered copilot-instructions.md"

TMP_WAKE=$(make_sandbox_home "dev/copilot")
cleanup_dirs+=("$TMP_WAKE")
cd "$TMP_WAKE"

HOME="$TMP_WAKE" node "$INIT" >/dev/null 2>&1

INSTRUCTIONS_FILE="$TMP_WAKE/.github/copilot-instructions.md"

if [ ! -f "$INSTRUCTIONS_FILE" ]; then
  fail "copilot-instructions.md was not rendered"
else
  pass "copilot-instructions.md rendered"

  if grep -q "Wake-word briefing" "$INSTRUCTIONS_FILE"; then
    pass "Contains 'Wake-word briefing' heading"
  else
    fail "Missing 'Wake-word briefing' heading"
  fi

  if grep -q "EXPLICIT briefing request" "$INSTRUCTIONS_FILE"; then
    pass "Contains Block A body signature"
  else
    fail "Missing Block A body signature"
  fi

  if grep -q "suggestions pending" "$INSTRUCTIONS_FILE"; then
    pass "Contains Copilot-adapted bullet 4 ('suggestions pending')"
  else
    fail "Missing Copilot-adapted bullet 4 — should say 'suggestions pending line appears earlier'"
  fi

  if grep -q "aman-suggestion-notice" "$INSTRUCTIONS_FILE"; then
    fail "Copilot file contains Claude-Code-specific '<aman-suggestion-notice>' tag (should be adapted)"
  else
    pass "Copilot file correctly omits '<aman-suggestion-notice>' tag"
  fi

  if grep -q "Tier upgrades — natural-language loaders" "$INSTRUCTIONS_FILE"; then
    pass "Contains 'Tier upgrades' heading"
  else
    fail "Missing 'Tier upgrades' heading"
  fi

  if grep -q "load rules" "$INSTRUCTIONS_FILE" && grep -q "npx @aman_asmuei/arules init" "$INSTRUCTIONS_FILE"; then
    pass "Contains 'load rules' catalog entry"
  else
    fail "Missing 'load rules' catalog entry"
  fi

  if grep -q "load archetype" "$INSTRUCTIONS_FILE" && grep -q "acore customize" "$INSTRUCTIONS_FILE"; then
    pass "Contains 'load archetype' catalog entry"
  else
    fail "Missing 'load archetype' catalog entry"
  fi
fi
```

- [ ] **Step 3: Run test to verify it fails**

```bash
cd /Users/aman-asmuei/project-aman/aman-copilot && bash test/test.sh
```

Expected: Block A and Block B assertions fail. Pre-existing tests should continue to pass.

- [ ] **Step 4: Implement Block A and Block B in `buildInstructions()`**

Edit `bin/init.mjs`. Locate the `buildInstructions({ core, rules, amemInstalled })` function (starts around line 62). Find the line:

```javascript
sections.push(
    "## Rules protocol (arules)",
```

This is the `sections.push(...)` call AFTER the `if (amemInstalled)` block closes. **Immediately BEFORE that `sections.push(` call**, insert the following two `sections.push` calls:

```javascript
  // Block A — Wake-word briefing (Copilot-adapted: bullet 4 references
  // "suggestions pending" line in this file, since Copilot has no
  // <aman-suggestion-notice> hook tag).
  sections.push(
    "## Wake-word briefing",
    "",
    "If the user's first message in this session is just your identity name (the",
    "\"name\" field in the Identity section above) — or a short greeting that contains",
    "your name as the main content (examples: \"Sarah\", \"hi Sarah\", \"Sarah you",
    "there?\", \"morning Sarah\") — treat it as an EXPLICIT briefing request, not a",
    "task.",
    "",
    "Respond with:",
    "1. Warm greeting in the time-of-day tone specified above. Address the user by",
    "   the name in the Relationship section if available.",
    "2. If the `memory_recall` MCP tool is available: call it with query",
    "   \"session narrative\" and paraphrase the most recent narrative in one",
    "   sentence. If none found, say \"no session narrative yet\".",
    "3. If the `reminder_check` MCP tool is available: call it. Surface any",
    "   reminder due today or overdue in one line. If none, skip this line.",
    "4. If a \"suggestions pending\" line appears earlier in this instruction file,",
    "   restate it.",
    "5. End with a short open-ended prompt (\"What's next?\" / \"Where do we start?\").",
    "",
    "Keep the whole briefing under 6 lines.",
    "",
    "Do NOT run this flow if the first message is a concrete task — even if it",
    "starts with your name. Use judgment: \"Sarah\" alone = briefing;",
    "\"Sarah, fix the login bug\" = task (apply the fold-greeting-into-task-opener",
    "rule from the Session greeting section).",
    "",
    "If the identity \"name\" is \"Companion\" (default) or unset, skip this mechanic",
    "entirely — you don't have a distinct wake-word to match on.",
    "",
    "---",
    "",
  );

  // Block B — Tier-loader phrase catalog (identical on both surfaces).
  sections.push(
    "## Tier upgrades — natural-language loaders",
    "",
    "When the user says any of these phrases (case-insensitive, exact or near-exact",
    "match), it's a request to install / reconfigure the corresponding ecosystem",
    "layer. Run the command via Bash, report one line of result, and continue.",
    "",
    "| User says        | Run via Bash                                  | Purpose |",
    "|------------------|-----------------------------------------------|---------|",
    "| load rules       | npx @aman_asmuei/arules init                  | Guardrails (24 starter rules) |",
    "| load workflows   | npx @aman_asmuei/aflow init                   | 4 starter workflows |",
    "| load memory      | npx @aman_asmuei/amem                         | Persistent amem MCP |",
    "| load eval        | npx @aman_asmuei/aeval init                   | Relationship tracking |",
    "| load identity    | npx @aman_asmuei/acore                        | Full identity (re-)walk |",
    "| load archetype   | npx @aman_asmuei/acore customize              | Change AI personality |",
    "| load tools       | npx @aman_asmuei/akit add <name>              | Tool kits (ask which) |",
    "| load skills      | npx @aman_asmuei/askill add <name>            | Plugin skills (ask which) |",
    "",
    "Rules:",
    "1. If the corresponding layer is already installed (e.g., ~/.arules/rules.md",
    "   or ~/.arules/dev/plugin/rules.md exists for \"load rules\"), tell the user",
    "   it's already set up and ask whether to re-run anyway before executing.",
    "2. For `load tools` and `load skills`, the subcommand requires a name — if the",
    "   user only says \"load tools\", ask which kit before running.",
    "3. Only run these when the user explicitly says the phrase. Do not volunteer",
    "   these as suggestions unless the user is obviously stuck looking for a layer.",
    "4. After a successful install, tell the user the new layer will auto-load on",
    "   the NEXT session start (since the session-start hook scans for it).",
    "5. Do NOT chain loaders (\"load everything\") without confirming each one.",
    "6. If the user's phrase is close but not exact (e.g., \"install rules\", \"enable",
    "   arules\"), confirm the mapping before running.",
    "",
    "These phrases are the user's entry to the ecosystem's tiered features. Treat",
    "them as first-class intents, same weight as slash commands.",
    "",
    "---",
    "",
  );
```

**Gotcha (important):** The existing `buildInstructions()` function uses `sections.push(...strings, "", ...)` where every array element becomes one line joined by `\n` at the end via `sections.join("\n")`. Every visible line of your block needs its own string element; blank lines need `""` elements. Do NOT put `\n` inside string literals — that produces `\n\n` when joined (double newlines everywhere).

**Gotcha (important):** JavaScript double-quoted strings require escaping of embedded double quotes (`\"`) and backslashes. The blocks contain quoted phrases like `"Sarah"` — these MUST be `\"Sarah\"` inside the JS string literal. Apostrophes do not require escaping inside double-quoted JS strings, so `it's` is fine unescaped.

**Gotcha:** The backticks around `memory_recall`, `reminder_check`, `load tools`, `load skills` are plain characters in a JavaScript string — no escaping needed.

- [ ] **Step 5: Run test to verify all pass**

```bash
cd /Users/aman-asmuei/project-aman/aman-copilot && bash test/test.sh
```

Expected: All tests pass. FAIL count is 0.

- [ ] **Step 6: Manual inspect the rendered output (hermetic)**

Verify the rendered file looks right visually — not just that grep matches. Run this in a temp HOME that does NOT touch your real `~/.acore`:

```bash
cd /Users/aman-asmuei/project-aman/aman-copilot && \
  TMPINSPECT=$(mktemp -d) && \
  mkdir -p "$TMPINSPECT/.acore/dev/copilot" && \
  echo "name: TestBot" > "$TMPINSPECT/.acore/dev/copilot/core.md" && \
  mkdir -p "$TMPINSPECT/.arules/dev/copilot" && \
  echo "# test rules" > "$TMPINSPECT/.arules/dev/copilot/rules.md" && \
  cd "$TMPINSPECT" && HOME="$TMPINSPECT" node /Users/aman-asmuei/project-aman/aman-copilot/bin/init.mjs && \
  cat "$TMPINSPECT/.github/copilot-instructions.md" | grep -A 10 "Wake-word briefing" && \
  echo "" && \
  cat "$TMPINSPECT/.github/copilot-instructions.md" | grep -A 5 "Tier upgrades" && \
  rm -rf "$TMPINSPECT"
```

Expected: You see the `## Wake-word briefing` heading followed by "If the user's first message..." and then the `## Tier upgrades — natural-language loaders` heading with the catalog table rows. The output should be cleanly formatted Markdown with no `\n` literal characters visible.

- [ ] **Step 7: Commit**

```bash
cd /Users/aman-asmuei/project-aman/aman-copilot
git add bin/init.mjs test/test.sh
git commit -m "feat(init): inject wake-word briefing + tier loaders

Adds Block A (Copilot-adapted bullet 4) and Block B from the
2026-04-21 spec into the rendered copilot-instructions.md. Parity
with aman-claude-code v3.2.0 session-start hook injection."
```

---

## Phase C — Spec alignment check

### Task C1: Self-review plan execution vs spec

- [ ] **Step 1: Re-read the spec and the plan side by side**

```bash
cat /Users/aman-asmuei/project-aman/aman-plugin/docs/superpowers/specs/2026-04-21-wake-word-and-tier-loaders-design.md
```

Check each of these spec sections has a task that implements it:

| Spec section | Implemented by |
|---|---|
| §3.1 File changes (hooks/session-start, test-hook.sh, init.mjs, test.sh) | Tasks A1-A3, B1 |
| §3.2 Delivery paths (hook append vs Copilot template) | Tasks A1/A2 (hook), B1 (template) |
| §4 Block A prose (Claude Code version) | Task A1 |
| §4.2 Copilot adaptation (bullet 4 adapted) | Task B1 (verified via test assertion) |
| §5 Block B prose (identical both surfaces) | Tasks A2, B1 |
| §6 Error handling | LLM-behavioral, validated by manual smoke (§7.3) |
| §7.1 test-hook.sh assertions | Tasks A1-A3 |
| §7.2 test.sh assertions | Task B1 |
| §7.3 Manual smoke | Outside automated plan — documented in Phase D below |

- [ ] **Step 2: Manual smoke tests from spec §7.3**

These validate LLM behavior (not automated). Run them yourself on a clean install after the commits land:

1. **Wake-word happy path:** on a machine with `~/.acore/dev/plugin/core.md` containing `name: Sarah`, start Claude Code session. First message: `Sarah`. Expect: 2-6 line briefing with last narrative + reminders + "what's next?".
2. **Default-name guard:** on a machine where `core.md` has `name: Companion`, first message `Companion`. Expect: today's behavior (normal response, no briefing).
3. **Task-with-name:** first message `Sarah, what does this codebase do?`. Expect: task response, greeting folded into task opener.
4. **Block B rules (fresh):** on a machine with no `~/.arules`, say `load rules`. Expect: LLM runs `npx @aman_asmuei/arules init`, reports new file created.
5. **Block B rules (already installed):** on a machine with `~/.arules/rules.md`, say `load rules`. Expect: LLM asks "already installed — re-run anyway?".
6. **Block B tools (needs arg):** say `load tools`. Expect: LLM asks "which kit?".
7. **Copilot parity:** after `aman-copilot init` + VS Code restart + Agent mode, repeat tests 1 and 4.

Document any behavioral divergence as a spec amendment (new section) or a follow-up plan, not a patch to this plan.

---

## Phase D — Ship

### Task D1: Version bumps

**Files (aman-plugin):**
- Modify: `.claude-plugin/plugin.json` — bump version
- Modify: `CHANGELOG.md` — add v3.2.0-alpha.2 entry

**Files (aman-copilot):**
- Modify: `package.json` — bump version
- Modify: `CHANGELOG.md` — add v0.5.0 entry

- [ ] **Step 1: Bump aman-plugin to v3.2.0-alpha.2**

Edit `aman-plugin/.claude-plugin/plugin.json` — change `"version": "3.2.0-alpha.1"` to `"version": "3.2.0-alpha.2"`.

Add this entry to the top of `aman-plugin/CHANGELOG.md` (under the `## [Unreleased]` section or create a `## [3.2.0-alpha.2]` section dated `2026-04-21`):

```markdown
## [3.2.0-alpha.2] - 2026-04-21

### Added
- Session-start hook injects a **Wake-word briefing** block: when the user's first message is just the AI's identity name (e.g., "Sarah"), the LLM responds with a session briefing (last narrative, reminders due, pending rule suggestions, what's next) instead of silent acknowledgement. Gated on `name != "Companion"` and on the ecosystem being present.
- Session-start hook injects a **Tier-loader phrase catalog**: natural-language phrases like `load rules`, `load memory`, `load archetype` map to the corresponding `npx @aman_asmuei/*` installer. LLM shells out via Bash when the user says one of the phrases.

Both are additive; users who never trigger them see identical behavior to 3.2.0-alpha.1.

Inspired by the wake-word + tiered-discovery pattern in [Kiyoraka/Project-AI-MemoryCore](https://github.com/Kiyoraka/Project-AI-MemoryCore). See `docs/superpowers/specs/2026-04-21-wake-word-and-tier-loaders-design.md`.
```

- [ ] **Step 2: Bump aman-copilot to v0.5.0**

Edit `aman-copilot/package.json` — change the `"version": "..."` field to `"0.5.0"`. (Verify current version first: `jq -r .version /Users/aman-asmuei/project-aman/aman-copilot/package.json`)

Add to `aman-copilot/CHANGELOG.md`:

```markdown
## [0.5.0] - 2026-04-21

### Added
- `aman-copilot init` now injects two new sections into `copilot-instructions.md`:
  - **Wake-word briefing**: Copilot responds with a session briefing when the user's first message is just the AI's name. Adapted bullet 4 references an inline "suggestions pending" line (Copilot has no `<aman-suggestion-notice>` hook tag).
  - **Tier upgrades — natural-language loaders**: catalog mapping `load rules`, `load memory`, etc. to `npx @aman_asmuei/*` installers.

Parity with `aman-claude-code` v3.2.0-alpha.2. Re-run `aman-copilot init` to pick up both blocks.

See `../aman-plugin/docs/superpowers/specs/2026-04-21-wake-word-and-tier-loaders-design.md`.
```

- [ ] **Step 3: Commit and tag**

```bash
cd /Users/aman-asmuei/project-aman/aman-plugin
git add .claude-plugin/plugin.json CHANGELOG.md
git commit -m "chore: bump to 3.2.0-alpha.2 — wake-word + tier loaders"

cd /Users/aman-asmuei/project-aman/aman-copilot
git add package.json CHANGELOG.md
git commit -m "chore: bump to 0.5.0 — wake-word + tier loaders"
```

**Do NOT push or tag without explicit user instruction.** Per the user's memory: "never npm publish locally; always use CI/CD (tag push or GitHub Release trigger)". If the user wants to publish, they will tag and push themselves.

---

## Open questions from spec §9 to resolve during execution

1. **`aman-copilot init` rendering mechanism** — RESOLVED during plan writing: it uses `sections.push(...strings)` + `sections.join("\n")`. Each string element becomes one line. The plan's Task B1 step 4 embeds this assumption correctly.

2. **Does `akit add` prompt interactively or fail-fast on missing arg?** — UNRESOLVED. Block B rule #2 tells the LLM to ask "which kit?" before running. This works regardless of `akit` behavior, so it's safe. If during Task C1 smoke test #6 the LLM behavior reveals akit also prompts interactively (making the "ask which" redundant but harmless), document as a note on the CHANGELOG entry — no code change required.

3. **Block A bullet 4 on Copilot with embedded suggestion-notice** — OUT OF SCOPE per spec §4.2. Do not implement in this plan. If Copilot later starts embedding passive-observer output, the Block A prose can be amended in a follow-up spec.

---

## Success criteria (all must be true before calling this plan done)

- [ ] All tests in `aman-plugin/test/test-hook.sh` pass, including the 3 new test groups added in Tasks A1-A3.
- [ ] All tests in `aman-copilot/test/test.sh` pass, including the new test group added in Task B1.
- [ ] Both repos have one commit per task (5 commits in aman-plugin, 2 in aman-copilot, plus 2 version-bump commits — 9 total across both repos).
- [ ] Manual smoke tests 1-7 from Phase C Task C1 Step 2 all behave as expected on real dev machine.
- [ ] No changes to `aman/` or any other ecosystem package.
- [ ] Version bumps in place but nothing published / tagged / pushed without user go-ahead.
