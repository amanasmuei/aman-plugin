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
