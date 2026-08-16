# Running the drain

How the orchestrator keeps a multi-wave run honest.

## Ticket intake

`wave-status.sh` lists the current wave's remaining tickets. That set is the load.
Row order is the **default**, not the rule:

- **Priority beats row order.** A p1 filed mid-run is pulled forward immediately — above
  all, anything blocking test infrastructure, since a broken fixture chain stalls every
  later gate. p2 crash and data-integrity tickets go ahead of p3/p4 stragglers even if
  their rows sit lower.
- **A wave does not close while p1/p2 tickets filed into it remain open.** A wave with an
  open crash ticket is not certifiable.
- **Tickets slotted into an already-closed wave are worked as the current wave's tail.**
  Never reopen a closed gate; their coverage rides the next one.
- **Check for stale ticket state before dispatching.** A ticket reading `status:
  in-progress` is often finished-but-unarchived from an interrupted run. The worker's first
  job is to check branches and `git log` for the ID and verify the behaviour live, then
  leave bookkeeping to you rather than redo the work.

### Write scope is an edge, not a hope

The graph is yours. Citations on the remaining tickets name product files. Two sittings
that would edit the same files get a sequential edge: the second starts only after the
first has returned and you have landed it. Sittings whose files do not clash may run at
the same time. `depends_on` is also an edge. `cluster` is a relatedness hint for who
shares an orientation; it never overrides a write-scope edge and it never pulls a
low-priority ticket ahead of a p1.

`next-ticket.sh --group` still walks same-`cluster` tickets from a lead and still
enforces the spec's size bounds. Consult it when partitioning a sitting. Do not treat
its output as the thing that starts a worker.

A sitting never crosses a wave boundary, for the same reason the gate exists.

## The roadmap moves underneath you

`.ai/sift` is commonly gitignored, so the tracker has no history and no diff. The user and
parallel sessions edit it while the run is in flight: tickets get consolidated, audit
tickets appear, rows are re-struck or re-worded. Workers write new files under `open/`
without touching `ROADMAP.md`.

Re-read `ROADMAP.md` before **every** dispatch. When it does not match what you remember:

1. Do not assume phantom work, a lost merge, or a corrupted tree.
2. Check `git log` on the integration branch. If no foreign code landed, the change is
   bookkeeping only.
3. Adapt to the tree as it now is and continue. Mention the reshuffle in the next progress
   line so the user knows you saw it.

You are the only writer of `ROADMAP.md` during the drain. Slot rows for tickets workers
filed. Strike rows when you archive. `roadmap-check.sh` is the arbiter of rule-9
consistency — run it after **your** bookkeeping for a returned worker, not against a
worker who was forbidden to write the tracker.

## Worker lifecycle

**Autonomy is the contract for ordinary judgment calls.** Dispatch prompts state that no
answer is coming for those and that a worker facing a judgment call decides it itself
using the ticket's Direction as written, then records the call in its report.
Knowledge-base curation conflicts are likewise resolved by the worker, conservatively:
prefer the live tree and the newest user directives over an older entry's claim.

**Interference is the exception.** If a worker notices another has changed files it is
responsible for, it stops and checks back. Coordinate a solution that covers both —
usually a sequential edge you missed, or a split of remaining files. Workers do not
fight by overwriting each other. The resume snippet for a real question is still:

```
You stopped to ask: {{QUESTION_AS_YOU_UNDERSTAND_IT}}

Resolve it yourself and finish the task; no answer is coming.
  - Knowledge-base curation conflict: resolve conservatively, preferring the live tree and
    the newest user directives. Zero durable candidates is a valid outcome.
  - Implementation scope: apply the ticket's Direction as written, note the judgment call
    in your report, and continue.
  - Interference / tamper: do not overwrite. Wait; the orchestrator is coordinating.
  - Report `status: blocked` with the full question only if it is genuinely unresolvable
    without the user.
```

**Boundaries.** Workers and gate agents never edit the sift-drain skill's own files — a
skill-maintenance agent may be running concurrently. No agent ever runs `git push` or
touches an external tracker. Workers never strike, archive, or merge.

## Reporting to the user

- **One line per ticket**, immediately after you land it (or after you block it): ID, what
  landed, verification headline, wave position. A sitting that carried several tickets
  gets one line per ticket, each with that ticket's own outcome — never one line for the
  sitting.
- **Every self-filed ticket, surfaced explicitly and prominently.** Every time, even when
  the same IDs were mentioned a moment earlier. The user's oversight of the backlog depends
  on it.
- **Honest completion arithmetic.** Give the raw struck-row percentage *and* the
  qualifiers: later waves usually skew heavier than the early bug tail, so struck rows
  overstate progress, and rows struck by consolidation into another ticket are bookkeeping,
  not completed work.
- **Structured reports only.** You consume exact test counts, live pre/post observations,
  and skipped-behaviour lists. Never open an implementation file to verify a claim — ask
  the worker for the missing numbers instead.
