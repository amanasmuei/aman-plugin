#!/usr/bin/env bash
# Tests for the session-start hook
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_PATH="$SCRIPT_DIR/../hooks/session-start"

PASS=0
FAIL=0
TOTAL=0

pass() {
  PASS=$((PASS + 1))
  TOTAL=$((TOTAL + 1))
  echo "  PASS: $1"
}

fail() {
  FAIL=$((FAIL + 1))
  TOTAL=$((TOTAL + 1))
  echo "  FAIL: $1"
  if [ -n "${2:-}" ]; then
    echo "        $2"
  fi
}

# Check jq is available
if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is required but not installed"
  exit 1
fi

# ---------- Test 1: No ecosystem files ----------
echo "Test 1: No ecosystem files present"
TMPDIR1=$(mktemp -d)
trap "rm -rf $TMPDIR1" EXIT

OUTPUT=$(HOME="$TMPDIR1" bash "$HOOK_PATH" 2>&1)

# Valid JSON?
if echo "$OUTPUT" | jq . &>/dev/null; then
  pass "Output is valid JSON"
else
  fail "Output is not valid JSON" "$OUTPUT"
fi

# Has additional_context key?
if echo "$OUTPUT" | jq -e '.additional_context' &>/dev/null; then
  pass "Contains additional_context key"
else
  fail "Missing additional_context key"
fi

# Has hookSpecificOutput key?
if echo "$OUTPUT" | jq -e '.hookSpecificOutput' &>/dev/null; then
  pass "Contains hookSpecificOutput key"
else
  fail "Missing hookSpecificOutput key"
fi

# Contains "No aman ecosystem configured" message?
CONTEXT=$(echo "$OUTPUT" | jq -r '.additional_context')
if echo "$CONTEXT" | grep -q "No aman ecosystem configured"; then
  pass "Shows 'No aman ecosystem configured' when no files exist"
else
  fail "Missing 'No aman ecosystem configured' message"
fi

rm -rf "$TMPDIR1"

# ---------- Test 2: Only core.md present ----------
echo ""
echo "Test 2: Only core.md present"
TMPDIR2=$(mktemp -d)
mkdir -p "$TMPDIR2/.acore"
echo "# Identity: TestBot" > "$TMPDIR2/.acore/core.md"

OUTPUT=$(HOME="$TMPDIR2" bash "$HOOK_PATH" 2>&1)

if echo "$OUTPUT" | jq . &>/dev/null; then
  pass "Output is valid JSON"
else
  fail "Output is not valid JSON" "$OUTPUT"
fi

CONTEXT=$(echo "$OUTPUT" | jq -r '.additional_context')
if echo "$CONTEXT" | grep -q "Identity: TestBot"; then
  pass "Contains core.md content"
else
  fail "Missing core.md content"
fi

rm -rf "$TMPDIR2"

# ---------- Test 3: Only kit.md present ----------
echo ""
echo "Test 3: Only kit.md present"
TMPDIR3=$(mktemp -d)
mkdir -p "$TMPDIR3/.akit"
echo "# Tools: hammer, wrench" > "$TMPDIR3/.akit/kit.md"

OUTPUT=$(HOME="$TMPDIR3" bash "$HOOK_PATH" 2>&1)

CONTEXT=$(echo "$OUTPUT" | jq -r '.additional_context')
if echo "$CONTEXT" | grep -q "Tools: hammer, wrench"; then
  pass "Contains kit.md content"
else
  fail "Missing kit.md content"
fi

rm -rf "$TMPDIR3"

# ---------- Test 4: Only flow.md present ----------
echo ""
echo "Test 4: Only flow.md present"
TMPDIR4=$(mktemp -d)
mkdir -p "$TMPDIR4/.aflow"
echo "# Workflow: deploy pipeline" > "$TMPDIR4/.aflow/flow.md"

OUTPUT=$(HOME="$TMPDIR4" bash "$HOOK_PATH" 2>&1)

CONTEXT=$(echo "$OUTPUT" | jq -r '.additional_context')
if echo "$CONTEXT" | grep -q "Workflow: deploy pipeline"; then
  pass "Contains flow.md content"
else
  fail "Missing flow.md content"
fi

rm -rf "$TMPDIR4"

# ---------- Test 5: Only rules.md present ----------
echo ""
echo "Test 5: Only rules.md present"
TMPDIR5=$(mktemp -d)
mkdir -p "$TMPDIR5/.arules"
echo "# Rule: no secrets in code" > "$TMPDIR5/.arules/rules.md"

OUTPUT=$(HOME="$TMPDIR5" bash "$HOOK_PATH" 2>&1)

CONTEXT=$(echo "$OUTPUT" | jq -r '.additional_context')
if echo "$CONTEXT" | grep -q "Rule: no secrets in code"; then
  pass "Contains rules.md content"
else
  fail "Missing rules.md content"
fi

rm -rf "$TMPDIR5"

# ---------- Test 6: Only skills.md present ----------
echo ""
echo "Test 6: Only skills.md present"
TMPDIR6=$(mktemp -d)
mkdir -p "$TMPDIR6/.askill"
echo "# Skill: code review" > "$TMPDIR6/.askill/skills.md"

OUTPUT=$(HOME="$TMPDIR6" bash "$HOOK_PATH" 2>&1)

CONTEXT=$(echo "$OUTPUT" | jq -r '.additional_context')
if echo "$CONTEXT" | grep -q "Skill: code review"; then
  pass "Contains skills.md content"
else
  fail "Missing skills.md content"
fi

rm -rf "$TMPDIR6"

# ---------- Test 7: All files present ----------
echo ""
echo "Test 7: All ecosystem files present"
TMPDIR7=$(mktemp -d)
mkdir -p "$TMPDIR7/.acore" "$TMPDIR7/.akit" "$TMPDIR7/.aflow" "$TMPDIR7/.arules" "$TMPDIR7/.askill"
echo "# Identity: AllBot" > "$TMPDIR7/.acore/core.md"
echo "# Kit: all tools" > "$TMPDIR7/.akit/kit.md"
echo "# Flow: all workflows" > "$TMPDIR7/.aflow/flow.md"
echo "# Rules: all rules" > "$TMPDIR7/.arules/rules.md"
echo "# Skills: all skills" > "$TMPDIR7/.askill/skills.md"

OUTPUT=$(HOME="$TMPDIR7" bash "$HOOK_PATH" 2>&1)

if echo "$OUTPUT" | jq . &>/dev/null; then
  pass "Output is valid JSON with all files"
else
  fail "Output is not valid JSON with all files" "$OUTPUT"
fi

CONTEXT=$(echo "$OUTPUT" | jq -r '.additional_context')
ALL_FOUND=true
for keyword in "Identity: AllBot" "Kit: all tools" "Flow: all workflows" "Rules: all rules" "Skills: all skills"; do
  if ! echo "$CONTEXT" | grep -q "$keyword"; then
    fail "Missing content: $keyword"
    ALL_FOUND=false
  fi
done
if [ "$ALL_FOUND" = true ]; then
  pass "All ecosystem file contents present in output"
fi

# Verify no "No aman ecosystem configured" message when files exist
if echo "$CONTEXT" | grep -q "No aman ecosystem configured"; then
  fail "Should not show 'No aman ecosystem configured' when files exist"
else
  pass "Correctly omits 'No aman ecosystem configured' when files exist"
fi

rm -rf "$TMPDIR7"

# ---------- Test 8: hookSpecificOutput structure ----------
echo ""
echo "Test 8: hookSpecificOutput structure"
TMPDIR8=$(mktemp -d)
mkdir -p "$TMPDIR8/.acore"
echo "# Test" > "$TMPDIR8/.acore/core.md"

OUTPUT=$(HOME="$TMPDIR8" bash "$HOOK_PATH" 2>&1)

HOOK_EVENT=$(echo "$OUTPUT" | jq -r '.hookSpecificOutput.hookEventName')
if [ "$HOOK_EVENT" = "SessionStart" ]; then
  pass "hookEventName is 'SessionStart'"
else
  fail "hookEventName should be 'SessionStart', got '$HOOK_EVENT'"
fi

if echo "$OUTPUT" | jq -e '.hookSpecificOutput.additionalContext' &>/dev/null; then
  pass "hookSpecificOutput contains additionalContext"
else
  fail "hookSpecificOutput missing additionalContext"
fi

rm -rf "$TMPDIR8"

# ---------- Summary ----------
echo ""
echo "================================"
echo "Results: $PASS passed, $FAIL failed, $TOTAL total"
echo "================================"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
