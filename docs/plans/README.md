# Plans

Living development plans, dated and accreting. Read in chronological order to see how MDPrintView evolved.

These are **historical artifacts of the build process**, not authoritative current-state docs. For what's actually shipping and what's deferred, see [`../STATUS.md`](../STATUS.md).

## How this directory is laid out

| Path | What's here |
|---|---|
| `*.md` (this directory) | Active or historical plans relevant to the current OSS-first direction |
| `private/` | Not present in the repo — gitignored. Used locally for plans that aren't ready (or appropriate) to share publicly |

## Conventions

- **Filename**: `YYYY-MM-DD-<topic>.md`
- **Don't edit shipped plans** to reflect new state — write a follow-up plan and link to it instead. The chronological record is the value.
- **Status notes can be appended** at the end of an old plan (e.g. "Result: shipped 2026-06-10; see commit abc1234"). Don't rewrite the body.

## What gets a plan

- New features that need decomposition before implementation
- Architecture / scope decisions worth recording the *why* for
- Audits and research with a punch-list of follow-ups
- Spike notes when an experiment was run

What does *not* get a plan: bug fixes, polish, dependency bumps.
