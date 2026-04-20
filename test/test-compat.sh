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

# --- with_flock: propagates exit code ---
if with_flock /tmp/compat-test-flock.lock true; then
    pass_rc=0
else
    pass_rc=$?
fi
assert_eq "$pass_rc" "0" "with_flock propagates success exit"

if with_flock /tmp/compat-test-flock.lock false; then
    fail_rc=0
else
    fail_rc=$?
fi
assert_eq "$fail_rc" "1" "with_flock propagates failure exit"

rm -f /tmp/compat-test-flock.lock

echo "---"
echo "PASS: $PASS  FAIL: $FAIL"
[ "$FAIL" -eq 0 ]
