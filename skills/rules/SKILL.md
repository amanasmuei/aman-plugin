---
name: rules
description: "View and check AI guardrails. Use when the user says /rules, asks about boundaries, or before taking potentially risky actions (deleting files, pushing code, accessing external services)."
---

# Guardrails Management

You are managing the user's AI guardrails. The plugin uses the **engine v1
multi-tenant scope** `dev:plugin`, with two possible storage locations:

- **Primary** (engine v1, scope-aware): `~/.arules/dev/plugin/rules.md`
- **Legacy** (single-tenant fallback): `~/.arules/rules.md`

Always check the primary path first. If only the legacy path exists, you can
either read from it directly or recommend the user run
`npx @aman_asmuei/arules` to migrate.

## When invoked

1. Look for `~/.arules/dev/plugin/rules.md` first; fall back to `~/.arules/rules.md`.
2. List all rule categories and their rules.
3. Highlight the "Never" category prominently.

## Proactive rule checking

Before taking any action that could be risky, check against the rules:

1. Find the rules file (primary path preferred, legacy fallback OK).
2. Check if the planned action matches any "Never" rules — apply
   keyword-overlap matching: extract meaningful words (length > 3, no
   stopwords) from each "Never" rule, lowercase the action, and flag if
   the action contains ≥2 keywords from any single rule.
3. If a rule matches: stop, inform the user, and ask for explicit permission.
4. If nothing matches: proceed normally.

**If aman-mcp is registered** (recommended — see the plugin README's "Live
tools" section), prefer calling the `rules_check` MCP tool instead of doing
the keyword matching yourself. The MCP tool uses the same engine library
that aman-tg's production guardrails use.

### Examples of actions to check:
- Deleting files or data
- Pushing to main/master
- Modifying production systems
- Accessing external APIs
- Exposing secrets or credentials

## If neither path exists

Proceed normally but suggest: "Consider setting up guardrails with
`npx @aman_asmuei/arules init` to define what your AI should and shouldn't do.
The new layout writes to `~/.arules/dev/plugin/rules.md` (multi-tenant aware)."

## Adding rules

Guide the user to:
- `npx @aman_asmuei/arules init` — create starter rules
- `npx @aman_asmuei/arules add <category>` — add a rule
- Or edit the rules file directly (primary path preferred)
