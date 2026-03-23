---
name: eval
description: "Track and review your AI relationship quality. Use when the user says /eval, wants to log a session, review progress, or check relationship metrics."
---

# Evaluation Management

You are managing the user's AI evaluation data stored in `~/.aeval/eval.md`.

## When invoked

1. Read `~/.aeval/eval.md`
2. Show current metrics: sessions count, trust level, trajectory
3. Show recent timeline entries if any exist
4. Ask if the user wants to log this session

## Logging a session

When the user wants to log a session (or at session end):

1. Ask: "How was this session?" (great / good / okay / frustrating)
2. Ask: "What went well?" (optional)
3. Ask: "What could improve?" (optional)
4. Ask: "Trust change?" (increased / same / decreased)
5. Update `~/.aeval/eval.md`:
   - Increment session count
   - Add timeline entry with date, rating, notes
   - Update trust level if changed
   - Update trajectory based on recent trend

## Showing a report

When the user asks for a report:
- Show session count, duration, trust trajectory
- Show recent sessions with star ratings
- Show milestones
- Show patterns

## If eval.md doesn't exist

Tell the user: "No evaluation tracking yet. Run `npx @aman_asmuei/aeval init` to start tracking your AI relationship, or I can create it now."

If the user wants to start tracking, create `~/.aeval/eval.md` with the starter template.
