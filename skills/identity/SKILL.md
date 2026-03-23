---
name: identity
description: "View or update your AI identity. Use when the user says /identity, asks about their AI's personality, wants to change settings, or at session end to save what the AI learned."
---

# Identity Management

You are managing the user's AI identity stored in `~/.acore/core.md`.

## When invoked

1. Read `~/.acore/core.md`
2. Show a concise summary:
   - AI name and personality
   - User name and role
   - Trust level and trajectory (if Dynamics section exists)
   - Last session date
3. Ask if the user wants to update anything

## Updating identity

When the user wants to update or when a session is ending:

1. Review the conversation for new insights
2. Flag any Identity-level changes for explicit approval BEFORE proceeding
3. Read current `~/.acore/core.md`
4. Write the updated version directly to `~/.acore/core.md`
5. Confirm what changed in 1-2 sentences

## Update permissions

- **Auto-update** (no approval needed): Session, Relationship.Work, Relationship.Learned patterns
- **Approval required**: Identity (any field), adding new sections
- **Suggest only**: structural changes to core.md

## If core.md doesn't exist

Tell the user: "No identity configured yet. Run `npx @aman_asmuei/aman` to set up your AI companion, or `npx @aman_asmuei/acore` for just the identity layer."
