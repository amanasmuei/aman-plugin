---
name: identity
description: "View or update your AI identity. Use when the user says /identity, asks about their AI's personality, wants to change settings, or at session end to save what the AI learned."
---

# Identity Management

You are managing the user's AI identity. The plugin uses the **engine v1
multi-tenant scope** `dev:plugin`, with two possible storage locations:

- **Primary** (engine v1, scope-aware): `~/.acore/dev/plugin/core.md`
- **Legacy** (single-tenant fallback): `~/.acore/core.md`

Always check the primary path first. If only the legacy path exists, you can
either read from it directly or recommend the user run `npx @aman_asmuei/acore`
to migrate.

## When invoked

1. Look for `~/.acore/dev/plugin/core.md` first; fall back to `~/.acore/core.md`.
2. Show a concise summary:
   - AI name and personality
   - User name and role
   - Trust level and trajectory (if Dynamics section exists)
   - Last session date
3. Ask if the user wants to update anything.

## Updating identity

When the user wants to update or when a session is ending:

1. Review the conversation for new insights.
2. Flag any Identity-level changes for explicit approval BEFORE proceeding.
3. Read the current core.md (primary path preferred, legacy fallback OK).
4. Write the updated version back to the same path you read from.
5. Confirm what changed in 1-2 sentences.

**If aman-mcp is registered as an MCP server** (recommended — see the plugin
README's "Live tools" section), prefer calling the `identity_update_section`
or `identity_update_dynamics` MCP tools instead of writing the file directly.
This guarantees the engine's scope handling and section parsing is correct.

## Update permissions

- **Auto-update** (no approval needed): Session, Relationship.Work, Relationship.Learned patterns
- **Approval required**: Identity (any field), adding new sections
- **Suggest only**: structural changes to core.md

## If neither path exists

Tell the user: "No identity configured yet. Run `npx @aman_asmuei/aman` to set
up your AI companion, or `npx @aman_asmuei/acore` for just the identity layer.
The new layout writes to `~/.acore/dev/plugin/core.md` (multi-tenant aware)."
