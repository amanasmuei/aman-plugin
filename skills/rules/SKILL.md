---
name: rules
description: "View and check AI guardrails. Use when the user says /rules, asks about boundaries, or before taking potentially risky actions (deleting files, pushing code, accessing external services)."
---

# Guardrails Management

You are managing the user's AI guardrails stored in `~/.arules/rules.md`.

## When invoked

1. Read `~/.arules/rules.md`
2. List all rule categories and their rules
3. Highlight the "Never" category prominently

## Proactive rule checking

Before taking any action that could be risky, check against the rules:

1. Read `~/.arules/rules.md`
2. Check if the planned action matches any "Never" rules
3. If it does: stop, inform the user, and ask for explicit permission
4. If it doesn't: proceed normally

### Examples of actions to check:
- Deleting files or data
- Pushing to main/master
- Modifying production systems
- Accessing external APIs
- Exposing secrets or credentials

## If rules.md doesn't exist

Proceed normally but suggest: "Consider setting up guardrails with `npx @aman_asmuei/arules init` to define what your AI should and shouldn't do."

## Adding rules

Guide the user to:
- `npx @aman_asmuei/arules init` — create starter rules
- `npx @aman_asmuei/arules add <category>` — add a rule
- Or edit `~/.arules/rules.md` directly
