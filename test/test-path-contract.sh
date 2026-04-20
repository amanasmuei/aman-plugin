#!/usr/bin/env bash
# Cross-repo path contract check.
#
# The plugin's UserPromptSubmit hook WRITES suggestions.md at a specific path.
# aman-agent's /rules review READS suggestions.md from the same path.
# If those two references ever drift, the observer silently breaks in
# production. This test catches drift cheaply by grepping both repos.
#
# Skips gracefully if ../aman-agent isn't present (local-dev only).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AGENT_ROOT="$(cd "$PLUGIN_ROOT/../aman-agent" 2>/dev/null && pwd || true)"

skip() {
    echo "SKIP: $1"
    exit 0
}

[ -n "$AGENT_ROOT" ] || skip "aman-agent sibling dir not found at ../aman-agent"
[ -f "$AGENT_ROOT/src/commands/rules.ts" ] || skip "aman-agent/src/commands/rules.ts missing"

PASS=0; FAIL=0
pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; [ -n "${2:-}" ] && echo "        $2"; }

# --- Assertion 1: plugin hooks reference dev/plugin scope ---
if grep -qE '\.arules/dev/plugin' "$PLUGIN_ROOT/hooks/user-prompt-submit"; then
    pass "plugin detector writes to .arules/dev/plugin"
else
    fail "plugin detector does NOT reference .arules/dev/plugin" \
         "grep: $(grep -E 'arules' "$PLUGIN_ROOT/hooks/user-prompt-submit" || echo NONE)"
fi

if grep -qE '\.arules/dev/plugin' "$PLUGIN_ROOT/hooks/session-start"; then
    pass "plugin session-start reads from .arules/dev/plugin"
else
    fail "plugin session-start does NOT reference .arules/dev/plugin" \
         "grep: $(grep -E 'arules' "$PLUGIN_ROOT/hooks/session-start" || echo NONE)"
fi

# --- Assertion 2: aman-agent rules.ts reads from dev/plugin scope ---
if grep -qE '"dev",\s*"plugin"|dev/plugin' "$AGENT_ROOT/src/commands/rules.ts"; then
    pass "aman-agent /rules review reads from dev/plugin"
else
    fail "aman-agent does NOT reference dev/plugin — suggestions would be invisible!" \
         "grep: $(grep -E 'dev' "$AGENT_ROOT/src/commands/rules.ts" | head -3)"
fi

# --- Assertion 3: aman-agent rules.ts does NOT derive suggestions path from AGENT_SCOPE ---
# This is the bug class we fixed. If anyone reintroduces AGENT_SCOPE-derived
# suggestions path, the observer silently breaks again.
if grep -E 'suggestionsPath|suggestionsScopeDir' "$AGENT_ROOT/src/commands/rules.ts" | \
   grep -qE 'AGENT_SCOPE.*suggestions|suggestions.*AGENT_SCOPE'; then
    fail "aman-agent derives suggestions path from AGENT_SCOPE — regression of the dev/plugin scope fix"
else
    pass "aman-agent suggestions path is NOT derived from AGENT_SCOPE (fix holds)"
fi

# --- Assertion 4: plugin .rejected-hashes path is consistent ---
# The hook writes rejections to the same scope dir. If .rejected-hashes moves,
# the detector's blocklist check at the head of user-prompt-submit breaks.
if grep -qE 'REJECTED.*\.arules/dev/plugin|\.arules/dev/plugin.*REJECTED|\.arules/dev/plugin/\.rejected|\$REJECTED' "$PLUGIN_ROOT/hooks/user-prompt-submit"; then
    pass "plugin detector's .rejected-hashes is scoped to dev/plugin"
else
    fail "plugin detector .rejected-hashes path unclear" \
         "grep: $(grep -E 'REJECTED|rejected-hashes' "$PLUGIN_ROOT/hooks/user-prompt-submit" | head -3)"
fi

echo "---"
echo "PASS: $PASS  FAIL: $FAIL"
[ "$FAIL" -eq 0 ]
