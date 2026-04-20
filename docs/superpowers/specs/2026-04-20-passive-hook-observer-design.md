# Passive Hook Observer (Mulahazah-inspired) — Design

**Status:** Design approved, pending implementation plan
**Date:** 2026-04-20
**Scope:** aman-claude-code plugin (v3.2.0 target)
**Issue tracker reference:** Gap #11 in the 19-item aman-agent improvement roadmap

## 1. Purpose

Passively learn the user's correction patterns from their Claude Code sessions and propose them as rules in `~/.arules/dev/plugin/rules.md` — with zero LLM cost, zero mid-conversation interruption, and explicit user approval before anything mutates the ruleset.

Inspired by Project-AI-MemoryCore's **Mulahazah** system: hook-driven shell observation that turns repeated user feedback into durable, user-approved behavioral rules.

### Why it matters

Today, `arules-core` requires users to remember to add rules manually via `/rules add <category> <text>`. Most corrections the user makes in-session are lost — even when the same correction is made five times across a week. The observer closes that gap:

- **User says** *"don't commit without running tests"* three times across sessions
- **Observer** notices the repetition, queues it as a pending rule suggestion
- **Next session start**: one-line notice — *"3 rule suggestions pending — run /rules review"*
- **User runs** `/rules review`, accepts → now it's a first-class rule enforced by arules

## 2. Non-goals (explicit)

- **Not** a general-purpose analytics system. Only correction-phrase detection in v1.
- **Not** LLM-backed. Zero LLM calls from the detector. The whole mechanic runs in shell.
- **Not** auto-applying rules. Every proposal requires explicit user approval.
- **Not** cross-scope. Always writes to the `dev:plugin` scope for v1. Per-project or `dev:<repo>` scope selection is v2+.
- **Not** multilingual. Regex patterns are English-only for v1. Bahasa Malaysia markers added in v1.1.

## 3. Architecture

### 3.1 File layout

```
aman-plugin/
├── hooks/
│   ├── hooks.json                    ← ADD UserPromptSubmit entry
│   ├── session-start                 ← EXTEND (pending-count notice)
│   ├── user-prompt-submit            ← NEW: the detector (~80 lines bash)
│   └── run-hook.cmd                  ← existing wrapper (unchanged)
├── test/
│   ├── hooks/
│   │   └── user-prompt-submit.test.sh  ← NEW: bats-core shell tests
│   └── e2e.test.sh                   ← NEW: full lifecycle smoke

~/.arules/dev/plugin/
├── rules.md                          ← existing (untouched by observer)
├── suggestions.md                    ← NEW: promoted rule candidates
├── .tally.tsv                        ← NEW: ephemeral working state
└── .rejected-hashes                  ← NEW: sha256 blocklist
```

### 3.2 Data flow

```
User message
    │
    ▼
UserPromptSubmit hook (bash, <50ms p99)
    │
    ├─ 1. Strip <private>...</private> regions
    ├─ 2. Redact token-shaped strings
    ├─ 3. Regex-match correction patterns (explicit vs ambient)
    ├─ 4. Check .rejected-hashes → skip if user previously rejected
    ├─ 5. Update .tally.tsv atomically via flock
    │      (increment count, OR-sticky explicit flag, update lastSeen)
    ├─ 6. If threshold met (explicit=1 OR count≥3):
    │      a. Guess category via keyword table
    │      b. Append block to suggestions.md with Status: pending
    │      c. Clear tally row (phrase has graduated)
    └─ 7. Exit 0. No mutation of conversation context.

...next session...

SessionStart hook (existing, extended)
    │
    ├─ (existing ecosystem context assembly)
    ├─ Count `^- Status: pending` lines in suggestions.md
    ├─ If > 0: add one-line notice inside <aman-suggestion-notice> tag
    └─ Emit greeting + context as before.

...user acts on notice...

User: /rules review
    │
    ▼
aman-agent handleRulesCommand("review", …) — NEW action
    │
    ├─ Read suggestions.md, parse blocks with Status: pending
    ├─ For each:
    │      Show: date, phrase, occurrences, category
    │      Prompt: (a)ccept | (r)eject | (e)dit | (s)kip | (q)uit
    │
    ├─ accept  → arules-core.addRule(category, phrase, "dev:plugin")
    │            + mutate Status: to "accepted (YYYY-MM-DD HH:MM)"
    ├─ edit    → re-prompt for category/phrase with defaults,
    │            store original in Original: field, same as accept
    ├─ reject  → mutate Status: to "rejected (YYYY-MM-DD HH:MM)"
    │            + append sha256(phrase) to .rejected-hashes
    ├─ skip    → no change, stays pending
    └─ quit    → exit loop
```

### 3.3 Key boundaries

| Boundary | Enforced by |
|---|---|
| Detector never writes to `rules.md` | Only `suggestions.md` and `.tally.tsv` are written by the hook |
| Promotion requires explicit user approval | Only `/rules review` calls `arules-core.addRule()` |
| No mid-conversation interrupt | Hook emits nothing on stdout (context unchanged) |
| No LLM calls in hook | Pure bash — `grep`, `sed`, `tr`, `flock`, `shasum` |
| Rejection is persistent | sha256 appended to `.rejected-hashes`, checked at step 4 |

## 4. Component specs

### 4.1 `hooks/user-prompt-submit` (detector)

**Language:** bash 4+ with standard POSIX utilities.
**Dependencies:** `grep`, `sed`, `tr`, `cut`, `flock` (or graceful degrade), `shasum -a 256` / `sha256sum`, `date`.
**Input:** user message via `$CLAUDE_USER_PROMPT` or stdin.
**Output:** nothing on stdout (never mutates conversation context).
**Side effects:** atomic writes to `~/.arules/dev/plugin/{.tally.tsv,suggestions.md,.rejected-hashes}`.
**Performance budget:** < 50ms p99.

**Correction-phrase regexes:**

| Class | Pattern (case-insensitive, anchored) | Threshold |
|---|---|---|
| Explicit marker | `(^\|[^a-z])(from now on\|always\|never\|by default\|going forward\|stop doing\|don'?t ever)` | 1 (fire immediately) |
| Ambient correction | `(^\|[^a-z])(don'?t\|stop\|no,? not\|that'?s wrong\|actually,?)` | 3 (fire on 3rd occurrence) |

Both are intentionally **over-inclusive**. Noise is filtered by the human review step. See §7 for the rationale.

**Phrase normalization:**

1. Strip `<private>...</private>` regions.
2. Redact token-shaped strings matching `[A-Za-z0-9_-]{32,}`, `sk-[A-Za-z0-9]+`, `ghp_[A-Za-z0-9]+`, hex strings ≥40 chars.
3. Lowercase, collapse whitespace, trim trailing punctuation.
4. Take first 100 characters.

**Tally atomicity:** all read-modify-write sequences on `.tally.tsv` are guarded by `flock -x 200>"$TALLY.lock"`. If `flock` is unavailable (BusyBox, Alpine), the script degrades to a no-flock write — at most one tally increment lost under contention, acceptable given the threshold mechanic is self-correcting.

**Full pseudo-code:** see §8.1 below for the complete script.

### 4.2 `hooks/session-start` extension

**Change:** ~8-line addition at end of context assembly, before JSON output.

```bash
SUGGESTIONS_FILE="$HOME/.arules/dev/plugin/suggestions.md"
if [ -f "$SUGGESTIONS_FILE" ]; then
    PENDING=$(grep -c '^- Status: pending' "$SUGGESTIONS_FILE" 2>/dev/null || echo 0)
    if [ "$PENDING" -gt 0 ]; then
        NOTICE="$PENDING rule $([ "$PENDING" -eq 1 ] && echo suggestion || echo suggestions) pending — run /rules review"
        context_parts="${context_parts}\n\n<aman-suggestion-notice>\n${NOTICE}\n</aman-suggestion-notice>"
    fi
fi
```

Tagged with `<aman-suggestion-notice>` so the LLM knows it's a notice vs core context. Agent mentions the count once at the top of its greeting, then moves on.

### 4.3 `/rules review` command (aman-agent)

**Location:** `aman-agent/src/commands/rules.ts`, new action inside existing `handleRulesCommand`.
**Signature:** `review` action, no args. Interactive via `process.stdin` (consistent with existing `/profile edit` pattern).

**Parser:** reuses the markdown block-scan approach from `arules-core/ruleset.ts`. Blocks delimited by `^## ` headings. Per-block fields extracted with `^- FieldName: ` regex.

**User flow:** see §5 below for full interactive transcript.

### 4.4 `hooks.json` update

Add one entry to the existing file:

```json
{
  "hooks": {
    "SessionStart": [ ...existing... ],
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

`async: true` — we don't want the user to wait on the detector. Fire-and-forget semantics (the file writes are atomic; a lost hook invocation loses one data point, no corruption).

## 5. UX — `/rules review` interactive transcript

```
User: /rules review

  3 rule suggestions pending

  [1/3] 2026-04-18 22:01 — "don't commit without running tests"
        Occurrences: 3 · Category: workflow
        Actions: (a)ccept · (r)eject · (e)dit · (s)kip · (q)uit

> a
  ✓ Added to workflow: "don't commit without running tests"

  [2/3] 2026-04-20 11:02 — "never edit on main"
        Occurrences: 1 (explicit: "from now on") · Category: git
        Actions: (a)ccept · (r)eject · (e)dit · (s)kip · (q)uit

> e
  Edit category [git]: release
  Edit phrase [never edit on main]: never push directly to main; always use a branch
  ✓ Added to release: "never push directly to main; always use a branch"

  [3/3] 2026-04-20 13:45 — "don't you love this?"
        Occurrences: 3 · Category: general
        Actions: (a)ccept · (r)eject · (e)dit · (s)kip · (q)uit

> r
  ✗ Rejected (won't surface again).

  Review complete. 2 accepted · 1 rejected · 0 skipped.
```

## 6. Storage formats

### 6.1 `.tally.tsv`

Tab-separated, one row per distinct normalized phrase:

```
phrase<TAB>count<TAB>firstSeen<TAB>lastSeen<TAB>explicit
```

| Field | Type | Semantics |
|---|---|---|
| phrase | string | Normalized, ≤100 chars, no trailing punctuation |
| count | integer | Incremented per match |
| firstSeen | epoch seconds | Immutable after insert |
| lastSeen | epoch seconds | Updated on each match |
| explicit | 0/1 | Sticky OR: once 1, stays 1 |

### 6.2 `suggestions.md`

One markdown block per proposal, fixed-order fields:

```markdown
## 2026-04-18 22:01 — don't commit without running tests
- Phrase: don't commit without running tests
- Occurrences: 3
- First seen: 2026-04-18 20:14
- Category (suggested): workflow
- Status: pending
```

**After accept** — Status line mutates, new fields may appear:

```markdown
- Status: accepted (2026-04-20 11:30)
```

**After edit + accept** — original preserved:

```markdown
- Original: never edit on main
- Phrase: never push directly to main; always use a branch
- Category (suggested): git
- Category (used): release
- Status: accepted (2026-04-20 11:32)
```

**After reject** — single Status mutation:

```markdown
- Status: rejected (2026-04-20 13:50)
```

### 6.3 `.rejected-hashes`

sha256 of normalized phrase, one per line, append-only. Scanned by detector at step 4 to skip re-surfacing.

### 6.4 Category auto-suggest keyword table

Ordered by specificity; first match wins (bash `case` statement):

| Keywords | Category |
|---|---|
| `password`, `token`, `secret`, `api.key`, `credential` | `privacy` |
| `commit`, `push`, `pull`, `merge`, `rebase`, `branch` | `git` |
| `test`, `lint`, `build`, `ci` | `workflow` |
| `database`, `db`, `migration`, `sql`, `schema` | `data` |
| (no match) | `general` |

### 6.5 File permissions

All three files created with `chmod 600` (user RW only). Phrases may contain anything the user says.

## 7. Design decisions — rationale log

| Decision | Alternative considered | Chosen because |
|---|---|---|
| Plugin only (not aman-agent) | Also inside aman-agent CLI | Mulahazah's value is shell-cheap passive observation. aman-agent already has `observation.ts` for its own telemetry. Avoid double implementation. |
| Corrections only (not preferences/sequences) | Broader pattern detection | Signal clarity for v1. Preferences have "I prefer tea today" false-positive risk; sequences are workflow territory (aflow). |
| Explicit-marker 1-shot + ambient 3-count | Pure 3-count (Mulahazah default) | "From now on, never X" is explicit intent; waiting 2 more repetitions insults user. Short marker list (`from now on`, `always`, `never`, `by default`, `going forward`). |
| Session-start notice (passive surface) | Mid-session interrupt | "Passive" must stay passive. Notice at natural session boundary, no nag. |
| Markdown `suggestions.md` (not JSONL) | JSON Lines | Consistent with ecosystem convention (`rules.md`, `core.md`, `eval.md`). User can hand-delete entries for the right behavior. |
| UserPromptSubmit only (not +Stop +PreToolUse) | Broader hook wiring | Smallest footprint; tally updates are atomic per hook call; no buffered state to flush. |
| Pure bash (not Node helper) | Bash → Node phrase matcher | No new deps; Mulahazah ethos. Upgrade to Node matcher if reliability proves inadequate — same storage contract. |
| Regex is over-inclusive | Strict high-precision regex | False negatives (miss real corrections) hurt more than false positives (user rejects noise in review). |
| `.rejected-hashes` as sha256 blocklist | Track by ID, re-show | Prevents noise from resurfacing. sha256 of the *normalized* phrase means minor user typo variations still match the same rejection. |

## 8. Implementation notes

### 8.1 Detector script shape (reference steps)

The implementation plan produces the full ~80-line script. Control flow:

1. Read `$MSG` from `$CLAUDE_USER_PROMPT` or stdin.
2. Strip `<private>...</private>` regions via `sed '/<private>/,/<\/private>/d'`.
3. Apply secret redaction (`[A-Za-z0-9_-]{32,}`, `sk-*`, `ghp_*`, hex ≥40) via `sed`.
4. Run `EXPLICIT_RE`; if no match, run `AMBIENT_RE`. Exit 0 if neither matches.
5. Compute sha256 of normalized phrase. Check against `.rejected-hashes`; exit 0 if present.
6. `flock`-guarded read/modify/write on `.tally.tsv` (increment count, OR-sticky explicit flag, update lastSeen).
7. If threshold met (explicit=1 OR count≥3): category guess → append block to `suggestions.md` with `Status: pending` → clear tally row.
8. Exit 0. Never write to stdout.

### 8.2 Cross-platform `flock` and `shasum`

- **Linux (standard)**: `flock`, `sha256sum` — direct use.
- **macOS**: `flock` (from homebrew's `util-linux` or `flock` package), `shasum -a 256` — provide shim at top of script:
  ```bash
  command -v sha256sum >/dev/null || sha256sum() { shasum -a 256 "$@" | cut -d' ' -f1; }
  ```
- **Alpine/BusyBox**: `flock` may be absent → degrade to no-flock path (1-in-N-million race, acceptable).

### 8.3 Scope path resolution

Hook writes to `~/.arules/dev/plugin/` unconditionally for v1. Uses the same scope (`dev:plugin`) that the existing `session-start` hook already sets via `AMAN_PLUGIN_SCOPE=dev:plugin`. Future v2 could read `$AMAN_PLUGIN_SCOPE` and write to a matching path.

## 9. Testing strategy

### 9.1 Shell unit tests (bats-core)

Location: `aman-plugin/test/hooks/user-prompt-submit.test.sh`.

Required cases:

| Test | Expected |
|---|---|
| Explicit marker fires at count=1 | suggestions.md has entry with `Occurrences: 1 (explicit marker)` |
| Ambient pattern waits for count=3 | Calls 1 and 2 → tally only; call 3 → suggestions.md |
| Rejected hash blocks re-surface | After `.rejected-hashes` append, 3 more matches → no new entry |
| `<private>...</private>` stripped before match | Private region not in tally or suggestions |
| Token-shaped string redacted | No raw token in tally |
| Tally row cleared post-promotion | After fire, `.tally.tsv` has no matching phrase row |
| Category auto-suggest: git keywords → git | `commit`, `push`, etc. route correctly |
| flock unavailable: graceful degrade | Hook still exits 0, file still updated |
| Malformed UTF-8 input: no crash | Hook exits 0, whatever it extracts is safe |

### 9.2 `/rules review` command tests (vitest)

Location: `aman-agent/test/commands-rules-review.test.ts`.

Required cases:

| Test | Expected |
|---|---|
| Accept → `addRule` called with correct category/phrase/scope | spy verified |
| Edit → defaults shown, new values used in addRule | spy verified |
| Reject → Status mutated, sha256 appended to `.rejected-hashes` | file assertions |
| Skip → Status unchanged | file assertion |
| Quit mid-loop → remaining entries stay pending | file assertion |
| Empty suggestions.md → "No pending suggestions." | output assertion |
| Malformed block → parser skips, continues with next | parser robustness |

### 9.3 End-to-end smoke (`aman-plugin/test/e2e.test.sh`)

Spawns `user-prompt-submit` with 3 correction inputs, then simulates `/rules review` via direct function call. Asserts the full lifecycle: tally → promote → review → accept → `rules.md` updated via `arules-core`.

Runs in CI on Ubuntu + macOS matrices.

## 10. Rollout plan

1. **v3.2.0-alpha.1**: Ship detector + hook wiring + `/rules review`. Gate behind `AMAN_OBSERVER_ENABLED=1` env var so early adopters opt in.
2. **v3.2.0-beta**: After one week of alpha with no major bugs, default-enable. Keep the env var as a kill switch.
3. **v3.2.0**: Stable. Remove env var once proven (can leave a `AMAN_OBSERVER_DISABLED=1` off-switch indefinitely).

## 11. Known limitations (v1)

- English only — no Bahasa Malaysia / other language markers.
- Global `dev:plugin` scope only — no per-repo scoping.
- No LLM-based deduplication (two equivalent phrases stay separate).
- No stale-tally cleanup (minor, benign leak).
- No analytics dashboard.
- Category auto-suggest is static — doesn't learn from the user's existing rules.

None of these block v1 usefulness. All are additive in v2+.

## 12. Success criteria for v1

- Observer detects 100% of `from now on / never / always` explicit-intent corrections in CI test fixtures.
- Observer catches a 3-occurrence ambient correction within the window without false positives on unit-test phrases.
- `/rules review` accept → `rules.md` updated via `arules-core` API, verifiable by `listRuleCategories`.
- Hook p99 latency under 50ms measured on Ubuntu 22 runner.
- Zero conversation-context mutation in normal operation (verified by running the hook on 100 diverse test messages and checking `stdout` is empty).
- Rejected phrases do not resurface after sha256 is recorded.

---

**Status: design approved, ready for `writing-plans` to create the implementation plan.**
