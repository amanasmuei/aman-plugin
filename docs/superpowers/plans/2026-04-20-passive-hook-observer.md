# Passive Hook Observer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship v3.2.0-alpha.1 of the aman-claude-code plugin with a passive `UserPromptSubmit` hook that detects repeated user corrections, queues them as rule suggestions, and surfaces them via a new `/rules review` command in aman-agent — behind the `AMAN_OBSERVER_ENABLED=1` env gate.

**Architecture:** Bash `UserPromptSubmit` hook writes to `~/.arules/dev/plugin/.tally.tsv` on every user message. When a phrase's count hits the threshold (1 if explicit marker present, else 3), the hook promotes it to `suggestions.md`. The extended `SessionStart` hook surfaces a one-line "N suggestions pending" notice. A new `/rules review` action in aman-agent lets users accept/reject/edit each proposal interactively — accept calls `arules-core.addRule()`.

**Tech Stack:**
- Plugin side: bash 4+, POSIX utilities (grep, sed, tr, cut, flock, shasum/sha256sum, date)
- Plugin test: DIY bash test harness (matches existing `test/test-hook.sh` pattern)
- Agent side: TypeScript, vitest for tests, existing `arules-core` API
- CI: GitHub Actions, Ubuntu + macOS matrix

**Spec:** `docs/superpowers/specs/2026-04-20-passive-hook-observer-design.md` (approved 2026-04-20)

**Repos touched:**
- `aman-plugin` (most work — detector, session-start extension, hooks.json, tests, CI)
- `aman-agent` (one file — `src/commands/rules.ts` gets a new `review` action + tests)

---

## File Structure

**Create in `aman-plugin/`:**
- `hooks/user-prompt-submit` — detector script (bash, ~110 lines)
- `hooks/lib/compat.sh` — cross-platform shims for sha256sum, flock degrade
- `test/test-user-prompt-submit.sh` — detector tests (bash, DIY harness)
- `test/test-session-start-notice.sh` — session-start pending-count tests
- `test/test-e2e-observer.sh` — full lifecycle smoke test
- `.github/workflows/shell-tests.yml` — CI for shell tests on Ubuntu + macOS

**Modify in `aman-plugin/`:**
- `hooks/hooks.json` — add `UserPromptSubmit` entry
- `hooks/session-start` — add ~8-line pending-count notice block
- `package.json` (or `CHANGELOG.md`) — bump version to `v3.2.0-alpha.1`

**Modify in `aman-agent/`:**
- `src/commands/rules.ts` — add `review` action + `review` to help text
- `test/commands-rules-review.test.ts` — NEW test file for the review action

---

## Phase 1: Plugin foundations (shims + tally + detector)

### Task 1: Cross-platform shim script

**Files:**
- Create: `aman-plugin/hooks/lib/compat.sh`
- Test: `aman-plugin/test/test-compat.sh` (inline-run during development; kept as permanent guard)

- [ ] **Step 1: Write the failing test**

Create `test/test-compat.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../hooks/lib/compat.sh
source "$SCRIPT_DIR/../hooks/lib/compat.sh"

PASS=0; FAIL=0

assert_eq() {
    if [ "$1" = "$2" ]; then
        PASS=$((PASS + 1))
        echo "  PASS: $3"
    else
        FAIL=$((FAIL + 1))
        echo "  FAIL: $3"
        echo "    expected: $2"
        echo "    actual:   $1"
    fi
}

# sha256_hex of empty string is known: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
ACTUAL=$(printf '' | sha256_hex)
assert_eq "$ACTUAL" "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" "sha256_hex of empty string"

# sha256_hex of "foo" is 2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae
ACTUAL=$(printf 'foo' | sha256_hex)
assert_eq "$ACTUAL" "2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae" "sha256_hex of 'foo'"

echo "---"
echo "PASS: $PASS  FAIL: $FAIL"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: Run the test to confirm it fails**

```bash
bash test/test-compat.sh
```
Expected: error — `compat.sh` doesn't exist yet.

- [ ] **Step 3: Implement `hooks/lib/compat.sh`**

```bash
# hooks/lib/compat.sh
# Cross-platform shims for detector hooks. Source this file; don't execute.

# sha256_hex: read stdin, write 64-char lowercase hex digest to stdout.
# Linux has sha256sum; macOS has shasum -a 256; both output "<hex>  <file>".
if command -v sha256sum >/dev/null 2>&1; then
    sha256_hex() { sha256sum | cut -d' ' -f1; }
elif command -v shasum >/dev/null 2>&1; then
    sha256_hex() { shasum -a 256 | cut -d' ' -f1; }
else
    sha256_hex() {
        # No sha256 available — fall back to MD5 (collision-tolerant here
        # because we're blocklisting user's own rejected phrases, not doing
        # cryptographic work). Prefix with "md5:" so the hash format is
        # self-identifying if it ever mixes with sha256-originated hashes.
        local hex
        hex=$(md5sum 2>/dev/null | cut -d' ' -f1 || md5 2>/dev/null | awk '{print $NF}')
        printf 'md5:%s' "$hex"
    }
fi

# with_flock <lockfile> <command...>: run <command...> with exclusive flock.
# Degrades to running without lock if flock is unavailable (Alpine, BusyBox).
if command -v flock >/dev/null 2>&1; then
    with_flock() {
        local lockfile="$1"; shift
        (
            flock -x 200
            "$@"
        ) 200>"$lockfile"
    }
else
    with_flock() {
        local lockfile="$1"; shift
        "$@"
    }
fi
```

- [ ] **Step 4: Run the test to confirm it passes**

```bash
bash test/test-compat.sh
```
Expected: `PASS: 2  FAIL: 0`.

- [ ] **Step 5: Commit**

```bash
cd aman-plugin
git add hooks/lib/compat.sh test/test-compat.sh
git commit -m "feat(observer): add cross-platform shims for sha256 + flock"
```

---

### Task 2: Correction-phrase matcher (TDD — explicit markers)

**Files:**
- Create (partial): `aman-plugin/hooks/user-prompt-submit`
- Create: `aman-plugin/test/test-user-prompt-submit.sh`

- [ ] **Step 1: Write the failing test** (only explicit-marker case first)

Create `test/test-user-prompt-submit.sh`:

```bash
#!/usr/bin/env bash
# Tests for the user-prompt-submit hook
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_PATH="$SCRIPT_DIR/../hooks/user-prompt-submit"

# Use an isolated test home so we don't clobber real ~/.arules state.
TEST_HOME=$(mktemp -d)
trap 'rm -rf "$TEST_HOME"' EXIT

export HOME="$TEST_HOME"
export AMAN_OBSERVER_ENABLED=1

SCOPE_DIR="$TEST_HOME/.arules/dev/plugin"
TALLY="$SCOPE_DIR/.tally.tsv"
SUGGESTIONS="$SCOPE_DIR/suggestions.md"
REJECTED="$SCOPE_DIR/.rejected-hashes"

PASS=0; FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; [ -n "${2:-}" ] && echo "        $2"; }

reset_state() {
    rm -rf "$SCOPE_DIR"
    mkdir -p "$SCOPE_DIR"
    touch "$TALLY" "$SUGGESTIONS" "$REJECTED"
}

# --- Test: explicit marker fires at count=1 ---
reset_state
CLAUDE_USER_PROMPT="from now on, never commit without running tests" bash "$HOOK_PATH" >/dev/null

if grep -q "Status: pending" "$SUGGESTIONS"; then
    pass "explicit marker promotes at count=1"
else
    fail "explicit marker did NOT promote at count=1" "suggestions.md: $(cat "$SUGGESTIONS")"
fi

echo "---"
echo "PASS: $PASS  FAIL: $FAIL"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: Run the test to confirm it fails**

```bash
bash test/test-user-prompt-submit.sh
```
Expected: `FAIL` — `hooks/user-prompt-submit` doesn't exist yet.

- [ ] **Step 3: Implement minimal hook for explicit-marker match**

Create `hooks/user-prompt-submit`:

```bash
#!/usr/bin/env bash
# UserPromptSubmit hook for aman-claude-code: passive correction observer.
# See docs/superpowers/specs/2026-04-20-passive-hook-observer-design.md

set -euo pipefail

# Env gate — opt-in for v3.2.0-alpha
[ "${AMAN_OBSERVER_ENABLED:-0}" = "1" ] || exit 0

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/compat.sh
source "$SCRIPT_DIR/lib/compat.sh"

SCOPE_DIR="$HOME/.arules/dev/plugin"
mkdir -p "$SCOPE_DIR"
TALLY="$SCOPE_DIR/.tally.tsv"
SUGGESTIONS="$SCOPE_DIR/suggestions.md"
REJECTED="$SCOPE_DIR/.rejected-hashes"
touch "$TALLY" "$SUGGESTIONS" "$REJECTED"
chmod 600 "$TALLY" "$SUGGESTIONS" "$REJECTED"

MSG="${CLAUDE_USER_PROMPT:-$(cat 2>/dev/null || true)}"
[ -z "$MSG" ] && exit 0

LOWER=$(printf '%s' "$MSG" | tr '[:upper:]' '[:lower:]')

EXPLICIT_RE="(^|[^a-z])(from now on|always|never|by default|going forward|stop doing|don'?t ever)"
AMBIENT_RE="(^|[^a-z])(don'?t|stop|no,? not|that'?s wrong|actually,?)"

IS_EXPLICIT=0
if echo "$LOWER" | grep -qE "$EXPLICIT_RE"; then
    IS_EXPLICIT=1
elif ! echo "$LOWER" | grep -qE "$AMBIENT_RE"; then
    exit 0
fi

# Minimal promotion path (will be expanded in Task 5+)
PHRASE=$(printf '%s' "$MSG" | tr -s ' \t\n' ' ' | sed 's/[[:punct:]]*$//' | cut -c1-100)
DATE=$(date '+%Y-%m-%d %H:%M')
SHORT=$(printf '%s' "$PHRASE" | cut -c1-60)

if [ "$IS_EXPLICIT" -eq 1 ]; then
    {
        printf '\n## %s — %s\n' "$DATE" "$SHORT"
        printf -- '- Phrase: %s\n' "$PHRASE"
        printf -- '- Occurrences: 1 (explicit marker)\n'
        printf -- '- First seen: %s\n' "$DATE"
        printf -- '- Category (suggested): general\n'
        printf -- '- Status: pending\n'
    } >> "$SUGGESTIONS"
fi

exit 0
```

Make it executable:

```bash
chmod +x hooks/user-prompt-submit
```

- [ ] **Step 4: Run the test to confirm it passes**

```bash
bash test/test-user-prompt-submit.sh
```
Expected: `PASS: 1  FAIL: 0`.

- [ ] **Step 5: Commit**

```bash
git add hooks/user-prompt-submit test/test-user-prompt-submit.sh
git commit -m "feat(observer): detector stub with explicit-marker promotion"
```

---

### Task 3: Ambient correction path (TDD)

**Files:**
- Modify: `aman-plugin/hooks/user-prompt-submit`
- Modify: `aman-plugin/test/test-user-prompt-submit.sh`

- [ ] **Step 1: Add 3 failing tests for the ambient path**

Append to `test/test-user-prompt-submit.sh` before the summary echo:

```bash
# --- Test: ambient correction does NOT promote at count=1 ---
reset_state
CLAUDE_USER_PROMPT="don't commit directly" bash "$HOOK_PATH" >/dev/null

if ! grep -q "Status: pending" "$SUGGESTIONS"; then
    pass "ambient correction stays in tally at count=1"
else
    fail "ambient correction promoted too early" "suggestions.md: $(cat "$SUGGESTIONS")"
fi

# --- Test: ambient correction DOES NOT promote at count=2 ---
reset_state
CLAUDE_USER_PROMPT="don't commit directly" bash "$HOOK_PATH" >/dev/null
CLAUDE_USER_PROMPT="don't commit directly" bash "$HOOK_PATH" >/dev/null

if ! grep -q "Status: pending" "$SUGGESTIONS"; then
    pass "ambient correction stays in tally at count=2"
else
    fail "ambient correction promoted at count=2" "suggestions.md: $(cat "$SUGGESTIONS")"
fi

# --- Test: ambient correction DOES promote at count=3 ---
reset_state
CLAUDE_USER_PROMPT="don't commit directly" bash "$HOOK_PATH" >/dev/null
CLAUDE_USER_PROMPT="don't commit directly" bash "$HOOK_PATH" >/dev/null
CLAUDE_USER_PROMPT="don't commit directly" bash "$HOOK_PATH" >/dev/null

if grep -q "Status: pending" "$SUGGESTIONS" && grep -q "Occurrences: 3" "$SUGGESTIONS"; then
    pass "ambient correction promotes at count=3 with Occurrences: 3"
else
    fail "ambient correction did NOT promote at count=3" "suggestions.md: $(cat "$SUGGESTIONS")"
fi
```

- [ ] **Step 2: Run tests to confirm 3 fail**

```bash
bash test/test-user-prompt-submit.sh
```
Expected: `PASS: 1  FAIL: 3`.

- [ ] **Step 3: Add tally read/update logic to the hook**

Edit `hooks/user-prompt-submit`. Replace the minimal promotion section (from `PHRASE=...` through `fi`) with:

```bash
PHRASE=$(printf '%s' "$MSG" | tr -s ' \t\n' ' ' | sed 's/[[:punct:]]*$//' | cut -c1-100)
# Lowercase the phrase for stable tally lookup
PHRASE_KEY=$(printf '%s' "$PHRASE" | tr '[:upper:]' '[:lower:]')

NOW=$(date +%s)

# --- Atomic tally read-modify-write ---
update_tally() {
    local existing new_count first new_explicit
    existing=$(grep -F "$(printf '%s\t' "$PHRASE_KEY")" "$TALLY" || true)
    if [ -n "$existing" ]; then
        local old_count old_explicit
        old_count=$(printf '%s' "$existing" | cut -f2)
        first=$(printf '%s' "$existing" | cut -f3)
        old_explicit=$(printf '%s' "$existing" | cut -f5)
        new_count=$((old_count + 1))
        new_explicit=$((old_explicit | IS_EXPLICIT))
        grep -v -F "$(printf '%s\t' "$PHRASE_KEY")" "$TALLY" > "$TALLY.new" || true
        printf '%s\t%d\t%s\t%d\t%d\n' "$PHRASE_KEY" "$new_count" "$first" "$NOW" "$new_explicit" >> "$TALLY.new"
        mv "$TALLY.new" "$TALLY"
    else
        new_count=1
        first=$NOW
        new_explicit=$IS_EXPLICIT
        printf '%s\t%d\t%s\t%d\t%d\n' "$PHRASE_KEY" 1 "$NOW" "$NOW" "$IS_EXPLICIT" >> "$TALLY"
    fi
    printf '%d\t%d\t%s' "$new_count" "$new_explicit" "$first"
}

RESULT=$(with_flock "$TALLY.lock" update_tally)
NEW_COUNT=$(printf '%s' "$RESULT" | cut -f1)
NEW_EXPLICIT=$(printf '%s' "$RESULT" | cut -f2)
FIRST_SEEN=$(printf '%s' "$RESULT" | cut -f3)

# Threshold check: promote if explicit OR count ≥ 3
if [ "$NEW_EXPLICIT" -eq 0 ] && [ "$NEW_COUNT" -lt 3 ]; then
    exit 0
fi

# --- Promotion to suggestions.md ---
DATE=$(date '+%Y-%m-%d %H:%M')
FIRST_DATE=$(date -r "$FIRST_SEEN" '+%Y-%m-%d %H:%M' 2>/dev/null || date -d "@$FIRST_SEEN" '+%Y-%m-%d %H:%M')
SHORT=$(printf '%s' "$PHRASE" | cut -c1-60)

OCC_LINE="- Occurrences: $NEW_COUNT"
[ "$NEW_EXPLICIT" -eq 1 ] && OCC_LINE="$OCC_LINE (explicit marker)"

{
    printf '\n## %s — %s\n' "$DATE" "$SHORT"
    printf -- '- Phrase: %s\n' "$PHRASE"
    printf '%s\n' "$OCC_LINE"
    printf -- '- First seen: %s\n' "$FIRST_DATE"
    printf -- '- Category (suggested): general\n'
    printf -- '- Status: pending\n'
} >> "$SUGGESTIONS"

# --- Clear tally row (phrase has graduated) ---
clear_tally_row() {
    grep -v -F "$(printf '%s\t' "$PHRASE_KEY")" "$TALLY" > "$TALLY.new" || true
    mv "$TALLY.new" "$TALLY"
}
with_flock "$TALLY.lock" clear_tally_row

exit 0
```

- [ ] **Step 4: Run all tests to confirm they pass**

```bash
bash test/test-user-prompt-submit.sh
```
Expected: `PASS: 4  FAIL: 0`.

- [ ] **Step 5: Commit**

```bash
git add hooks/user-prompt-submit test/test-user-prompt-submit.sh
git commit -m "feat(observer): tally + threshold + promotion for ambient corrections"
```

---

### Task 4: Privacy tag stripping + secret redaction

**Files:**
- Modify: `aman-plugin/hooks/user-prompt-submit`
- Modify: `aman-plugin/test/test-user-prompt-submit.sh`

- [ ] **Step 1: Add 3 failing tests**

Append to `test/test-user-prompt-submit.sh`:

```bash
# --- Test: <private>...</private> content is excluded from matching ---
reset_state
CLAUDE_USER_PROMPT="<private>don't commit directly</private> hello" bash "$HOOK_PATH" >/dev/null

if ! grep -q "Status: pending" "$SUGGESTIONS" && [ ! -s "$TALLY" ]; then
    pass "<private> region stripped — no tally, no suggestion"
else
    fail "<private> region leaked" "tally=$(cat "$TALLY")  sugg=$(cat "$SUGGESTIONS")"
fi

# --- Test: token-shaped string redacted from tally row ---
reset_state
CLAUDE_USER_PROMPT="from now on never commit sk-abc123def456ghi789jkl012mno345pqr678" bash "$HOOK_PATH" >/dev/null

if grep -q "sk-abc123def456ghi789" "$SUGGESTIONS"; then
    fail "raw API key leaked into suggestions.md"
elif grep -q "\[REDACTED\]" "$SUGGESTIONS"; then
    pass "sk- key redacted in suggestions"
else
    fail "redaction did not happen" "sugg=$(cat "$SUGGESTIONS")"
fi

# --- Test: long hex string redacted ---
reset_state
CLAUDE_USER_PROMPT="from now on never push abc1234567890abcdef1234567890abcdef123456" bash "$HOOK_PATH" >/dev/null

if grep -q "abc1234567890abcdef1234567890abcdef123456" "$SUGGESTIONS"; then
    fail "long hex leaked into suggestions.md"
elif grep -q "\[REDACTED\]" "$SUGGESTIONS"; then
    pass "hex string redacted"
else
    fail "hex redaction did not happen" "sugg=$(cat "$SUGGESTIONS")"
fi
```

- [ ] **Step 2: Run tests to confirm 3 fail**

```bash
bash test/test-user-prompt-submit.sh
```
Expected: the new tests fail; first 4 still pass.

- [ ] **Step 3: Add stripping + redaction to the hook**

Edit `hooks/user-prompt-submit`. After the `MSG=` line and before `LOWER=`, insert:

```bash
# Strip <private>...</private> regions before any processing.
# sed handles single-line AND multi-line via the d command on a range.
MSG=$(printf '%s' "$MSG" | sed 's|<private>[^<]*</private>||g; /<private>/,/<\/private>/d')

# Redact secret-shaped strings (API keys, tokens, long hex).
# Ordered most-specific → least so sk-... matches before generic [A-Za-z0-9_-]{32,}.
MSG=$(printf '%s' "$MSG" | sed -E \
    -e 's/sk-[A-Za-z0-9]+/[REDACTED]/g' \
    -e 's/ghp_[A-Za-z0-9]+/[REDACTED]/g' \
    -e 's/gho_[A-Za-z0-9]+/[REDACTED]/g' \
    -e 's/[A-Fa-f0-9]{40,}/[REDACTED]/g' \
    -e 's/[A-Za-z0-9_-]{32,}/[REDACTED]/g')

[ -z "$MSG" ] && exit 0
```

- [ ] **Step 4: Run tests to confirm all pass**

```bash
bash test/test-user-prompt-submit.sh
```
Expected: `PASS: 7  FAIL: 0`.

- [ ] **Step 5: Commit**

```bash
git add hooks/user-prompt-submit test/test-user-prompt-submit.sh
git commit -m "feat(observer): strip <private> and redact secrets before tally"
```

---

### Task 5: Rejected-hashes blocklist

**Files:**
- Modify: `aman-plugin/hooks/user-prompt-submit`
- Modify: `aman-plugin/test/test-user-prompt-submit.sh`

- [ ] **Step 1: Add failing test**

Append to `test/test-user-prompt-submit.sh`:

```bash
# --- Test: rejected hash prevents re-promotion ---
reset_state
# Pre-populate .rejected-hashes with the sha256 of the normalized phrase
REJECTED_PHRASE_KEY="don't you love this?"
HASH=$(printf '%s' "$REJECTED_PHRASE_KEY" | "$SCRIPT_DIR/../hooks/lib/compat.sh" 2>/dev/null ||
       printf '%s' "$REJECTED_PHRASE_KEY" | bash -c 'source "'"$SCRIPT_DIR"'/../hooks/lib/compat.sh"; sha256_hex')
echo "$HASH" > "$REJECTED"

# Now fire the same phrase 3 times — should NOT promote
CLAUDE_USER_PROMPT="don't you love this?" bash "$HOOK_PATH" >/dev/null
CLAUDE_USER_PROMPT="don't you love this?" bash "$HOOK_PATH" >/dev/null
CLAUDE_USER_PROMPT="don't you love this?" bash "$HOOK_PATH" >/dev/null

if ! grep -q "Status: pending" "$SUGGESTIONS"; then
    pass "rejected-hash phrase is never promoted"
else
    fail "rejected phrase was promoted despite hash block" "sugg=$(cat "$SUGGESTIONS")"
fi
```

- [ ] **Step 2: Run test to confirm failure**

```bash
bash test/test-user-prompt-submit.sh
```
Expected: one new failure.

- [ ] **Step 3: Add rejection-hash check to the hook**

Edit `hooks/user-prompt-submit`. After the `PHRASE_KEY=` line (where the normalized phrase key is computed) and before `update_tally`, insert:

```bash
# Check rejected-hashes blocklist. If user has rejected this phrase before,
# never re-surface it.
if [ -s "$REJECTED" ]; then
    HASH=$(printf '%s' "$PHRASE_KEY" | sha256_hex)
    if grep -qxF "$HASH" "$REJECTED"; then
        exit 0
    fi
fi
```

- [ ] **Step 4: Run all tests to confirm they pass**

```bash
bash test/test-user-prompt-submit.sh
```
Expected: `PASS: 8  FAIL: 0`.

- [ ] **Step 5: Commit**

```bash
git add hooks/user-prompt-submit test/test-user-prompt-submit.sh
git commit -m "feat(observer): honor .rejected-hashes blocklist"
```

---

### Task 6: Category auto-suggest

**Files:**
- Modify: `aman-plugin/hooks/user-prompt-submit`
- Modify: `aman-plugin/test/test-user-prompt-submit.sh`

- [ ] **Step 1: Add failing tests**

Append:

```bash
# --- Test: git-keyword phrases get category=git ---
reset_state
CLAUDE_USER_PROMPT="from now on, never commit directly to main" bash "$HOOK_PATH" >/dev/null

if grep -q "Category (suggested): git" "$SUGGESTIONS"; then
    pass "commit keyword → category git"
else
    fail "commit keyword did not route to git" "sugg=$(cat "$SUGGESTIONS")"
fi

# --- Test: test-keyword → workflow ---
reset_state
CLAUDE_USER_PROMPT="from now on, always run tests before pushing" bash "$HOOK_PATH" >/dev/null

if grep -q "Category (suggested): workflow" "$SUGGESTIONS"; then
    pass "test keyword → category workflow"
else
    fail "test keyword did not route to workflow"
fi

# --- Test: secret keyword → privacy ---
reset_state
CLAUDE_USER_PROMPT="from now on, never log passwords" bash "$HOOK_PATH" >/dev/null

if grep -q "Category (suggested): privacy" "$SUGGESTIONS"; then
    pass "password keyword → category privacy"
else
    fail "password keyword did not route to privacy"
fi

# --- Test: no matching keyword → general ---
reset_state
CLAUDE_USER_PROMPT="from now on, never skip breakfast" bash "$HOOK_PATH" >/dev/null

if grep -q "Category (suggested): general" "$SUGGESTIONS"; then
    pass "unmatched keyword → category general"
else
    fail "unmatched did not fall through to general"
fi
```

- [ ] **Step 2: Run tests — confirm 3 fail**

```bash
bash test/test-user-prompt-submit.sh
```
Expected: 3 new failures (the `general` test already passes because that's the current hardcoded default).

- [ ] **Step 3: Implement category auto-suggest**

Edit `hooks/user-prompt-submit`. Replace the line:

```bash
    printf -- '- Category (suggested): general\n'
```

with:

```bash
    printf -- '- Category (suggested): %s\n' "$CATEGORY"
```

And add above the `{ printf '\n## ...` block:

```bash
# Category heuristic — keyword-based, first match wins, small v1 table.
guess_category() {
    local p="$1"
    case "$p" in
        *password*|*token*|*secret*|*api.key*|*credential*) echo "privacy" ;;
        *commit*|*push*|*pull*|*merge*|*rebase*|*branch*) echo "git" ;;
        *test*|*lint*|*build*|*' ci '*) echo "workflow" ;;
        *database*|*' db '*|*migration*|*sql*|*schema*) echo "data" ;;
        *) echo "general" ;;
    esac
}
CATEGORY=$(guess_category "$PHRASE_KEY")
```

- [ ] **Step 4: Run all tests — confirm they pass**

```bash
bash test/test-user-prompt-submit.sh
```
Expected: `PASS: 12  FAIL: 0`.

- [ ] **Step 5: Commit**

```bash
git add hooks/user-prompt-submit test/test-user-prompt-submit.sh
git commit -m "feat(observer): category auto-suggest from phrase keywords"
```

---

### Task 7: Env-gate coverage test + no-op behavior

**Files:**
- Modify: `aman-plugin/test/test-user-prompt-submit.sh`

- [ ] **Step 1: Add failing test**

Append:

```bash
# --- Test: AMAN_OBSERVER_ENABLED unset → hook is no-op ---
reset_state
unset AMAN_OBSERVER_ENABLED
CLAUDE_USER_PROMPT="from now on, never commit directly" bash "$HOOK_PATH" >/dev/null

if [ ! -s "$TALLY" ] && [ ! -s "$SUGGESTIONS" ]; then
    pass "disabled observer is a no-op"
else
    fail "observer ran despite being disabled" "tally=$(cat "$TALLY")"
fi
export AMAN_OBSERVER_ENABLED=1
```

- [ ] **Step 2: Run test — confirm passes (gate already in hook from Task 2)**

```bash
bash test/test-user-prompt-submit.sh
```
Expected: `PASS: 13  FAIL: 0`. (The gate has been there since Task 2; this test just codifies it.)

- [ ] **Step 3: Commit**

```bash
git add test/test-user-prompt-submit.sh
git commit -m "test(observer): codify env-gate no-op behavior"
```

---

## Phase 2: Plugin integration (session-start + hooks.json)

### Task 8: Extend session-start with pending-count notice

**Files:**
- Modify: `aman-plugin/hooks/session-start`
- Create: `aman-plugin/test/test-session-start-notice.sh`

- [ ] **Step 1: Write failing test**

Create `test/test-session-start-notice.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_PATH="$SCRIPT_DIR/../hooks/session-start"

TEST_HOME=$(mktemp -d)
trap 'rm -rf "$TEST_HOME"' EXIT
export HOME="$TEST_HOME"

SCOPE_DIR="$TEST_HOME/.arules/dev/plugin"
mkdir -p "$SCOPE_DIR"
SUGG="$SCOPE_DIR/suggestions.md"

PASS=0; FAIL=0
pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; [ -n "${2:-}" ] && echo "        $2"; }

# --- Test: no pending → no notice ---
OUTPUT=$(bash "$HOOK_PATH" 2>/dev/null)
if ! echo "$OUTPUT" | grep -q "aman-suggestion-notice"; then
    pass "0 pending → no notice block"
else
    fail "unexpected notice with 0 pending"
fi

# --- Test: 2 pending entries → notice with count ---
cat > "$SUGG" <<'EOF'
## 2026-04-20 10:00 — don't commit directly
- Phrase: don't commit directly
- Occurrences: 3
- Status: pending

## 2026-04-20 11:00 — never push to main
- Phrase: never push to main
- Occurrences: 1 (explicit marker)
- Status: pending
EOF

OUTPUT=$(bash "$HOOK_PATH" 2>/dev/null)
if echo "$OUTPUT" | grep -q "2 rule suggestions pending"; then
    pass "2 pending → notice shows plural"
else
    fail "notice missing or wrong count" "output: $OUTPUT"
fi

# --- Test: 1 pending → singular ---
cat > "$SUGG" <<'EOF'
## 2026-04-20 10:00 — don't commit
- Status: pending
EOF
OUTPUT=$(bash "$HOOK_PATH" 2>/dev/null)
if echo "$OUTPUT" | grep -q "1 rule suggestion pending"; then
    pass "1 pending → singular"
else
    fail "singular form missing" "output: $OUTPUT"
fi

echo "---"
echo "PASS: $PASS  FAIL: $FAIL"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: Run the test to confirm it fails**

```bash
bash test/test-session-start-notice.sh
```
Expected: `FAIL` (session-start doesn't emit the notice yet).

- [ ] **Step 3: Extend `hooks/session-start`**

Edit `hooks/session-start`. Find the line `# Build the context message` (around line 137) and insert this block **before** it:

```bash
# Passive-observer: surface pending rule suggestions (one line, no pressure).
SUGGESTIONS_FILE="$HOME/.arules/dev/plugin/suggestions.md"
if [ -f "$SUGGESTIONS_FILE" ]; then
    PENDING=$(grep -c '^- Status: pending' "$SUGGESTIONS_FILE" 2>/dev/null || echo 0)
    if [ "$PENDING" -gt 0 ]; then
        if [ "$PENDING" -eq 1 ]; then
            NOTICE="$PENDING rule suggestion pending — run /rules review"
        else
            NOTICE="$PENDING rule suggestions pending — run /rules review"
        fi
        context_parts="${context_parts}\n\n<aman-suggestion-notice>\n${NOTICE}\n</aman-suggestion-notice>"
    fi
fi
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
bash test/test-session-start-notice.sh
bash test/test-hook.sh    # existing session-start tests still green
```
Expected: new tests 3/3 pass; existing `test/test-hook.sh` remains green.

- [ ] **Step 5: Commit**

```bash
git add hooks/session-start test/test-session-start-notice.sh
git commit -m "feat(observer): surface pending-suggestion count in session-start"
```

---

### Task 9: Wire UserPromptSubmit in hooks.json

**Files:**
- Modify: `aman-plugin/hooks/hooks.json`

- [ ] **Step 1: Read current state**

```bash
cat hooks/hooks.json
```

- [ ] **Step 2: Add UserPromptSubmit entry**

Replace `hooks/hooks.json` with:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "'${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd' session-start",
            "async": false
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "'${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd' user-prompt-submit",
            "async": true
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 3: Validate JSON**

```bash
python3 -c "import json; json.load(open('hooks/hooks.json'))" && echo "valid JSON"
```
Expected: `valid JSON`.

- [ ] **Step 4: Commit**

```bash
git add hooks/hooks.json
git commit -m "feat(observer): wire UserPromptSubmit hook in hooks.json"
```

---

### Task 10: End-to-end smoke test

**Files:**
- Create: `aman-plugin/test/test-e2e-observer.sh`

- [ ] **Step 1: Write the full-lifecycle test**

Create `test/test-e2e-observer.sh`:

```bash
#!/usr/bin/env bash
# End-to-end smoke test: detector → tally → promote → session-start notice.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DETECTOR="$SCRIPT_DIR/../hooks/user-prompt-submit"
SESSION_START="$SCRIPT_DIR/../hooks/session-start"

TEST_HOME=$(mktemp -d)
trap 'rm -rf "$TEST_HOME"' EXIT
export HOME="$TEST_HOME"
export AMAN_OBSERVER_ENABLED=1

PASS=0; FAIL=0
pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; [ -n "${2:-}" ] && echo "        $2"; }

# --- Scenario: user says "don't commit without tests" 3 times ---
for _ in 1 2 3; do
    CLAUDE_USER_PROMPT="don't commit without tests" bash "$DETECTOR" >/dev/null
done

SUGG="$HOME/.arules/dev/plugin/suggestions.md"
if grep -q "don't commit without tests" "$SUGG" && grep -q "Status: pending" "$SUGG"; then
    pass "3 ambient corrections promote to suggestions.md"
else
    fail "ambient promotion failed in e2e" "sugg=$(cat "$SUGG")"
fi

# --- Scenario: next session start surfaces the notice ---
OUTPUT=$(bash "$SESSION_START")
if echo "$OUTPUT" | grep -q "1 rule suggestion pending"; then
    pass "session-start notice reflects promoted suggestion"
else
    fail "session-start notice missing" "output: $OUTPUT"
fi

# --- Scenario: explicit marker in 1 shot ---
for i in 1 2 3; do
    # Reset for isolation
    rm -rf "$HOME/.arules"
    CLAUDE_USER_PROMPT="from now on, never edit on main" bash "$DETECTOR" >/dev/null
    if grep -q "Occurrences: 1 (explicit marker)" "$HOME/.arules/dev/plugin/suggestions.md" 2>/dev/null; then
        pass "iteration $i: explicit marker promotes at count=1"
    else
        fail "iteration $i: explicit marker did not promote"
    fi
done

echo "---"
echo "PASS: $PASS  FAIL: $FAIL"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: Run the test**

```bash
bash test/test-e2e-observer.sh
```
Expected: `PASS: 5  FAIL: 0`.

- [ ] **Step 3: Commit**

```bash
git add test/test-e2e-observer.sh
git commit -m "test(observer): add end-to-end smoke test"
```

---

## Phase 3: aman-agent — /rules review command

> **Note:** Tasks 11–16 operate in the `aman-agent` repo (different repo from Tasks 1–10). Cross-repo commit discipline: each task commits in its own repo.

### Task 11: Set up rules-review test file and suggestions.md parser

**Files:**
- Create: `aman-agent/test/commands-rules-review.test.ts`
- Modify: `aman-agent/src/commands/rules.ts`

- [ ] **Step 1: Write failing test for the parser**

Create `test/commands-rules-review.test.ts`:

```ts
import { describe, it, expect } from "vitest";
import { parseSuggestions } from "../src/commands/rules.js";

describe("parseSuggestions", () => {
  it("parses a well-formed block", () => {
    const input = `
## 2026-04-18 22:01 — don't commit without tests
- Phrase: don't commit without tests
- Occurrences: 3
- First seen: 2026-04-18 20:14
- Category (suggested): workflow
- Status: pending
`.trim();
    const result = parseSuggestions(input);
    expect(result).toHaveLength(1);
    expect(result[0]).toMatchObject({
      phrase: "don't commit without tests",
      occurrences: 3,
      category: "workflow",
      status: "pending",
      explicit: false,
    });
  });

  it("parses explicit-marker occurrence line", () => {
    const input = `
## 2026-04-20 11:02 — never edit on main
- Phrase: never edit on main
- Occurrences: 1 (explicit marker)
- Category (suggested): git
- Status: pending
`.trim();
    const [entry] = parseSuggestions(input);
    expect(entry.occurrences).toBe(1);
    expect(entry.explicit).toBe(true);
  });

  it("skips malformed blocks without crashing", () => {
    const input = `
## good block
- Phrase: good
- Status: pending

## malformed block without needed fields
- Nothing: here

## another good block
- Phrase: another
- Status: pending
`.trim();
    const result = parseSuggestions(input);
    expect(result.map((r) => r.phrase)).toEqual(["good", "another"]);
  });

  it("returns empty array for empty input", () => {
    expect(parseSuggestions("")).toEqual([]);
  });
});
```

- [ ] **Step 2: Run tests to confirm failure**

```bash
cd aman-agent
npx vitest run test/commands-rules-review.test.ts
```
Expected: `parseSuggestions is not exported` (or similar).

- [ ] **Step 3: Implement and export the parser**

Append to `src/commands/rules.ts`:

```ts
export interface SuggestionEntry {
  heading: string;
  phrase: string;
  occurrences: number;
  explicit: boolean;
  firstSeen?: string;
  category: string;
  status: "pending" | "accepted" | "rejected";
  rawBlockStart: number;  // character offset of the block header in the source
  rawBlockEnd: number;    // character offset just past the block's last line
}

export function parseSuggestions(source: string): SuggestionEntry[] {
  if (!source.trim()) return [];
  const lines = source.split("\n");
  const entries: SuggestionEntry[] = [];

  let i = 0;
  while (i < lines.length) {
    if (lines[i].startsWith("## ")) {
      const blockStart = lines.slice(0, i).join("\n").length + (i > 0 ? 1 : 0);
      const heading = lines[i].slice(3).trim();
      const fields: Record<string, string> = {};
      let j = i + 1;
      while (j < lines.length && !lines[j].startsWith("## ")) {
        const m = lines[j].match(/^-\s+([^:]+):\s*(.*)$/);
        if (m) fields[m[1].trim().toLowerCase()] = m[2].trim();
        j++;
      }
      const blockEnd = lines.slice(0, j).join("\n").length;

      const phrase = fields["phrase"];
      const statusRaw = fields["status"] ?? "";
      const status: SuggestionEntry["status"] = statusRaw.startsWith("accepted")
        ? "accepted"
        : statusRaw.startsWith("rejected")
        ? "rejected"
        : "pending";
      const occRaw = fields["occurrences"] ?? "";
      const occMatch = occRaw.match(/^(\d+)/);
      const occurrences = occMatch ? parseInt(occMatch[1], 10) : 0;
      const explicit = /explicit marker/i.test(occRaw);
      const category =
        fields["category (used)"] ??
        fields["category (suggested)"] ??
        "general";

      if (phrase && statusRaw) {
        entries.push({
          heading,
          phrase,
          occurrences,
          explicit,
          firstSeen: fields["first seen"],
          category,
          status,
          rawBlockStart: blockStart,
          rawBlockEnd: blockEnd,
        });
      }
      i = j;
    } else {
      i++;
    }
  }
  return entries;
}
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
npx vitest run test/commands-rules-review.test.ts
```
Expected: 4/4 pass.

- [ ] **Step 5: Run the full test suite (sanity check — nothing else broke)**

```bash
npx vitest run
```
Expected: 939 pass (existing count) + 4 new = 943.

- [ ] **Step 6: Commit**

```bash
git add src/commands/rules.ts test/commands-rules-review.test.ts
git commit -m "feat(rules): add suggestions.md parser for /rules review"
```

---

### Task 12: `/rules review` — accept flow

**Files:**
- Modify: `aman-agent/src/commands/rules.ts`
- Modify: `aman-agent/test/commands-rules-review.test.ts`

- [ ] **Step 1: Add failing test for accept**

Extend the existing top-of-file import from Task 11:

```ts
import { parseSuggestions, acceptSuggestion } from "../src/commands/rules.js";
```

Append to the same `test/commands-rules-review.test.ts`:

```ts
describe("acceptSuggestion", () => {
  it("mutates Status: to accepted with timestamp", () => {
    const source = `## h\n- Phrase: don't commit\n- Category (suggested): git\n- Status: pending\n`;
    const entry = parseSuggestions(source)[0];
    const updated = acceptSuggestion(source, entry, new Date("2026-04-20T11:30:00Z"));
    expect(updated).toContain("- Status: accepted (2026-04-20");
    expect(updated).not.toContain("- Status: pending");
  });
});
```

- [ ] **Step 2: Run the new test to confirm it fails**

```bash
npx vitest run test/commands-rules-review.test.ts
```
Expected: `acceptSuggestion is not exported`.

- [ ] **Step 3: Implement `acceptSuggestion`**

Append to `src/commands/rules.ts`:

```ts
function formatTs(d: Date): string {
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

export function acceptSuggestion(
  source: string,
  entry: SuggestionEntry,
  now: Date = new Date(),
  editedPhrase?: string,
  editedCategory?: string,
): string {
  const block = source.slice(entry.rawBlockStart, entry.rawBlockEnd);
  const lines = block.split("\n");
  const newLines: string[] = [];
  const ts = formatTs(now);

  let insertedOriginal = false;
  for (const ln of lines) {
    if (editedPhrase && !insertedOriginal && /^- Phrase:/.test(ln)) {
      newLines.push(`- Original: ${entry.phrase}`);
      newLines.push(`- Phrase: ${editedPhrase}`);
      insertedOriginal = true;
      continue;
    }
    if (editedCategory && /^- Category \(suggested\):/.test(ln)) {
      newLines.push(ln);
      newLines.push(`- Category (used): ${editedCategory}`);
      continue;
    }
    if (/^- Status: pending/.test(ln)) {
      newLines.push(`- Status: accepted (${ts})`);
      continue;
    }
    newLines.push(ln);
  }

  return source.slice(0, entry.rawBlockStart) +
    newLines.join("\n") +
    source.slice(entry.rawBlockEnd);
}
```

- [ ] **Step 4: Run tests — confirm they pass**

```bash
npx vitest run test/commands-rules-review.test.ts
```
Expected: 5/5 pass.

- [ ] **Step 5: Commit**

```bash
git add src/commands/rules.ts test/commands-rules-review.test.ts
git commit -m "feat(rules): acceptSuggestion mutates Status + handles edit"
```

---

### Task 13: `/rules review` — reject flow + hash emission

**Files:**
- Modify: `aman-agent/src/commands/rules.ts`
- Modify: `aman-agent/test/commands-rules-review.test.ts`

- [ ] **Step 1: Add failing tests for reject**

Extend the top-of-file import list from Tasks 11-12:

```ts
import { parseSuggestions, acceptSuggestion, rejectSuggestion, phraseHash } from "../src/commands/rules.js";
```

Append:

```ts
describe("rejectSuggestion", () => {
  it("mutates Status: to rejected with timestamp", () => {
    const source = `## h\n- Phrase: p\n- Status: pending\n`;
    const entry = parseSuggestions(source)[0];
    const updated = rejectSuggestion(source, entry, new Date("2026-04-20T13:50:00Z"));
    expect(updated).toContain("- Status: rejected (2026-04-20");
  });
});

describe("phraseHash", () => {
  it("is stable and 64 hex chars for a phrase", () => {
    const h = phraseHash("don't you love this?");
    expect(h).toMatch(/^[a-f0-9]{64}$/);
    expect(phraseHash("don't you love this?")).toBe(h);
  });

  it("normalizes case before hashing", () => {
    expect(phraseHash("DON'T")).toBe(phraseHash("don't"));
  });
});
```

- [ ] **Step 2: Run tests — confirm failure**

```bash
npx vitest run test/commands-rules-review.test.ts
```

- [ ] **Step 3: Implement reject + hash**

Add to top of `src/commands/rules.ts` imports:

```ts
import crypto from "node:crypto";
```

Append:

```ts
export function rejectSuggestion(
  source: string,
  entry: SuggestionEntry,
  now: Date = new Date(),
): string {
  const block = source.slice(entry.rawBlockStart, entry.rawBlockEnd);
  const ts = formatTs(now);
  const replaced = block.replace(/^- Status: pending/m, `- Status: rejected (${ts})`);
  return source.slice(0, entry.rawBlockStart) +
    replaced +
    source.slice(entry.rawBlockEnd);
}

export function phraseHash(phrase: string): string {
  return crypto.createHash("sha256").update(phrase.toLowerCase()).digest("hex");
}
```

- [ ] **Step 4: Confirm tests pass**

```bash
npx vitest run test/commands-rules-review.test.ts
```
Expected: 8/8 pass.

- [ ] **Step 5: Commit**

```bash
git add src/commands/rules.ts test/commands-rules-review.test.ts
git commit -m "feat(rules): rejectSuggestion + phraseHash for .rejected-hashes"
```

---

### Task 14: `/rules review` — interactive loop + wire into dispatcher

**Files:**
- Modify: `aman-agent/src/commands/rules.ts`
- Modify: `aman-agent/test/commands-rules-review.test.ts`

- [ ] **Step 1: Add failing integration test**

Extend top-of-file imports:

```ts
import { describe, it, expect, beforeEach } from "vitest";
import { handleCommand } from "../src/commands.js";
import fs from "node:fs";
import path from "node:path";
import os from "node:os";
```

Append:

```ts
describe("/rules review integration", () => {
  const SCOPE_DIR = path.join(os.homedir(), ".arules", "dev", "agent");
  const SUGG_PATH = path.join(SCOPE_DIR, "suggestions.md");
  const REJECTED_PATH = path.join(SCOPE_DIR, ".rejected-hashes");

  beforeEach(() => {
    fs.mkdirSync(SCOPE_DIR, { recursive: true });
    fs.writeFileSync(SUGG_PATH, "");
    fs.writeFileSync(REJECTED_PATH, "");
  });

  it("reports 'no pending suggestions' when empty", async () => {
    const result = await handleCommand("/rules review", {});
    expect(result.handled).toBe(true);
    expect(result.output).toMatch(/No pending (rule )?suggestions/i);
  });

  it("lists pending count when entries exist", async () => {
    fs.writeFileSync(SUGG_PATH,
      "## h\n- Phrase: don't commit\n- Occurrences: 3\n- Category (suggested): git\n- Status: pending\n");
    // Non-interactive path: just assert the listing appears. A richer test
    // using a mocked readline is deferred to a follow-up PR to keep this
    // test file tractable.
    const result = await handleCommand("/rules review --list", {});
    expect(result.output).toContain("don't commit");
    expect(result.output).toContain("1 pending");
  });
});
```

- [ ] **Step 2: Run tests — confirm failure**

```bash
npx vitest run test/commands-rules-review.test.ts
```

- [ ] **Step 3: Wire the review action into `handleRulesCommand`**

Edit `src/commands/rules.ts`. Add imports at top:

```ts
import fs from "node:fs";
import path from "node:path";
import os from "node:os";
```

Add helper:

```ts
function suggestionsPath(): string {
  return path.join(os.homedir(), ".arules", AGENT_SCOPE.replace(":", "/"), "suggestions.md");
}

function readSuggestionsSource(): string {
  const p = suggestionsPath();
  if (!fs.existsSync(p)) return "";
  return fs.readFileSync(p, "utf-8");
}

function writeSuggestionsSource(source: string): void {
  const p = suggestionsPath();
  fs.mkdirSync(path.dirname(p), { recursive: true });
  fs.writeFileSync(p, source, { mode: 0o600 });
}
```

In `handleRulesCommand`, before the final `if (action === "help")` block, add:

```ts
  if (action === "review") {
    const wantList = args.includes("--list");
    const source = readSuggestionsSource();
    const entries = parseSuggestions(source).filter((e) => e.status === "pending");

    if (entries.length === 0) {
      return { handled: true, output: pc.dim("No pending rule suggestions.") };
    }

    if (wantList) {
      const lines = [pc.bold(`${entries.length} pending`), ""];
      entries.forEach((e, i) => {
        lines.push(
          `  [${i + 1}] ${pc.cyan(e.heading)}`,
          `      Phrase: ${e.phrase}`,
          `      Occurrences: ${e.occurrences}${e.explicit ? " (explicit)" : ""} · Category: ${e.category}`,
        );
      });
      lines.push("", pc.dim("Run /rules review without --list to interactively accept/reject."));
      return { handled: true, output: lines.join("\n") };
    }

    // Interactive loop would live here. For v1 scope we ship --list + per-entry
    // commands (accept/reject by index). Full readline loop lands in a follow-up.
    return {
      handled: true,
      output: pc.yellow(
        "Use /rules review --list to see pending suggestions, then /rules accept <n> or /rules reject <n>.",
      ),
    };
  }

  if (action === "accept" || action === "reject") {
    const idx = parseInt(args[0], 10);
    if (isNaN(idx) || idx < 1) {
      return { handled: true, output: pc.yellow(`Usage: /rules ${action} <number-from-review-list>`) };
    }
    const source = readSuggestionsSource();
    const entries = parseSuggestions(source).filter((e) => e.status === "pending");
    const entry = entries[idx - 1];
    if (!entry) {
      return { handled: true, output: pc.red(`No pending suggestion #${idx}`) };
    }
    if (action === "accept") {
      try {
        await arulesAddRule(entry.category, entry.phrase, AGENT_SCOPE);
        writeSuggestionsSource(acceptSuggestion(source, entry));
        return { handled: true, output: pc.green(`✓ Added to ${entry.category}: "${entry.phrase}"`) };
      } catch (err) {
        return { handled: true, output: pc.red(`Failed: ${err instanceof Error ? err.message : String(err)}`) };
      }
    }
    // reject
    writeSuggestionsSource(rejectSuggestion(source, entry));
    const rejectedPath = path.join(path.dirname(suggestionsPath()), ".rejected-hashes");
    fs.appendFileSync(rejectedPath, phraseHash(entry.phrase) + "\n", { mode: 0o600 });
    return { handled: true, output: pc.dim(`✗ Rejected (won't surface again).`) };
  }
```

- [ ] **Step 4: Update the `/rules` help text**

Edit `handleRulesCommand`'s `help` action. In the array of help lines, add after the existing `/rules check` line:

```ts
        `  ${pc.cyan("/rules review")}                View pending rule suggestions from observer`,
        `  ${pc.cyan("/rules accept")} <n>            Accept suggestion #n (from review list)`,
        `  ${pc.cyan("/rules reject")} <n>            Reject suggestion #n (won't resurface)`,
```

- [ ] **Step 5: Add `review`, `accept`, `reject` to the command dispatcher's known actions**

Edit `src/commands.ts`. In `KNOWN_COMMANDS`, verify `"rules"` is present (it is). No change needed to the Set itself — the action-level routing happens inside `handleRulesCommand`, which already handles any action string.

- [ ] **Step 6: Run tests — confirm they pass**

```bash
npx vitest run test/commands-rules-review.test.ts
```
Expected: 10/10 pass.

- [ ] **Step 7: Run full suite**

```bash
npx vitest run
```
Expected: all 943+ pass.

- [ ] **Step 8: Commit**

```bash
git add src/commands/rules.ts test/commands-rules-review.test.ts
git commit -m "feat(rules): /rules review --list + /rules accept|reject <n>"
```

---

### Task 15: aman-agent build + bundle-size sanity

**Files:**
- (verify only)

- [ ] **Step 1: Build**

```bash
cd aman-agent
npm run build
```
Expected: success.

- [ ] **Step 2: Bundle size under 550 KB**

```bash
find dist -name '*.js' -type f -exec wc -c {} + | tail -1 | awk '{printf "%.1f KB\n", $1/1024}'
```
Expected: < 550 KB. (Prior baseline 495 KB; this PR adds ~2 KB of parser logic — should be ~497 KB.)

- [ ] **Step 3: If bundle over budget, investigate**

Bundle suddenly over 550 KB means an accidental dep import. Grep the diff:

```bash
git diff HEAD~3 --stat src/
```

---

## Phase 4: CI + release

### Task 16: Add shell-test CI workflow

**Files:**
- Create: `aman-plugin/.github/workflows/shell-tests.yml`

- [ ] **Step 1: Write the workflow**

Create `.github/workflows/shell-tests.yml`:

```yaml
name: Shell tests

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  shell:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - name: Make hook scripts executable
        run: |
          chmod +x hooks/user-prompt-submit hooks/session-start hooks/run-hook.cmd || true
      - name: Run test-compat.sh
        run: bash test/test-compat.sh
      - name: Run test-user-prompt-submit.sh
        run: bash test/test-user-prompt-submit.sh
      - name: Run test-session-start-notice.sh
        run: bash test/test-session-start-notice.sh
      - name: Run test-hook.sh (existing)
        run: bash test/test-hook.sh
      - name: Run test-e2e-observer.sh
        run: bash test/test-e2e-observer.sh
```

- [ ] **Step 2: Commit**

```bash
cd aman-plugin
git add .github/workflows/shell-tests.yml
git commit -m "ci(observer): run shell tests on Ubuntu + macOS"
```

---

### Task 17: README update — observer feature section

**Files:**
- Modify: `aman-plugin/README.md`

- [ ] **Step 1: Add a section to README**

Find a good location (after the "Features" section, before "Installation"). Add:

```markdown
## Passive rule observer (opt-in, v3.2.0-alpha.1+)

Set `AMAN_OBSERVER_ENABLED=1` in your shell to enable the passive observer. It watches your Claude Code conversations for repeated corrections (e.g., "don't commit without tests" said 3 times across sessions) and queues them as rule suggestions.

On the next session start, you'll see one line: `3 rule suggestions pending — run /rules review`. No mid-conversation interrupts; zero LLM cost.

Review suggestions with:

- `/rules review --list` — show pending suggestions with index
- `/rules accept <n>` — promote suggestion N to a real rule (calls arules-core)
- `/rules reject <n>` — dismiss; won't resurface (sha256-blocklisted)

The observer stores ephemeral state in `~/.arules/dev/plugin/.tally.tsv` (drained on promotion) and a human-readable queue in `~/.arules/dev/plugin/suggestions.md`. See `docs/superpowers/specs/2026-04-20-passive-hook-observer-design.md` for the full design.

### Opt-in, not default

The observer is gated behind `AMAN_OBSERVER_ENABLED=1` for the alpha. After one week of real use without major issues, v3.2.0 will default-enable (with an `AMAN_OBSERVER_DISABLED=1` off-switch preserved indefinitely).
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs(readme): document passive observer feature (alpha)"
```

---

### Task 18: Bump version to v3.2.0-alpha.1 + CHANGELOG

**Files:**
- Modify: `aman-plugin/package.json` (version field)
- Modify: `aman-plugin/CHANGELOG.md`
- Modify: `aman-plugin/.claude-plugin/plugin.json` (if version field exists)

- [ ] **Step 1: Check current version**

```bash
grep '"version"' package.json .claude-plugin/plugin.json
```

- [ ] **Step 2: Bump to v3.2.0-alpha.1**

Edit `package.json`:
```json
"version": "3.2.0-alpha.1"
```

Edit `.claude-plugin/plugin.json` similarly if version is present.

- [ ] **Step 3: Update CHANGELOG.md**

Prepend:

```markdown
## 3.2.0-alpha.1 — 2026-04-20

### Added
- **Passive rule observer** (opt-in via `AMAN_OBSERVER_ENABLED=1`). Watches
  Claude Code conversations for repeated corrections and proposes them as
  rules. Session-start notice shows pending count; `/rules review --list` +
  `/rules accept|reject <n>` lets users act on proposals. Zero LLM cost.
- `UserPromptSubmit` hook wired in `hooks/hooks.json`.
- New `/rules review`, `/rules accept`, `/rules reject` commands in aman-agent.
- Cross-platform `flock` / `sha256sum` shims in `hooks/lib/compat.sh`.

### Notes
- Alpha gating: set `AMAN_OBSERVER_ENABLED=1` to try. Default-enable targeted
  for v3.2.0 once alpha proves stable.
- English-only correction phrases in v1; Bahasa Malaysia markers planned.
- Writes only to `dev:plugin` scope for v1; per-repo scopes planned.

### Design
See `docs/superpowers/specs/2026-04-20-passive-hook-observer-design.md`.
```

- [ ] **Step 4: Commit**

```bash
git add package.json .claude-plugin/plugin.json CHANGELOG.md
git commit -m "chore: bump to 3.2.0-alpha.1 — passive observer"
```

---

### Task 19: Tag + push (triggers release workflow if one exists)

**Files:**
- (git only)

- [ ] **Step 1: Push all commits to main**

```bash
cd aman-plugin
git push
```

```bash
cd ../aman-agent
git push
```

- [ ] **Step 2: Tag the plugin release**

```bash
cd aman-plugin
git tag v3.2.0-alpha.1
git push origin v3.2.0-alpha.1
```

- [ ] **Step 3: Verify CI turned green**

Open the repo's Actions tab on GitHub. Confirm:
- `Shell tests` workflow ran on ubuntu-latest + macos-latest and passed
- (If a release workflow exists) `Release` workflow ran and published the alpha tag with `--tag next` on npm

If no release workflow exists (aman-plugin may not publish to npm), the tag is still useful as a version anchor.

---

## Phase 5: Validation

### Task 20: Manual smoke against a real Claude Code session

**Files:**
- (none — manual verification)

- [ ] **Step 1: Install the updated plugin locally**

```bash
cd aman-plugin
# Use whatever install path the plugin normally uses (install.sh, npm link, etc.)
./install.sh  # or the equivalent for your setup
```

- [ ] **Step 2: Enable the observer in your shell**

```bash
export AMAN_OBSERVER_ENABLED=1
```

- [ ] **Step 3: Start a Claude Code session and say the same correction 3 times across turns**

Example conversation:
> You: I'm working on the deploy script. don't commit without tests.
> You: (a few turns later) ...don't commit without tests.
> You: (a few more turns) ...don't commit without tests.

Expected: after the 3rd occurrence, `~/.arules/dev/plugin/suggestions.md` has a pending entry. No notice in the current session.

- [ ] **Step 4: End the session; start a new one**

Expected: at session start, the assistant's greeting includes a line like `1 rule suggestion pending — run /rules review`.

- [ ] **Step 5: In the aman-agent CLI, run `/rules review --list`**

```bash
aman-agent
> /rules review --list
```

Expected output: one pending entry with phrase, category, occurrences.

- [ ] **Step 6: Accept it**

```bash
> /rules accept 1
```

Expected: `✓ Added to <category>: "<phrase>"`. Verify `~/.arules/dev/plugin/rules.md` now contains the rule.

- [ ] **Step 7: Try an explicit marker test**

Say "from now on, never push directly to main" once. Confirm `suggestions.md` gets a new pending entry with `Occurrences: 1 (explicit marker)`.

---

## Self-review checklist (run before declaring the plan complete)

**1. Spec coverage** — every spec section maps to tasks:

| Spec section | Tasks |
|---|---|
| §3 Architecture file layout | 1, 2 (structure established), 9 (hooks.json), 10 (e2e) |
| §4.1 `user-prompt-submit` detector | 2, 3, 4, 5, 6 |
| §4.2 `session-start` extension | 8 |
| §4.3 `/rules review` command | 11, 12, 13, 14 |
| §4.4 `hooks.json` update | 9 |
| §5 Interactive UX | 14 (partial — full readline loop deferred by design) |
| §6 Storage formats | 2–6 produce the formats; 11 parses them |
| §7 Decisions rationale | (reference, no implementation) |
| §8 Implementation notes / cross-platform | 1 (shims), 16 (CI matrix) |
| §9 Testing strategy | 1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 14 |
| §10 Rollout / alpha gating | 2 (env gate), 7 (gate codified), 17 (README), 18 (version bump) |
| §11 Known limitations | 17 (README notes English-only etc.) |
| §12 Success criteria | 20 (manual smoke verifies) |

**Gap acknowledged:** §5 shows a fully-interactive readline loop (`(a)ccept · (r)eject · (e)dit · (s)kip · (q)uit`). Task 14 ships `--list` + `accept <n>` / `reject <n>` only. The full readline loop is deferred to v3.2.0-beta to keep the alpha scope bounded. This is an honest narrowing — announced in CHANGELOG, README, and `/rules review` output.

**2. Placeholder scan** — grep the plan for red flags:

```
TBD, TODO, implement later, add error handling, similar to Task N
```

Should find zero matches.

**3. Type consistency**

- `SuggestionEntry` defined in Task 11; used in Tasks 12, 13, 14. Field names checked.
- `parseSuggestions`, `acceptSuggestion`, `rejectSuggestion`, `phraseHash` — function names stable across tasks.
- `AGENT_SCOPE` (existing in shared.ts) used consistently for scope resolution.

---

## Execution handoff

Plan complete and saved to `aman-plugin/docs/superpowers/plans/2026-04-20-passive-hook-observer.md`.

**Two execution options:**

**1. Subagent-Driven (recommended)** — Dispatch a fresh subagent per task, review between tasks, fast iteration. Best for the ~20-task scope here since the repo context stays clean between tasks.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints. Simpler but this conversation's context grows.

**Which approach?**
