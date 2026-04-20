# hooks/lib/compat.sh
# Cross-platform shims for detector hooks. Source this file; don't execute.

# sha256_hex: read stdin, write 64-char lowercase hex digest to stdout.
# Linux has sha256sum; macOS has shasum -a 256; both output "<hex>  <file>".
if command -v sha256sum >/dev/null 2>&1; then
    sha256_hex() { sha256sum | cut -d' ' -f1; }
elif command -v shasum >/dev/null 2>&1; then
    sha256_hex() { shasum -a 256 | cut -d' ' -f1; }
elif command -v md5sum >/dev/null 2>&1; then
    # No sha256 available — fall back to MD5 (collision-tolerant here because
    # we're blocklisting user's own rejected phrases, not doing cryptographic
    # work). Prefix with "md5:" so the hash format is self-identifying if it
    # ever mixes with sha256-originated hashes.
    sha256_hex() { printf 'md5:'; md5sum | cut -d' ' -f1; }
elif command -v md5 >/dev/null 2>&1; then
    sha256_hex() { printf 'md5:'; md5 | awk '{print $NF}'; }
else
    sha256_hex() {
        echo "compat.sh: no sha256sum/shasum/md5sum/md5 available" >&2
        return 1
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
