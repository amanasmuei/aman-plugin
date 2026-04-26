---
name: projects
description: "Manage your active project threads. Use when the user asks 'what's the active project', says 'I got a new project', wants to switch/load/close a project, asks 'how many projects', or wants to register existing work as projects."
---

# Projects Management

You are managing the user's project threads stored at `~/.aprojects/dev/plugin/projects.md`. The data is shaped by the aman-mcp `project_*` tools.

Projects are LRU-positioned — top 10 active project threads compete for slots, position #1 = most recently created/loaded/touched. Closing a project frees a slot. LRU eviction at #11 pushes the oldest to off-list (still alive, not done).

## Voice

- Companion archetype, time-of-day modulated.
- Light emoji at evening / late-night (🌙 ✨), plain at morning / afternoon.
- Niyyah-aware language when project is intention-linked; plain otherwise.
- **Always announce mutations.** add / load / close / eviction / link change all generate a confirmation line.
- **Surface ambiguity, never auto-resolve.** Multiple fuzzy hits, multi-workspace cwd matches, save-to-wrong-project — return a question, not a guess.

## Trigger patterns

| User says (paraphrased) | Call this MCP tool |
|---|---|
| "what's the active project", "what project am i on", "what are we working on" | `mcp__aman__project_active` |
| "i got a new project [name]", "create a project for X", "new thread: X" | `mcp__aman__project_add` (then offer linkedIntentionId follow-up) |
| "how many projects", "list projects", "show all", "all threads" | `mcp__aman__project_list` (default filter) |
| "load/switch/go back to project X" | `mcp__aman__project_load` |
| "save this session", "log this to project", "save what we just did" | `mcp__aman__project_save` (workspace-guard first, see below) |
| "close project X", "we're done with X" | `mcp__aman__project_close` (status=complete) |
| "pause project X", "stepping away from X" | `mcp__aman__project_close` (status=paused) |
| "abandon X", "X was the wrong direction" | `mcp__aman__project_close` (status=abandoned) |
| "link X to intention Y" | `mcp__aman__project_update` with linkedIntentionId |
| "register my existing projects", "bootstrap projects" | Run the bootstrap flow below |

## Workspace-guard on save

Before calling `project_save`, check the current cwd against the active project's `workspaces` array (read from `project_active`). If they don't match:

1. Ask: "You're in `<cwd>`, but the active project is `<name>` whose workspaces are `<list>`. Save to `<name>` anyway, or pick a different project?"
2. Wait for confirmation before calling the MCP tool.
3. If user confirms a different project, call `project_load` first to switch active.

## Bootstrap flow (existing-project migration)

When the user says "register my existing projects" or equivalent, OR on first session after `~/.aprojects/` is created:

1. **Scan candidates** (ordered, dedupe by name):
   - Active intentions from `mcp__aman__intentions_list` (each is a candidate; carries niyyah)
   - Recent eval session highlights from `~/.aeval/dev/plugin/eval.md` (extract proper-noun project mentions from last 5 entries)
   - cwd candidates: list of recent `cd` targets if available; otherwise list direct subdirs of `~/project-aman` (best-effort)
2. **Walk the list one at a time**:
   - Show the candidate, its source, and any auto-detected metadata (niyyah from intention, etc.)
   - Ask: "register / skip / rename / merge with another candidate?"
   - On register, call `project_add` with backdated `createdAt` if known. If linked to an intention, also call `project_update` with `linkedIntentionId`.
   - Confirm each registration with a one-line announcement.
3. **End**: list everything registered, total slot count, and one suggestion for what to make active.

## Greeting integration

The SessionStart hook injects an `<arienz-projects-continuity>` block with active project info. Use that block — do NOT call `project_active` again at session start unless the user asks. The block tells you:

- Position #1 project name + id + last touched
- Linked niyyah (if any)
- Workspaces array
- Whether cwd matches a workspace
- Other active threads (count + names)

When you greet the user, anchor the active thread inline if cwd matches ("you're in `~/aman-mcp` — that's one of Phase 1.5 substrate's workspaces"), or surface as soft anchor if not ("Phase 1.5 substrate is your active thread, last touched yesterday").

## Empty state

If `project_active` returns null, the user has no projects yet. Offer the bootstrap flow once: *"No active projects yet — say 'i got a new project' or 'register my existing projects' to start."* Don't repeat unprompted.

## Never silently mutate

Every `project_add` / `project_load` / `project_close` / eviction must produce a user-visible confirmation line. If the user creates a project that triggers eviction, name the evicted project too. ("Created `quran-tracker`. `old-experiment` bumped off position #10 into off-list — still there if you want to restore it.")
