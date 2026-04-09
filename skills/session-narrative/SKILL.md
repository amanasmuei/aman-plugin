---
name: session-narrative
description: "Save a flowing-prose narrative of the current session's reasoning path. Use when the user says /session-narrative, 'save a session narrative', 'capture this session', or at the end of a substantial working session where the reasoning path matters as much as the outcome."
---

# Session Narrative

You are writing a **session narrative** — a single flowing-prose memory note that captures the *reasoning path* of the current Claude Code session, not just the final decisions. Scattered `memory_store` calls capture *what we decided*; a session narrative captures *how we got there* — the attempts, the dead ends, the pivot moments, the lessons.

This skill is the Claude Code twin of the `/session-narrative` prompt file that ships with aman-copilot for VS Code Copilot Chat and Copilot CLI. Same protocol, same output shape, same memory store — works on all three surfaces transparently because the dev:* scopes share memory via amem.

## When to refuse

If the session has been trivial — pure implementation of an already-decided plan, a 5-minute bug fix, or nothing surprising happened — **tell the user the session isn't narrative-worthy and suggest scattered `memory_store` calls instead**. Don't pad empty sessions into fake narratives. Narratives should preserve genuine reasoning; inflated narratives dilute the signal.

Good test: *"Would a colleague joining the project next week actually benefit from reading this as a story?"* If no, refuse and save facts instead.

## How to write it

**300–500 words of flowing prose.** Not a bullet list. Prose, because prose preserves causation (*"because X, we tried Y"*) in a way bullets can't. Write as if telling a colleague who joins the project next week and asks *"how did we end up here?"*

Cover in order:

1. **Intent** — what were we trying to do at the start?
2. **Attempts** — what did we try, in chronological order?
3. **Dead ends** — what didn't work, and *why*? This is the most valuable part.
4. **Pivot moments** — when and why did we change direction?
5. **Outcome** — what shipped, what's still open
6. **Lessons** — one or two reusable insights (or *"none — this was execution"*)

Good narratives are honest about failure. If something took three attempts, say so. If a decision was a judgment call that might be wrong, flag it. The point is to preserve the *thinking*, not to write a success story.

## How to save it

### Option A — amem is installed (preferred)

Check if the `amem-memory` MCP server is available. If yes, call `memory_store` with:

- `type`: `fact` (amem doesn't have a dedicated narrative type yet — we use facts with clear title and metadata)
- `confidence`: `0.9`
- `content`: the 300–500 word narrative, prepended with:

```
# Session narrative — <YYYY-MM-DD> — <short topic>

**Scope:** <current scope, e.g. dev:plugin>
**Type:** session_narrative
**Duration:** <rough estimate>

---

<the narrative body>
```

After storing, confirm with one line plus the narrative's opening sentence so the user can verify the right story was captured.

### Option B — amem is not installed (fallback)

If amem is not installed, save the narrative to the Claude Code auto-memory directory at `~/.claude/projects/<current-project>/memory/session_<YYYY-MM-DD>_<short-topic>.md` using the same markdown structure as Option A, with this frontmatter:

```markdown
---
name: Session narrative — <YYYY-MM-DD> — <short topic>
description: <one-line summary of what this session was about>
type: session_narrative
---
```

Then tell the user: *"amem isn't installed, so I wrote the narrative to your Claude Code auto-memory at `<path>`. If you install amem later, the next `amem-cli sync` will import this into your searchable memory store."*

## Safety

- **Wrap secrets** in `<private>...</private>` before any save — stripped before storage. This includes: API keys, tokens, URLs with embedded auth, and file paths containing credentials.
- **Filter emotional context.** If the user rejected a direction for reasons that were personal/tired/frustrated, keep the rejection in the narrative but frame it neutrally. Memory outlives the mood that produced it.
- **Check consent for sensitive work.** If the session touched client code, customer data, or production systems, ask before writing a narrative that might inadvertently describe those details.

## If the user wants edits

If they push back — *"you missed the part about X"*, *"rewrite the lessons"*, *"make it shorter"* — revise in place and re-save via `memory_patch` (if using amem) or rewrite the file (if using auto-memory). Narratives should be singular per session, not duplicated. If they ask for a completely different framing, it's fine to delete the old one and write fresh.

## What this enables

Three months from now, the user (or a future AI session) can run `memory_recall("session narrative [topic]")` and get back the entire story — not just the final decisions, but the reasoning path. That's the whole point. Decisions age poorly without their context; narratives age well because they carry their own reasoning.

This skill pairs with the `amem` prompt best practices guide at
https://github.com/amanasmuei/amem/blob/main/docs/guides/prompt-best-practices.md
which documents the full phrase catalog (save triggers, recall
triggers, session closers) for users.
