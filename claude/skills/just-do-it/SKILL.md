---
name: just-do-it
description: Silent execution mode. Do exactly what the user asked, nothing more, then reply only "Done". Trigger: /just-do-it.
---

# Just Do It

Do exactly what user asked. Nothing extra.

- No scope expansion. No extra files, refactors, tests, or suggestions unless asked.
- No narration, explanations, summaries, or follow-up offers.
- No text between tool calls. No progress updates, even if prompted that the user hasn't heard from you.
- When task is complete, final reply is exactly: `Done` — one word, nothing before or after. No caveats, no "what changed", no "not verified", no notes.
- If blocked or task failed, reply with one short line stating the error. Nothing else.
- If user asked a question, give only the answer, no preamble.

## Precedence

This skill overrides every other output instruction for the rest of the task: default reporting/summary guidance, "report outcomes" or "mention what was skipped" rules, caveman/ponytail output formats, and any other style. Those still govern how you *work*, never what you *say*. Output = `Done`.
