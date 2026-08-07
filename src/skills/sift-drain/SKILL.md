---
name: sift-drain
description: This skill should be used when the user asks to "drain sift", "drain the sift roadmap", "resume the sift run", "work through the sift backlog", "keep draining tickets", "orchestrate the sift waves", or otherwise asks to work a `.ai/sift` ticket roadmap end to end. Provides the sequential one-ticket-per-sub-agent orchestration playbook, scoped per-ticket verification rules, the wave-gate test batching procedure, and deterministic roadmap scripts.
---

# Drain Sift

Work a `.ai/sift` roadmap to completion: one sub-agent per ticket, strictly sequential,
with a test-and-lint gate at the end of every wave. Nothing here is project-specific —
sub-agents discover the repository's own commands and conventions themselves.

## Gate: is sift initialized?

Before anything else — before reading `ROADMAP.md`, before the first dispatch — run the
`sift-init` card's `scripts/sift-gate.sh`. It reads only, and its exit code decides:

- **0 (`READY`)** — continue below.
- **3, 4 or 6** — there is no usable tree yet. Hand off to `sift-init` and follow its
  rules (4 and 6 require asking the user first). There is nothing to drain until it
  reports `READY`.
- **5 (`UNRESOLVED`)** — no project root found. Report the `$PWD` it walked from and stop.

Never resolve the root by eye and never initialize the tree yourself: the gate is one
script precisely so every card agrees on where `.ai/sift` lives.

## Orchestrate, never implement

You implement nothing. Every line of code, every test, and every piece of ticket
bookkeeping happens inside a sub-agent.

You read exactly three things: `.ai/sift/ROADMAP.md`, the one ticket file you are sizing,
and — when building a wave gate's coverage list — the `resolution` lines of that wave's
archived tickets. Never open source files, diffs, or raw test output; the structured
sub-agent reports are your only other input. Catch yourself reading implementation code:
**stop and delegate.**

## Sources of truth

| Path | Role |
|---|---|
| `.ai/sift/README.md` | Ticket convention. Rule 9 is load-bearing. |
| `.ai/sift/ROADMAP.md` | Wave ordering. `~~struck~~` rows are done. |
| `.ai/sift/open/**` | Actionable tickets (`open`, `in-progress`, `blocked`). |
| `.ai/sift/archive/**` | Terminal tickets (`done`, `wontfix`, `superseded`). |

**Rule 9:** archiving a ticket and striking its roadmap row is ONE change, in the same
commit as the implementation.

**Re-read `ROADMAP.md` before every dispatch.** Sub-agents file tickets mid-run, and the
tree is commonly gitignored — so the user or a parallel session can reorganise it with no
trace in git. A row that moved or vanished is bookkeeping, not corruption: confirm via
`git log` that no foreign code landed, adapt, continue.

## Scripts

Call these instead of parsing markdown by eye. They live in `scripts/` next to this file;
resolve that absolute path once at run start and reuse it.

```sh
scripts/next-ticket.sh    # next dispatchable ticket + front-matter
scripts/wave-status.sh    # per-wave done/remaining + current wave
scripts/roadmap-check.sh  # rule-9 consistency, non-zero on violation
scripts/list-labels.sh    # every label in use (--counts, --open)
scripts/tickets-by-label.sh <label>  # tickets carrying one label (--open, --paths)
```

They find the project root by walking up from `$PWD` for `.ai/sift/ROADMAP.md` and read
the prefix from `.ai/sift/config/config.yaml`; override with `SIFT_ROOT` / `SIFT_PREFIX`.
`next-ticket.sh` skips `status: blocked` tickets (`--include-blocked` to override).
Run `roadmap-check.sh` after **every** ticket agent returns — non-zero means the agent
broke rule 9 and needs a follow-up dispatch to fix the bookkeeping.

## Per-ticket loop — strictly sequential

**One ticket agent at a time, in roadmap order.** Intra-wave parallelism is rejected as
error-prone; never re-propose it.

1. Run `next-ticket.sh`. Read **only** the ticket file it names, to size the work.
   **Priority beats row order:** pull a newly filed p1 forward immediately — above all,
   anything blocking test infrastructure — and p2 crash / data-integrity tickets ahead of
   p3/p4 stragglers.
2. Dispatch **one** sub-agent to take the ticket end to end: branch off the local
   integration branch → implement → scoped verification → archive per rule 9 → merge
   locally. Use `references/ticket-agent-prompt.md` verbatim; do not re-derive it.
3. **Model policy.** Default to the session's model tier. Escalate to the strongest tier
   available for `effort: l|xl`, for architecturally sensitive work (public API, ADRs,
   structural hubs), and for wave-gate test batches. Never downgrade to a cheap or fast
   tier to save tokens — a bad merge costs more than the model did.
4. **Never `git push`** — not you, not any sub-agent. Local branches, local merges.
5. **No planning-skill detours, no TDD cycle.** The agent implements directly, then
   verifies.
6. **No per-ticket test authoring, three exceptions.** Tests are batched at the wave
   gate; a ticket with test acceptance criteria records the **waiver** in its
   `resolution`, and the gate builds its coverage list from those resolutions. The
   exceptions: a `type: test` ticket, whose deliverable *is* the tests; a canary/pin test
   the ticket itself asks for; and minimal edits to **existing** tests whose assertions
   pin behaviour this ticket intentionally changes. Every such edit is explained in the
   report.
7. **Scoped verification only** — this is where the wall-clock savings live. The agent
   runs the project's lint, static analysis and unit/integration commands over **only**
   what it touched, plus a live pre-fix reproduction where feasible and live acceptance on
   throwaway fixtures it fully cleans up. Full suites run at the gate, never per ticket.
8. **Nothing goes to an external tracker.** No agent files, comments on, or patches an
   upstream project. An upstream fix worth making becomes a local `type: dx` ticket,
   surfaced to the user, who files it.
9. After the agent returns: post a **one-line progress update**, run `roadmap-check.sh`,
   and **surface every self-filed ticket to the user** — non-negotiable, every time.

**If a sub-agent stalls** waiting for an answer, resume it rather than abandoning the
ticket (recipe in `references/run-management.md`). Sub-agents never edit this skill's own
files: a skill-maintenance agent may be running concurrently.

**Failure policy:** redispatch once with the failure context attached. On a second
failure, dispatch an agent to set `status: blocked` (file stays in `open/`, roadmap row
left unstruck), report it, and continue the wave. Never stall a run on one ticket.

## Sub-agent report format

Sub-agents return exactly this — no diffs, no file listings, no code:

```
status: done | blocked
merge commit: <hash>
summary: <one paragraph>
verification: <suite: N tests, M assertions, files run> | <lint: result>
              | <static analysis: result> | <e2e: spec, N passed | n/a>
live check: <pre-fix observation> -> <post-fix observation>; fixtures cleaned up
test edits: <existing tests touched and why> | none
deferred to the wave gate: <waived criteria + sequences to cover> | none
tickets filed: <IDs> | none
```

Exact test and assertion counts are mandatory — they make the scope self-evident. So are
the live pre/post observations: they are the only evidence you ever see that behaviour
actually changed. A report too vague to act on gets a follow-up question, never a peek at
the diff.

## Wave gate

A wave closes only after this, before any ticket of the next wave is dispatched:

1. **E2E specialist agent** first (skip only if the project has no e2e suite): covers only
   **browser-visible** wave behaviour, deliberately lean, extending existing specs rather
   than duplicating them, and reporting one line per behaviour covered *and* per behaviour
   skipped as having no browser surface.
2. **Batch coverage agent** — "write tests, not too many, mostly integration." Its
   coverage list is the **waived criteria collected from the wave's archived tickets**,
   folded into existing test classes where natural, plus the destructive sequences a
   shared dev environment could not run live.
3. **This is the only place the FULL suites run**, all as the wave-close: full test suite,
   full lint/static analysis, full e2e — exact totals reported for each. One agent may
   carry the batch coverage and the close.
4. **One fix agent per root cause** of any fallout — not one per failing test. Test agents
   never fix product code: they file a ticket and annotate the test with its ID so suites
   stay green-with-known-issues.
5. The wave closes when all full runs are green — and **not while p1/p2 tickets filed into
   that wave are still open**. Tickets slotted into an already-closed wave are worked as
   the current wave's tail; a closed gate is never reopened and their coverage rides the
   **next** gate.
6. Post a **wave summary**: tickets done/blocked, tickets filed, tests added, suite status.

Prompt templates: `references/wave-gate.md`.

## Gotchas

- **`.ai/sift` is usually gitignored**, so ignore-aware search (the Grep tool, `rg`, a
  wrapper `grep` shell function) silently returns nothing there. Use `find` plus
  `command grep`, or the tool's no-ignore flag.
- **Scoped linters often need absolute paths** when invoked through a package manager from
  a different working directory; a relative path reads as a broken toolchain when it is
  just a bad argument. Have agents pass absolute paths.
- **A shared dev environment is not disposable.** No agent reinstalls it, uninstalls real
  components, or actually executes a destructive scenario the code's guards exist to
  prevent — verify the guard, not the destruction. Destructive sequences belong in the
  gate's integration tests.
- **`ROADMAP.md` orders the work, but `depends_on` is the authority** when the two
  disagree, and priority pulls tickets forward within it.

## Final report at run end

Roadmap state from `wave-status.sh`; every blocked ticket and why; every ticket filed
during the run.

## Additional resources

- **`references/ticket-agent-prompt.md`** — the canonical per-ticket sub-agent prompt.
- **`references/wave-gate.md`** — prompt templates for the e2e, batch coverage, and fix
  agents.
- **`references/run-management.md`** — ticket intake, roadmap churn, sub-agent stalls, and
  honest progress reporting.
