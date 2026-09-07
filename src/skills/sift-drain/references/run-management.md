# Running the drain

Detailed operating guidance for the orchestration loop in `SKILL.md`. The skill owns phase
order, actor ownership, dispatch, tracker updates, report consumption, and gate sequencing.
This file explains how to make the choices inside that loop. Worker instructions and the
exact worker report schema live only in `ticket-agent-prompt.md`.

`tests/static/skill-prose-pins.test.sh` reads the authority tags below.

```text
@PIN: src/skills/sift-drain/SKILL.md ## Wave graph
@PIN: src/skills/sift-drain/SKILL.md ## Consume worker reports
@PIN: src/skills/sift-drain/SKILL.md ## Wave gate
@PIN: src/skills/sift-drain/references/ticket-agent-prompt.md This file is the sole full worker contract.
```

## Ticket intake

`wave-status.sh` lists the current wave's remaining tickets, in `priority` order. That
set is the load, and that order is the **default**, not the rule:

- **Priority is the intra-wave order, and it is only a default.** A p1 filed mid-run is
  pulled forward immediately — above all, anything blocking test infrastructure, since a
  broken fixture chain stalls every later gate. p2 crash and data-integrity tickets go
  ahead of p3/p4 stragglers however late they were drafted.
- **Dependencies still win.** Priority chooses among ready tickets; it does not bypass an
  unmet `depends_on` or a write-scope edge.
- **Stale state changes the dispatch.** Search the integration branch log and local branch
  names for every ticket in a proposed sitting. When either shows prior work, keep the
  ticket in the sitting so the canonical prompt can require a live check, but tell the
  worker what history you found. Do not treat `status: in-progress` alone as evidence that
  implementation is absent.

The skill owns the rules for closing a wave and handling tickets inserted after a close.
Apply them after intake; do not restate them as a second close policy here.

### Write scope is an edge, not a hope

Use the citations in every remaining ticket to build a file-to-sitting map. Two sittings
that would edit the same product file get a sequential edge. Start the second only after
the first returns and its commit lands. Sittings with disjoint product files may run at
the same time. Add every `depends_on` relation as an edge too.

Use `cluster` only to share orientation. It neither proves that files are disjoint nor
overrides priority. When citations name a directory, generated asset, or shared template,
treat the affected files as overlapping until a ticket narrows the write scope.

`next-ticket.sh --group` still walks same-`cluster` tickets from a lead and still
enforces the spec's size bounds. Consult it when partitioning a sitting. Do not treat
its output as the thing that starts a worker.

A ticket carrying no `wave:` is in no load at all. `ticket-check.sh` names each one; give
it the wave it belongs in before the next dispatch rather than working it off the report.

Do not create a new sitting for documentation directly made inaccurate by a ticket's own
change. Include that documentation in its write scope and commit. For genuinely separate
follow-ups, prefer reusing a worker with relevant context or collecting small maintenance
items into a sitting, subject to dependencies and priority.

The coordinator prepares all new worktrees and branches with `prepare-worktree.sh` from the
original repository. Workers receive the prepared path and branch, plus `SIFT_ROOT` for the
shared tracker. No worker checks out the integration branch. On reuse, wait until the worker
has stopped, land its completed work, then prepare a new branch/worktree from the current
integration state and send the new assignment to that same worker. Leave its prior worktree
intact when it contains unfinished work; never reset or clean a tree holding live tickets.

A sitting never crosses a wave boundary. Before dispatch, verify that every ticket in it is
still present in the live wave and that no earlier edge remains unmet.

## The tree moves underneath you

`.ai/sift` is commonly gitignored, so the tracker has no history and no diff. The user and
parallel sessions edit it while the run is in flight: tickets get consolidated, audit
tickets appear, a `wave:` or a `priority:` is rewritten. Workers add files under `open/`.

The skill requires a fresh `wave-status.sh` run before every dispatch. When its report does
not match what you remember:

1. Do not assume phantom work, a lost merge, or a corrupted tree.
2. Check `git log` on the integration branch. If no foreign code landed, the change is
   bookkeeping only.
3. Adapt to the tree as it now is and continue. Mention the reshuffle in the next progress
   line so the user knows you saw it.

The skill owns tracker writes and the required `ticket-check.sh` call. This section only
defines how to react to concurrent bookkeeping changes before the next dispatch.

## Worker check-back

The canonical worker prompt tells workers how to handle judgment calls and tamper. When a
worker checks back anyway, classify the return before sending another instruction:

- **Ordinary judgment call.** Resume the same worker with the exact resume template in
  `ticket-agent-prompt.md`. Do not redispatch the sitting and lose its context.
- **Tamper or write-scope overlap.** Do not tell either worker to overwrite. Identify the
  overlapping files and sittings, wait for the earlier owner to return, land it, then resume
  or redispatch the later sitting from the new integration state.
- **Question only the user can answer.** Accept a blocked status with the full question and
  apply the failure policy in `SKILL.md`.

Rebuild the graph after any check-back. A missed overlap is evidence that its file scope was
too narrow, so inspect the remaining tickets' citations for the same shared path before the
next dispatch.

## Reporting to the user

- **One line per ticket**, immediately after you land it (or after you block it): ID, what
  landed, verification headline, wave position. A sitting that carried several tickets
  gets one line per ticket, each with that ticket's own outcome — never one line for the
  sitting.
- **Every self-filed ticket, surfaced explicitly and prominently.** Every time, even when
  the same IDs were mentioned a moment earlier. The user's oversight of the backlog depends
  on it.
- **Honest completion arithmetic.** Give the raw done percentage from `wave-status.sh`
  *and* the qualifiers: later waves usually skew heavier than the early bug tail, so the
  archived count overstates progress, and a ticket archived `superseded` by consolidation
  into another one is bookkeeping, not completed work.
- **Incomplete reports go back to their author.** The exact schema lives in
  `ticket-agent-prompt.md`; ask for the missing field or number instead of inspecting an
  implementation file.
