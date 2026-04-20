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

echo "---"
echo "PASS: $PASS  FAIL: $FAIL"
[ "$FAIL" -eq 0 ]
