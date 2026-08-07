# Running the drain

How the orchestrator keeps a multi-wave run honest.

## Ticket intake

`next-ticket.sh` reads the roadmap in row order. Row order is the **default**, not the
rule:

- **Priority beats row order.** A p1 filed mid-run is pulled forward immediately — above
  all, anything blocking test infrastructure, since a broken fixture chain stalls every
  later gate. p2 crash and data-integrity tickets go ahead of p3/p4 stragglers even if
  their rows sit lower.
- **A wave does not close while p1/p2 tickets filed into it remain open.** A wave with an
  open crash ticket is not certifiable.
- **Tickets slotted into an already-closed wave are worked as the current wave's tail.**
  Never reopen a closed gate; their coverage rides the next one.
- **Check for stale ticket state before dispatching.** A ticket reading `status:
  in-progress` is often finished-but-unarchived from an interrupted run. The agent's first
  job is to check branches and `git log` for the ID and verify the behaviour live, then
  finish the bookkeeping rather than redo the work.

## The roadmap moves underneath you

`.ai/sift` is commonly gitignored, so the tracker has no history and no diff. The user and
parallel sessions edit it while the run is in flight: tickets get consolidated, audit
tickets appear, rows are re-struck or re-worded.

Re-read `ROADMAP.md` before **every** dispatch. When it does not match what you remember:

1. Do not assume phantom work, a lost merge, or a corrupted tree.
2. Check `git log` on the integration branch. If no foreign code landed, the change is
   bookkeeping only.
3. Adapt to the tree as it now is and continue. Mention the reshuffle in the next progress
   line so the user knows you saw it.

`roadmap-check.sh` is the arbiter of rule-9 consistency — run it after every ticket agent
returns, not just at wave ends.

## Sub-agent lifecycle

**Autonomy is the contract.** Dispatch prompts state that no answer is coming and that an
agent facing a judgment call decides it itself using the ticket's Direction as written,
then records the call in its report. Knowledge-base curation conflicts are likewise
resolved by the agent, conservatively: prefer the live tree and the newest user directives
over an older entry's claim.

**If an agent stops mid-task waiting for an answer** — its question may never have reached
you — resume it rather than redispatching from scratch:

```
You stopped to ask: {{QUESTION_AS_YOU_UNDERSTAND_IT}}

Resolve it yourself and finish the task; no answer is coming.
  - Knowledge-base curation conflict: resolve conservatively, preferring the live tree and
    the newest user directives. Zero durable candidates is a valid outcome.
  - Implementation scope: apply the ticket's Direction as written, note the judgment call
    in your report, and continue.
  - Report `status: blocked` with the full question only if it is genuinely unresolvable
    without the user.
```

**Boundaries.** Ticket and gate agents never edit the sift-drain skill's own files — a
skill-maintenance agent may be running concurrently. No agent ever runs `git push` or
touches an external tracker.

## Reporting to the user

- **One line per ticket**, immediately after the agent returns: ID, what landed,
  verification headline, wave position.
- **Every self-filed ticket, surfaced explicitly and prominently.** Every time, even when
  the same IDs were mentioned a moment earlier. The user's oversight of the backlog depends
  on it.
- **Honest completion arithmetic.** Give the raw struck-row percentage *and* the
  qualifiers: later waves usually skew heavier than the early bug tail, so struck rows
  overstate progress, and rows struck by consolidation into another ticket are bookkeeping,
  not completed work.
- **Structured reports only.** You consume exact test counts, live pre/post observations,
  and skipped-behaviour lists. Never open an implementation file to verify a claim — ask
  the agent for the missing numbers instead.
