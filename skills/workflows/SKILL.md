---
name: workflows
description: "View and follow AI workflows. Use when the user says /workflows, asks about processes, or starts a task that matches a defined workflow (code review, bug fix, feature build, etc.)."
---

# Workflow Management

You are managing the user's AI workflows stored in `~/.aflow/flow.md`.

## When invoked

1. Read `~/.aflow/flow.md`
2. List all defined workflows with their triggers
3. If the user asks about a specific workflow, show its steps

## Following a workflow

When the conversation matches a workflow's trigger (e.g., user asks for a code review and there's a `code-review` workflow):

1. Announce: "Following the **code-review** workflow"
2. Execute each step in order
3. Report progress as you go
4. Mark the workflow as complete when done

## If flow.md doesn't exist

Tell the user: "No workflows configured yet. Run `npx @aman_asmuei/aflow init` to set up starter workflows (code-review, bug-fix, feature-build, daily-standup)."

## Adding workflows

Guide the user to:
- `npx @aman_asmuei/aflow add` — add a new workflow interactively
- `npx @aman_asmuei/aflow list` — list all workflows
- Or edit `~/.aflow/flow.md` directly
