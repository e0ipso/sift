---
name: sift-drain
description: This skill should be used when the user asks to "drain sift", "drain the sift roadmap", "resume the sift run", "work through the sift backlog", "keep draining tickets", "orchestrate the sift waves", or otherwise asks to work a `.ai/sift` ticket roadmap end to end. Provides the strictly sequential one-sub-agent-per-dispatch orchestration playbook, scoped per-ticket verification rules, the wave-gate test batching procedure, and deterministic roadmap scripts.
---

# Drain Sift

Work a `.ai/sift` roadmap to completion: one sub-agent per dispatch, strictly sequential,
with a test-and-lint gate at the end of every wave. A dispatch carries one ticket, or a
small group of tickets sharing a root cause — either way it is one agent, working one
ticket at a time. Nothing here is project-specific — sub-agents discover the repository's
own commands and conventions themselves.

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

Invoking a shipped script is not implementing. `next-ticket.sh`, `roadmap-check.sh` and
`drain-log.sh` are all called, never reimplemented — so stamping the run log means running
`drain-log.sh`, and writing a row into `RUNLOG.md` yourself is a breach of this rule.

You read exactly three things: `.ai/sift/ROADMAP.md`, the ticket files of the dispatch
group you are sizing — **every member's, not just the lead's** — and, when building a wave
gate's coverage list, the `resolution` lines of that wave's archived tickets. A group
widens the second item; it does not add a fourth, and reading three ticket files to size a
group of three is the rule being followed, not bent. Never open source files, diffs, or raw
test output; the structured sub-agent reports are your only other input. Catch yourself
reading implementation code: **stop and delegate.**

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
scripts/next-ticket.sh --group       # …and the whole dispatch group it leads
scripts/wave-status.sh    # per-wave done/remaining + current wave
scripts/roadmap-check.sh  # rule-9 consistency, non-zero on violation
scripts/list-labels.sh    # every label in use (--counts, --open)
scripts/tickets-by-label.sh <label>  # tickets carrying one label (--open, --paths)
scripts/drain-log.sh dispatch|phase|return|report  # per-dispatch runtime and idle attribution
```

They find the project root by walking up from `$PWD` for `.ai/sift/ROADMAP.md` and read
the prefix from `.ai/sift/config/config.yaml`; override with `SIFT_ROOT` / `SIFT_PREFIX`.
`next-ticket.sh` skips `status: blocked` tickets (`--include-blocked` to override). It
reports the lookup's own state as `result: found` or `result: none` — never as `status:`,
which in that report is always the chosen ticket's own front-matter value, so every key
means exactly one thing.
`next-ticket.sh --group` leaves the lead and every other key exactly as they were and adds
`group_size:`, `group_tickets:` and a `group_files:` block naming the tickets that may go
to one agent in a single dispatch. Membership comes from the optional `cluster`
front-matter key — a kebab-case value naming a root cause several tickets share — and a
group is bounded by a maximum ticket count and a maximum combined effort weight. The key
and both bounds are specified in `.ai/sift/README.md` under "Dispatch groups and the
cluster key"; read them there rather than from a second copy here. What you need at
dispatch time is the degradation: a ticket carrying no `cluster`, or a malformed one, is
grouped alone, so the flag only ever widens a dispatch — it can never reorder the roadmap
and never fail a run.
Every script here honours `--` as the end-of-options marker, and it means one thing across
the card: the option list ends there and everything behind it is positional. So
`tickets-by-label.sh -- <label>` looks the label up even when it came out of a variable,
while `list-labels.sh`, `next-ticket.sh`, `wave-status.sh` and `roadmap-check.sh` take no
positional at all — they accept the marker and refuse anything behind it rather than
ignoring it. `drain-log.sh`'s first positional is a subcommand, so the marker stands in
front of it: `drain-log.sh -- dispatch <TICKET>` records the row `drain-log.sh dispatch
<TICKET>` records.
`drain-log.sh dispatch <TICKET>...` and `drain-log.sh return <TICKET> <STATUS>...` append
one row per ticket to `.ai/sift/RUNLOG.md`, which the first dispatch creates and nothing
ever rewrites. Every row a single call appends shares one timestamp, and that shared
timestamp is what makes those rows one group — so hand the whole group to one call; calling
once per ticket splits one dispatch into as many groups as it carried, each of them reading
as an interrupted run. `drain-log.sh phase orient|implement|verify|bookkeep` marks where the
time went inside a dispatch; the ticket agent stamps those from within its own run, so you
read them in `report` without ever calling the mode yourself.
`drain-log.sh report` reads the log back as a per-group table of agent runtime, the idle gap
before each dispatch, the phase breakdown, and the runtime divided by the tickets the group
actually **resolved**, and flags incomplete, orphaned and unusually slow records.
Run `roadmap-check.sh` after **every** ticket agent returns — non-zero means the agent
broke rule 9 and needs a follow-up dispatch to fix the bookkeeping.

## Per-group loop — strictly sequential

**One ticket agent at a time, in roadmap order.** Intra-wave parallelism is rejected as
error-prone; never re-propose it.

**Batching is not parallelism, and it does not touch that rule.** A dispatch may carry a
*group* of tickets, but the group goes to **one** agent, which works its members **one
ticket at a time** in the order it was given, one commit each. Nothing overlaps: not two
agents, not two tickets inside one agent, not two commits. Grouping amortises a single
orientation over several related tickets and changes nothing else about the ordering. If
you find yourself reasoning about a group as if its tickets could progress at once, you
have re-proposed the rejected thing under a new name.

1. Run `next-ticket.sh --group`. Read **only** the ticket files it names — the lead and
   every member of the group — to size the work.
   **Priority beats row order:** pull a newly filed p1 forward immediately — above all,
   anything blocking test infrastructure — and p2 crash / data-integrity tickets ahead of
   p3/p4 stragglers. Priority chooses the **lead**; members only ever join the lead the
   priority rule already picked (`references/run-management.md`).
2. Run `drain-log.sh dispatch <TICKET>...` — **every** ticket in the group, in one call —
   as the last thing before the dispatch, so the stamp bounds agent runtime rather than
   your own deliberation.
3. Dispatch **one** sub-agent to take the group end to end: branch off the local
   integration branch → implement → scoped verification → archive per rule 9 → merge
   locally. Use `references/ticket-agent-prompt.md` verbatim; do not re-derive it.
4. **Model policy.** Default to the session's model tier. Escalate to the strongest tier
   available for `effort: l|xl`, for architecturally sensitive work (public API, ADRs,
   structural hubs), and for wave-gate test batches. Never downgrade to a cheap or fast
   tier to save tokens — a bad merge costs more than the model did.
5. **Never `git push`** — not you, not any sub-agent. Local branches, local merges.
6. **No planning-skill detours, no TDD cycle.** The agent implements directly, then
   verifies.
7. **No per-ticket test authoring, three exceptions.** Tests are batched at the wave
   gate; a ticket with test acceptance criteria records the **waiver** in its
   `resolution`, and the gate builds its coverage list from those resolutions. The
   exceptions: a `type: test` ticket, whose deliverable *is* the tests; a canary/pin test
   the ticket itself asks for; and minimal edits to **existing** tests whose assertions
   pin behaviour this ticket intentionally changes. Every such edit is explained in the
   report.
8. **Scoped verification only** — this is where the wall-clock savings live. The agent
   runs the project's lint, static analysis and unit/integration commands over **only**
   what it touched, plus a live pre-fix reproduction where feasible and live acceptance on
   throwaway fixtures it fully cleans up. Full suites run at the gate, never per ticket.
9. **Nothing goes to an external tracker.** No agent files, comments on, or patches an
   upstream project. An upstream fix worth making becomes a local `type: dx` ticket,
   surfaced to the user, who files it.
10. The moment the agent returns, before anything else, run
    `drain-log.sh return <TICKET> <STATUS>...` in one call, pairing each ticket with the
    `status:` its report gave **for that ticket** — a group that landed three of four says
    so here. Then post a **one-line progress update per ticket**, run `roadmap-check.sh`,
    and **surface every self-filed ticket to the user** — non-negotiable, every time.

**If a sub-agent stalls** waiting for an answer, resume it rather than abandoning the
ticket (recipe in `references/run-management.md`). Sub-agents never edit this skill's own
files: a skill-maintenance agent may be running concurrently.

**Failure policy:** redispatch once with the failure context attached. On a second
failure, dispatch an agent to set `status: blocked` (file stays in `open/`, roadmap row
left unstruck), report it, and continue the wave. Never stall a run on one ticket.

**A group fails per ticket, not as a unit.** "The dispatch failed" is almost always "some
of its tickets failed": each ticket is its own commit, its own archive move and its own
roadmap strike, so the members that came back `done` are already landed and merged. They
**stand**. Redispatch only the tickets that failed, with the failure context attached, and
on a second failure block only those — the group's successes are untouched by it. A group
is a dispatch, never a transaction, and redispatching a whole group to retry one member
redoes landed work.

## Sub-agent report format

Sub-agents return exactly this — no diffs, no file listings, no code:

```
status: <TICKET-ID>: done | blocked | not started   — one line per ticket, dispatch order
merge commit: <hash> | none
commits: <TICKET-ID> <hash> — one per ticket that landed
summary: <one paragraph per ticket>
verification: per ticket — <suite: N tests, M assertions, files run> | <lint: result>
              | <static analysis: result> | <e2e: spec, N passed | n/a>
group verification: <N tests, M assertions over the union of the scoped files>
                    | <lint: result> | <roadmap-check: exit 0>
live check: per ticket — <pre-fix observation> -> <post-fix observation>; fixtures cleaned up
test edits: <existing tests touched and why> | none
deferred to the wave gate: <waived criteria, destructive sequences, and durable knowledge
                           worth capturing> | none
tickets filed: <IDs> | none
```

`references/ticket-agent-prompt.md` holds the canonical wording; this is the same block, and
if the two ever read differently the prompt is the one the agent was actually given.

**One `status:` line per ticket**, in dispatch order, every ticket present — and `summary:`,
`verification:` and `live check:` are per ticket too. A group never reports one verdict for
the batch: partial success is a normal outcome, and a collapsed status either hides a
blocked ticket behind its neighbours' success or writes off work that landed. Those status
lines are exactly what step 10 feeds to `drain-log.sh return`. A group summarised as one
vague paragraph is a group of unverified tickets — send it back.

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
6. **One knowledge-capture pass for the whole wave**, over the wave's collected sub-agent
   reports. Ticket agents no longer capture individually — a single dispatch cannot see
   what the rest of the wave changed under it.
7. Post a **wave summary**: tickets done/blocked, tickets filed, tests added, suite status.

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
during the run; the timing table from `drain-log.sh report`.

## Additional resources

- **`references/ticket-agent-prompt.md`** — the canonical per-ticket sub-agent prompt.
- **`references/wave-gate.md`** — prompt templates for the e2e, batch coverage, fix and
  knowledge-capture agents.
- **`references/run-management.md`** — ticket intake, roadmap churn, sub-agent stalls, and
  honest progress reporting.
