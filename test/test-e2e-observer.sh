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

# --- Scenario: explicit marker in 1 shot, three isolated iterations ---
for i in 1 2 3; do
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
