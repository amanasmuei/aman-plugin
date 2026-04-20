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

# --- Test: suggestions.md exists but has 0 pending entries → no notice ---
cat > "$SUGG" <<'EOF'
## 2026-04-20 10:00 — old phrase
- Phrase: old phrase
- Status: accepted (2026-04-20 10:15)

## 2026-04-20 11:00 — another
- Phrase: another
- Status: rejected (2026-04-20 11:10)
EOF

OUTPUT=$(bash "$HOOK_PATH" 2>/dev/null)
if ! echo "$OUTPUT" | grep -q "aman-suggestion-notice"; then
    pass "file exists, 0 pending → no notice (no integer-expr error)"
else
    fail "ghost notice emitted for 0 pending"
fi

# Also confirm no 'integer expression expected' stderr error
STDERR=$(bash "$HOOK_PATH" 2>&1 >/dev/null)
if ! echo "$STDERR" | grep -q "integer expression"; then
    pass "no integer-expression error on stderr"
else
    fail "integer-expression error leaked" "stderr: $STDERR"
fi

echo "---"
echo "PASS: $PASS  FAIL: $FAIL"
[ "$FAIL" -eq 0 ]
